module kerisy.auth.guard.JwtGuard;

import kerisy.auth.guard.Guard;
import kerisy.auth.AuthOptions;
import kerisy.auth.BasicAuthRealm;
import kerisy.auth.JwtToken;
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


class JwtGuard : Guard {

    this() {
        this(new SimpleUserService(), DEFAULT_GURAD_NAME);
    }

    this(UserService userService, string name) {
        super(userService, name);
        Initialize();
    }    

    override AuthenticationToken GetToken(Request request) {
        string tokenString = request.BearerToken();

        if (tokenString.empty)
            tokenString = request.cookie(TokenCookieName);

        if (tokenString.empty)
            return null;

        return new JwtToken(tokenString, TokenCookieName);
    }

    protected void Initialize() {
        TokenCookieName = JWT_COOKIE_NAME;
        AuthScheme = AuthenticationScheme.Bearer;

        AddRealms(new BasicAuthRealm(userService()));
        AddRealms(new JwtAuthRealm(userService()));
    }
}
