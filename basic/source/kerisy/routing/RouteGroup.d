module kerisy.routing.RouteGroup;

import kerisy.routing.ActionRouteItem;
import kerisy.routing.RouteItem;
import kerisy.auth.AuthOptions;
import kerisy.middleware.MiddlewareInterface;

import hunt.logging.ConsoleLogger;

/**
 * 
 */
final class RouteGroup {

    private RouteItem[] _allItems;
    private string _guardName = DEFAULT_GURAD_NAME;

    private TypeInfo_Class[] _allowedMiddlewares;
    private TypeInfo_Class[] _skippedMiddlewares;

    // type
    enum string DEFAULT = "default";
    enum string HOST = "host";
    enum string DOMAIN = "domain";
    enum string PATH = "path";

    string name;
    string type;
    string value;


    void AppendRoutes(RouteItem[] items) {
        _allItems ~= items;
    }

    RouteItem Get(string actionId) {
        foreach (RouteItem item; _allItems) {
            ActionRouteItem actionItem = cast(ActionRouteItem) item;
            if (actionItem is null)
                continue;
            if (actionItem.ActionId == actionId)
                return actionItem;
        }

        return null;
    }

    override string toString() {
        return "{" ~ name ~ ", " ~ type ~ ", " ~ value ~ "}";
    }

    string GuardName() {
        return _guardName;
    }

    RouteGroup GuardName(string value) {
        _guardName = value;
        return this;
    }

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
