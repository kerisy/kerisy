module kerisy.auth.BasicAuthRealm;

import kerisy.auth.AuthRealm;
import kerisy.auth.Claim;
import kerisy.auth.ClaimTypes;
import kerisy.auth.JwtToken;
import kerisy.auth.JwtUtil;
import kerisy.auth.principal;
import kerisy.auth.UserDetails;
import kerisy.auth.UserService;
import kerisy.provider.ServiceProvider;

import hunt.collection.ArrayList;
import hunt.collection.Collection;
import hunt.http.AuthenticationScheme;
import hunt.logging.ConsoleLogger;
import hunt.shiro;
import hunt.String;

import std.format;


/**
 * 
 */
class BasicAuthRealm : AuthRealm {

    this(UserService userService) {
        super(userService);
    }

    override bool supports(AuthenticationToken token) {
        version(HUNT_AUTH_DEBUG) tracef("AuthenticationToken: %s", typeid(cast(Object)token));
        UsernamePasswordToken t = cast(UsernamePasswordToken)token;
        return t !is null;
    }

    override protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) {
        string username = token.getPrincipal();
        string password = cast(string)token.getCredentials();

        UserService userService = GetUserService();
        version(HUNT_AUTH_DEBUG) {
            infof("username: %s, %s", username, typeid(cast(Object)userService));
        }        

        // To authenticate the user with username and password
        UserDetails user = userService.Authenticate(username, password);
        
        if(user !is null) {

            version(HUNT_AUTH_DEBUG) infof("Realm: %s", getName());
            PrincipalCollection pCollection = new SimplePrincipalCollection(user, getName());
            String credentials = new String(password);
            SimpleAuthenticationInfo info = new SimpleAuthenticationInfo(pCollection, credentials);

            return info;
        } else {
            throw new IncorrectCredentialsException(username);
        }
    }
}