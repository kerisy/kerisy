module kerisy.routing.RouteItem;

import kerisy.middleware.MiddlewareInterface;
import hunt.logging.ConsoleLogger;


/**
 * 
 */
class RouteItem {
    private TypeInfo_Class[] _allowedMiddlewares;
    private TypeInfo_Class[] _skippedMiddlewares;

    string[] methods;

    string path;
    string urlTemplate;
    string pattern;
    string[int] paramKeys;

    bool isRegex = false;

    void WithMiddleware(T)() if(is(T : MiddlewareInterface)) {
        _allowedMiddlewares ~= T.classinfo;
    }

    void WithMiddleware(string name) {
        try {
            TypeInfo_Class typeInfo = MiddlewareInterface.Get(name);
            _allowedMiddlewares ~= typeInfo;
        } catch(Exception ex) {
            warning(ex.msg);
        }
    }

    TypeInfo_Class[] AllowedMiddlewares() {
        return _allowedMiddlewares;
    }

    void WithoutMiddleware(T)() if(is(T : MiddlewareInterface)) {
        _skippedMiddlewares ~= T.classinfo;
    }

    void WithoutMiddleware(string name) {
        try {
            TypeInfo_Class typeInfo = MiddlewareInterface.Get(name);
            _skippedMiddlewares ~= typeInfo;
        } catch(Exception ex) {
            warning(ex.msg);
        }
    }

    TypeInfo_Class[] SkippedMiddlewares() {
        return _skippedMiddlewares;
    }


}
