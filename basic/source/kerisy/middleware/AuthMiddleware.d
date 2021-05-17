module kerisy.middleware.AuthMiddleware;

import kerisy.middleware.MiddlewareInterface;

import kerisy.application.Application;
import kerisy.auth.Auth;
import kerisy.auth.AuthOptions;
import kerisy.auth.Claim;
import kerisy.auth.ClaimTypes;
import kerisy.auth.Identity;
import kerisy.auth.UserService;
import kerisy.config.ApplicationConfig;
import kerisy.http.RedirectResponse;
import kerisy.http.Request;
import kerisy.http.Response;
import kerisy.http.UnauthorizedResponse;
import kerisy.Init;
import kerisy.provider.ServiceProvider;
import kerisy.BasicSimplify;


import hunt.http.HttpHeader;
import hunt.http.AuthenticationScheme;
import hunt.logging.ConsoleLogger;

import std.base64;
import std.range;
import std.string;

/**
 * 
 */
class AuthMiddleware : AbstractMiddleware {
    shared static this() {
        MiddlewareInterface.register!(typeof(this));
    }

    protected bool OnAccessable(Request request) {
        return true;
    }

    protected Response OnRejected(Request request) {
        if(request.isRestful()) {
            return new UnauthorizedResponse("", true);
        } else {
            ApplicationConfig.AuthConf appConfig = app().Config().auth;
            string unauthorizedUrl = appConfig.unauthorizedUrl;
            if(unauthorizedUrl.empty ) {
                return new UnauthorizedResponse("", false, request.auth().Scheme());
            } else {
                return new RedirectResponse(request, unauthorizedUrl);
            }
        }            
    } 

    Response OnProcess(Request request, Response response = null) {
        version(HUNT_AUTH_DEBUG) {
            infof("path: %s, method: %s", request.Path(), request.method );
        }

        
        Auth auth = request.auth();
        if(!auth.isEnabled()) {
            warning("The auth is disabled. Are you sure that the guard is defined?");
            return OnRejected(request);
        }

        // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-08-04T18:03:55+08:00
        // More tests are needed
        // Identity user = auth.user();
        // try {
        //     if(user.IsAuthenticated()) {
        //         version(HUNT_DEBUG) {
        //             string fullName = user.fullName();
        //             infof("User [%s / %s] has already logged in.",  user.name(), fullName);
        //         }
        //         return null;
        //     }
        // } catch(Exception ex) {
        //     warning(ex.msg);
        //     version(HUNT_DEBUG) warning(ex);
        // }

        Identity user = auth.SignIn();
        if(user.IsAuthenticated()) {
            version(HUNT_DEBUG) {
                string fullName = user.FullName();
                infof("User [%s / %s] logged in.",  user.Name(), fullName);
            }

            if(OnAccessable(request)) return null;	
        }
        
        return OnRejected(request);
    }    
}