module kerisy.auth.JwtAuthRealm;

import kerisy.auth.AuthRealm;
import kerisy.auth.Claim;
import kerisy.auth.ClaimTypes;
import kerisy.auth.Identity;
import kerisy.auth.JwtToken;
import kerisy.auth.JwtUtil;
import kerisy.auth.principal;
import kerisy.auth.UserDetails;
import kerisy.auth.UserService;
import kerisy.config.AuthUserConfig;
import kerisy.Init;
import kerisy.provider.ServiceProvider;


import hunt.collection.ArrayList;
import hunt.collection.Collection;
import hunt.http.AuthenticationScheme;
import hunt.logging.ConsoleLogger;
import hunt.shiro;
import hunt.String;

import std.algorithm;
import std.range;
import std.string;


/**
 * See_also:
 *  [Springboot Integrate with Apache Shiro](http://www.andrew-programming.com/2019/01/23/springboot-integrate-with-jwt-and-apache-shiro/)
 *  https://stackoverflow.com/questions/13686246/shiro-security-multiple-realms-which-authorization-info-is-taken
 */
class JwtAuthRealm : AuthRealm {

    this(UserService userService) {
        super(userService);
    }

    override bool supports(AuthenticationToken token) {
        version(HUNT_AUTH_DEBUG) tracef("AuthenticationToken: %s", typeid(cast(Object)token));
        
        JwtToken t = cast(JwtToken)token;
        return t !is null;
    }

    // override protected UserService GetUserService() {
    //     return serviceContainer().resolve!UserService();
    // }

    override protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) {
        string tokenString = token.getPrincipal();
        string username = JwtUtil.GetUsername(tokenString);
        if (username.empty) {
            version(HUNT_DEBUG) warning("The username in token is empty.");
            throw new AuthenticationException("token invalid");
        }

        UserService userService = GetUserService();
        version(HUNT_AUTH_DEBUG) {
            infof("username: %s, %s", username, typeid(cast(Object)userService));
        }        

        // To retrieve the user info from username
        UserDetails user = userService.GetByName(username);
        if(user is null) {
            throw new AuthenticationException(format("The user [%s] does NOT exist!", username));
        }

        if(!user.isEnabled)
            throw new AuthenticationException("The user is disabled!");

        string salt = user.salt; // userService.GetSalt(username, "user.password");
        version(HUNT_AUTH_DEBUG) {
            infof("tokenString: %s,  username: %s, salt: %s", tokenString, username, salt);
        }      

        // Valid the user using JWT
        if(!JwtUtil.Verify(tokenString, username, salt)) {
            throw new IncorrectCredentialsException("Wrong username or password for " ~ username);
        }

        version(HUNT_AUTH_DEBUG) infof("Realm: %s", getName());
        PrincipalCollection pCollection = new SimplePrincipalCollection(user, getName());
        String credentials = new String(tokenString);

        SimpleAuthenticationInfo info = new SimpleAuthenticationInfo(pCollection, credentials);
        return info;
    }

}