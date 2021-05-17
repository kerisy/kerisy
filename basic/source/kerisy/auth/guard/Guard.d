module kerisy.auth.guard.Guard;

import kerisy.auth.AuthOptions;
import kerisy.auth.AuthRealm;
import kerisy.auth.HuntShiroCache;
import kerisy.auth.ShiroCacheManager;
import kerisy.auth.UserService;
import kerisy.config.ApplicationConfig;
import kerisy.http.Request;
import kerisy.provider.ServiceProvider;
import hunt.http.AuthenticationScheme;
import hunt.shiro;
import hunt.shiro.session.mgt.SessionManager;
import hunt.shiro.session.mgt.DefaultSessionManager;

import hunt.logging.ConsoleLogger;



/**
 * 
 */
abstract class Guard {
    private DefaultSecurityManager _securityManager;
    private Realm[] _realms;
    private UserService _userService;
    private int _tokenExpiration = DEFAULT_TOKEN_EXPIRATION*24*60*60;
    private AuthenticationScheme _authScheme = AuthenticationScheme.Bearer;
    private string _tokenCookieName = JWT_COOKIE_NAME;

    private string _name;

    this(UserService userService, string name = DEFAULT_GURAD_NAME) {
        _userService = userService;
        _name = name;

        ApplicationConfig appConfig = serviceContainer().resolve!ApplicationConfig();
        _tokenExpiration = appConfig.auth.tokenExpiration;
    }

    string name() {
        return _name;
    }

    UserService userService() {
        return _userService;
    }

    Guard TokenExpiration(int value) {
        _tokenExpiration = value;
        return this;
    }

    int TokenExpiration() {
        return _tokenExpiration;
    }

    Guard TokenCookieName(string value) {
        _tokenCookieName = value;
        return this;
    }

    string TokenCookieName() {
        return _tokenCookieName;
    }

    AuthenticationScheme AuthScheme() {
        return _authScheme;
    }

    Guard AuthScheme(AuthenticationScheme value) {
        _authScheme = value;
        return this;
    }

    Guard AddRealms(AuthRealm realm) {
        _realms ~= cast(Realm)realm;
        return this;
    }

    AuthenticationToken GetToken(Request request);

    void boot() {
        try {
            HuntCache cache = serviceContainer().resolve!HuntCache();
            CacheManager cacheManager = new ShiroCacheManager(cache);        
            _securityManager = new DefaultSecurityManager();
            DefaultSessionManager sm = cast(DefaultSessionManager)_securityManager.getSessionManager();

            if(sm !is null) {
                sm.setGlobalSessionTimeout(_tokenExpiration*1000);
            }

            SecurityUtils.setSecurityManager(_name, _securityManager);
            _securityManager.setRealms(_realms);
            _securityManager.setCacheManager(cacheManager);              
        } catch(Exception ex) {
            warning(ex.msg);
            version(HUNT_DEBUG) warning(ex);
        }      
    }

}