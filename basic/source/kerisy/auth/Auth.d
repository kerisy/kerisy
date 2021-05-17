module kerisy.auth.Auth;

import kerisy.auth.AuthOptions;
import kerisy.auth.AuthService;
import kerisy.auth.Claim;
import kerisy.auth.ClaimTypes;
import kerisy.auth.guard;
import kerisy.auth.Identity;
import kerisy.auth.JwtToken;
import kerisy.auth.JwtUtil;
import kerisy.auth.UserService;
import kerisy.auth.UserDetails;
import kerisy.http.Request;
// import kerisy.BasicSimplify;
import kerisy.provider.ServiceProvider;

import hunt.http.AuthenticationScheme;
import hunt.logging.ConsoleLogger;
import hunt.shiro.Exceptions;
import hunt.shiro.authc.AuthenticationToken;
import hunt.util.TypeUtils;

import hunt.jwt.JwtRegisteredClaimNames;

import std.algorithm;
import std.array : split;
import std.base64;
import std.json;
import std.format;
import std.range;
import std.variant;
import core.time;

private enum AuthState {
    Auto,
    Token,
    SignIn,
    SignOut
}


/**
 * 
 */
class Auth {
    
    private Identity _user;
    private string _token;
    private bool _remember = false;
    private bool _isTokenRefreshed = false;
    private bool _isLogout = false;
    private AuthState _state = AuthState.Auto;
    private string _guardName = DEFAULT_GURAD_NAME;
    private Guard _guard;
    private bool _isEnabled = false;

    private Request _request;
    
    this(Request request) {
        _request = request;
        _guardName = request.guardName();
        AuthService authService = serviceContainer().resolve!AuthService();
        
        _guard = authService.guard(_guardName);
        _isEnabled = isGuardAvailable();
        _user = new Identity(_guardName, _isEnabled);

        version(HUNT_AUTH_DEBUG) {
            if(_isEnabled) {
                warningf("path: %s, IsAuthenticated: %s", request.Path(), _user.IsAuthenticated());
            }
        }
    }

    bool isGuardAvailable() {
        return _guard !is null;
    }

    bool isEnabled() {
        return _isEnabled;
    }

    string TokenCookieName() {
        return guard().TokenCookieName();
    }

    // void autoDetect() {
    //     if(_state != AuthState.Auto || !isEnabled()) 
    //         return;

    //     version(HUNT_DEBUG) {
    //         infof("Detecting the authentication state from %s", TokenCookieName());
    //     }
        
    //     AuthenticationScheme scheme = guard().AuthScheme();
    //     if(scheme == AuthenticationScheme.None)
    //         scheme = AuthenticationScheme.Bearer;

    //     // Detect the auth type automatically
    //     if(scheme == AuthenticationScheme.Bearer) {
    //         _token = _request.BearerToken();
    //     } else if(scheme == AuthenticationScheme.Basic) {
    //         _token = _request.BasicToken();
    //     }

    //     if(_token.empty()) { // Detect the token from cookie
    //         _token = request.cookie(TokenCookieName());
    //     } 

    //     if(!_token.empty()) {
    //         _user.Authenticate(_token, scheme);
    //     }

    //     _state = AuthState.Token;
    // }

    Identity user() {
        return _user;
    }

    Guard guard() {
        version(HUNT_DEBUG) {
            if(!isEnabled()) {
                string msg = format("No guard avaliable for %s", _guardName);
                throw new AuthenticationException(msg);
            }
        }
        return _guard;
    }

    Identity SignIn(string name, string password, bool remember = false) {
        _user.Authenticate(name, password, remember);

        _remember = remember;
        _state = AuthState.SignIn;

        if(!_user.IsAuthenticated()) 
            return _user;

        if(Scheme == AuthenticationScheme.Bearer) {
            UserDetails userDetails = _user.userDetails();
            string salt = userDetails.salt;
            // UserService userService = guard().userService();
            // string salt = userService.GetSalt(name, password);
            
            uint exp = guard().TokenExpiration; // config().auth.tokenExpiration;

            JSONValue claims;
            claims["user_id"] = _user.id;

            Claim[] userClaims = _user.Claims();

            foreach(Claim c; userClaims) {
                string claimName = ToJwtClaimName(c.Type());
                Variant value = c.Value;
                if(TypeUtils.isIntegral(value.type))
                    claims[claimName] = JSONValue(c.Value.get!(long));
                else if(TypeUtils.isUsignedIntegral(value.type))
                    claims[claimName] = JSONValue(c.Value.get!(ulong));
                else if(TypeUtils.isFloatingPoint(value.type))
                    claims[claimName] = JSONValue(c.Value.get!(float));
                else 
                    claims[claimName] = JSONValue(c.Value.toString());
            }

            _token = JwtUtil.Sign(name, salt, exp.seconds, claims);
            _isEnabled = true;
        } else if(Scheme == AuthenticationScheme.Basic) {
            string str = name ~ ":" ~ password;
            ubyte[] data = cast(ubyte[])str;
            _token = cast(string)Base64.encode(data);
            _isEnabled = true;
        } else {
            error("Unsupported AuthenticationScheme: %s", Scheme);
            _isEnabled = false;
        }

        return _user;
    }

    static string ToJwtClaimName(string name) {
        switch(name) {
            case  ClaimTypes.Name: 
                return JwtRegisteredClaimNames.Sub;

            case  ClaimTypes.Nickname: 
                return JwtRegisteredClaimNames.Nickname;

            case  ClaimTypes.GivenName: 
                return JwtRegisteredClaimNames.GivenName;

            case  ClaimTypes.Surname: 
                return JwtRegisteredClaimNames.FamilyName;

            case  ClaimTypes.Email: 
                return JwtRegisteredClaimNames.Email;

            case  ClaimTypes.Gender: 
                return JwtRegisteredClaimNames.Gender;

            case  ClaimTypes.DateOfBirth: 
                return JwtRegisteredClaimNames.Birthdate;
            
            default:
                return name;
        }
    }

    /// Use token to login
    Identity SignIn() {
        scope(success) {
            _state = AuthState.Token;
        }

        Guard g = guard();
        
        version(HUNT_DEBUG) infof("guard: %s, type: %s", g.name, typeid(g));

        AuthenticationToken token = g.GetToken(_request);
        _user.Login(token);
        _isEnabled = true;
        return _user;
    }

    void SignOut() {
        _state = AuthState.SignOut;
        _token = null;
        _remember = false;
        _isLogout = true;
        
        if(Scheme != AuthenticationScheme.Basic && Scheme != AuthenticationScheme.Bearer) {
            warningf("Unsupported authentication scheme: %s", Scheme);
        }

        if(_user.IsAuthenticated()) {
            _user.Logout();
        }
    }

    string RefreshToken(string salt) {
        string username = _user.Name();
        if(!_user.IsAuthenticated()) {
            throw new AuthenticationException( format("The use is not authenticated: %s", _user.Name()));
        }

        if(Scheme == AuthenticationScheme.Bearer) {
            // UserService userService = serviceContainer().resolve!UserService();
            // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-07-17T11:10:18+08:00
            // 
            // string salt = userService.GetSalt(username, "no password");
            _token = JwtUtil.Sign(username, salt);
        } 
        
        _state = AuthState.Token;
        _isTokenRefreshed = true;
        return _token;
    }

    // the token value for the "remember me" session.
    string Token() {
        // autoDetect();
        if(_token.empty) {
            AuthenticationToken token = guard().GetToken(_request);
            if(token !is null)
                _token = token.getPrincipal();
        }
        return _token;
    }
  
    AuthenticationScheme Scheme() {
        return guard().AuthScheme();
    }

    bool CanRememberMe() {
        return _remember;
    }

    bool IsTokenRefreshed() {
        return _isTokenRefreshed;
    }

    bool IsLogout() {
        return _isLogout;
    }

    void TouchSession() {
        _user.TouchSession();
    }

}
