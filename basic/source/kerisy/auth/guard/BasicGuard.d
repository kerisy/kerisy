module kerisy.auth.guard.BasicGuard;

import kerisy.auth.guard.Guard;
import kerisy.auth.AuthOptions;
import kerisy.auth.BasicAuthRealm;
import kerisy.auth.JwtAuthRealm;
import kerisy.auth.SimpleUserService;
import kerisy.auth.UserService;
import kerisy.http.Request;
import hunt.http.AuthenticationScheme;
import hunt.shiro;

import hunt.logging.ConsoleLogger;

import std.algorithm;
import std.base64;
import std.range;
import std.string;


class BasicGuard : Guard {

    this() {
        this(new SimpleUserService(), DEFAULT_GURAD_NAME);
    }

    this(UserService userService, string name) {
        super(userService, name);
        Initialize();
    }    

    override AuthenticationToken GetToken(Request request) {
        string tokenString = request.BasicToken();
        
        if (tokenString.empty)
            tokenString = request.cookie(TokenCookieName);

        if(tokenString.empty) {
            return null;
        }

        ubyte[] decoded = Base64.decode(tokenString);
        string[] values = split(cast(string)decoded, ":");
        if(values.length != 2) {
            warningf("Wrong token: %s", values);
            return null;
        }

        string username = values[0];
        string password = values[1];
        
        return new UsernamePasswordToken(username, password);
    }

    protected void Initialize() {
        TokenCookieName = BASIC_COOKIE_NAME;
        AuthScheme = AuthenticationScheme.Basic;

        AddRealms(new BasicAuthRealm(userService()));
        // addRealms(new JwtAuthRealm(userService()));
    }

}