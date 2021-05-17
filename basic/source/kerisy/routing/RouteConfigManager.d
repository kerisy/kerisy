module kerisy.routing.RouteConfigManager;

import kerisy.routing.ActionRouteItem;
import kerisy.routing.RouteItem;
import kerisy.routing.ResourceRouteItem;
import kerisy.routing.RouteGroup;

import kerisy.config.ApplicationConfig;
import kerisy.Init;
import hunt.logging.ConsoleLogger;
import hunt.http.routing.RouterManager;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.regex;
import std.string;


/** 
 * 
 */
class RouteConfigManager {

    private ApplicationConfig _appConfig;
    private RouteItem[][string] _allRouteItems;
    private RouteGroup[] _allRouteGroups;
    private string _basePath;

    this(ApplicationConfig appConfig) {
        _appConfig = appConfig;
        _basePath = DEFAULT_CONFIG_PATH;
        LoadGroupRoutes();
        LoadDefaultRoutes();
    }

    string BasePath() {
        return _basePath;
    }

    RouteConfigManager BasePath(string value) {
        _basePath = value;
        return this;
    }

    private void AddGroupRoute(RouteGroup group, RouteItem[] routes) {
        _allRouteItems[group.name] = routes;
        group.AppendRoutes(routes);
        _allRouteGroups ~= group;

        RouteGroupType groupType = RouteGroupType.Host;
        if (group.type == "path") {
            groupType = RouteGroupType.Path;
        }
    }

    RouteItem Get(string actionId) {
        return GetRoute(RouteGroup.DEFAULT, actionId);
    }

    RouteItem Get(string group, string actionId) {
        return GetRoute(group, actionId);
    }

    RouteItem[][RouteGroup] AllRoutes() {
        RouteItem[][RouteGroup] r;
        foreach (string key, RouteItem[] value; _allRouteItems) {
            foreach (RouteGroup g; _allRouteGroups) {
                if (g.name == key) {
                    r[g] ~= value;
                    break;
                }
            }
        }
        return r;
    }

    ActionRouteItem GetRoute(string group, string actionId) {
        auto itemPtr = group in _allRouteItems;
        if (itemPtr is null)
            return null;

        foreach (RouteItem item; *itemPtr) {
            ActionRouteItem actionItem = cast(ActionRouteItem) item;
            if (actionItem is null)
                continue;
            if (actionItem.ActionId == actionId)
                return actionItem;
        }

        return null;
    }

    ActionRouteItem GetRoute(string groupName, string method, string path) {
        version(HUNT_FM_DEBUG) {
            tracef("matching: groupName=%s, method=%s, path=%s", groupName, method, path);
        }

        if(path.empty) {
            warning("path is empty");
            return null;
        }

        if(path != "/")
            path = path.stripRight("/");

        //
        // auto itemPtr = group.name in _allRouteItems;
        auto itemPtr = groupName in _allRouteItems;
        if (itemPtr is null)
            return null;

        foreach (RouteItem item; *itemPtr) {
            ActionRouteItem actionItem = cast(ActionRouteItem) item;
            if (actionItem is null)
                continue;

            // TODO: Tasks pending completion -@zhangxueping at 2020-03-13T16:23:18+08:00
            // handle /user/{id<[0-9]+>} 
            if(actionItem.path != path) continue;
            // tracef("actionItem: %s", actionItem);
            string[] methods = actionItem.methods;
            if (!methods.empty && !methods.canFind(method))
                continue;

            return actionItem;
        }

        return null;
    }

    RouteGroup Group(string name = RouteGroup.DEFAULT) {
        auto item = _allRouteGroups.find!(g => g.name == name).takeOne;
        if (item.empty) {
            errorf("Can't find the route group: %s", name);
            return null;
        }
        return item.front;
    }

    private void LoadGroupRoutes() {
        RouteGroupConfig[] routeGroups = _appConfig.route.groups;
        if (routeGroups.empty) {
            version(HUNT_DEBUG) warning("No route group defined.");
            return;
        }

        version (HUNT_DEBUG) {
            info(routeGroups);
        }

        foreach (RouteGroupConfig v; routeGroups) {
            RouteGroup groupInfo = new RouteGroup();
            groupInfo.name = strip(v.name);
            groupInfo.type = strip(v.type);
            groupInfo.value = strip(v.value);

            version (HUNT_FM_DEBUG)
                infof("route group: %s", groupInfo);

            string routeConfigFile = groupInfo.name ~ DEFAULT_ROUTE_CONFIG_EXT;
            routeConfigFile = buildPath(_basePath, routeConfigFile);

            if (!exists(routeConfigFile)) {
                warningf("Config file does not exist: %s", routeConfigFile);
            } else {
                RouteItem[] routes = Load(routeConfigFile);

                if (routes.length > 0) {
                    AddGroupRoute(groupInfo, routes);
                } else {
                    version (HUNT_DEBUG)
                        warningf("No routes defined for group %s", groupInfo.name);
                }
            }
        }
    }

    private void LoadDefaultRoutes() {
        // load default routes
        string routeConfigFile = buildPath(_basePath, DEFAULT_ROUTE_CONFIG);
        if (!exists(routeConfigFile)) {
            warningf("The config file for route does not exist: %s", routeConfigFile);
        } else {
            RouteItem[] routes = Load(routeConfigFile);
            _allRouteItems[RouteGroup.DEFAULT] = routes;

            RouteGroup defaultGroup = new RouteGroup();
            defaultGroup.name = RouteGroup.DEFAULT;
            defaultGroup.type = RouteGroup.DEFAULT;
            defaultGroup.value = RouteGroup.DEFAULT;
            defaultGroup.AppendRoutes(routes);

            _allRouteGroups ~= defaultGroup;
        }
    }

    void WithMiddleware(T)() if(is(T : MiddlewareInterface)) {
        group().withMiddleware!T();
    }
    
    void WithMiddleware(string name) {
        try {
            Group().WithMiddleware(name);
        } catch(Exception ex) {
            warning(ex.msg);
        }
    }    
    
    void WithoutMiddleware(T)() if(is(T : MiddlewareInterface)) {
        Group().withoutMiddleware!T();
    }
    
    void WithoutMiddleware(string name) {
        try {
            Group().WithoutMiddleware(name);
        } catch(Exception ex) {
            warning(ex.msg);
        }
    } 

    string CreateUrl(string actionId, string[string] params = null, string groupName = RouteGroup.DEFAULT) {

        if (groupName.empty)
            groupName = RouteGroup.DEFAULT;

        // find Route
        // RouteConfigManager routeConfig = serviceContainer().resolve!(RouteConfigManager);
        RouteGroup routeGroup = Group(groupName);
        if (routeGroup is null)
            return null;

        RouteItem route = GetRoute(groupName, actionId);
        if (route is null) {
            return null;
        }

        string url;
        if (route.isRegex) {
            if (params is null) {
                warningf("Need route params for (%s).", actionId);
                return null;
            }

            if (!route.paramKeys.empty) {
                url = route.urlTemplate;
                foreach (i, key; route.paramKeys) {
                    string value = params.get(key, null);

                    if (value is null) {
                        logWarningf("this route template need param (%s).", key);
                        return null;
                    }

                    params.remove(key);
                    url = url.replaceFirst("{" ~ key ~ "}", value);
                }
            }
        } else {
            url = route.pattern;
        }

        string groupValue = routeGroup.value;
        if (routeGroup.type == RouteGroup.HOST || routeGroup.type == RouteGroup.DOMAIN) {
            url = (_appConfig.https.enabled ? "https://" : "http://") ~ groupValue ~ url;
        } else {
            string baseUrl = strip(_appConfig.application.baseUrl, "", "/");
            string tempUrl = (groupValue.empty || groupValue == RouteGroup.DEFAULT) ? baseUrl : (baseUrl ~ "/" ~ groupValue);
            url = tempUrl ~ url;
        }

        return url ~ (params.length > 0 ? ("?" ~ BuildUriQueryString(params)) : "");
    }

    static string BuildUriQueryString(string[string] params) {
        if (params.length == 0) {
            return "";
        }

        string r;
        foreach (k, v; params) {
            r ~= (r ? "&" : "") ~ k ~ "=" ~ v;
        }

        return r;
    }

    static RouteItem[] Load(string filename) {
        import std.stdio;

        RouteItem[] items;
        auto f = File(filename);

        scope (exit) {
            f.close();
        }

        foreach (line; f.byLineCopy) {
            RouteItem item = ParseOne(cast(string) line);
            if (item is null)
                continue;

            if (item.path.length > 0) {
                items ~= item;
            }
        }

        return items;
    }

    static RouteItem ParseOne(string line) {
        line = strip(line);

        // not availabale line return null
        if (line.length == 0 || line[0] == '#') {
            return null;
        }

        // match example: 
        // GET, POST    /users    module.controller.action | staticDir:wwwroot:true
        auto matched = line.match(
                regex(`([^/]+)\s+(/[\S]*?)\s+((staticDir[\:][\w|\/|\\|\:|\.]+)|([\w\.]+))`));

        if (!matched) {
            if (!line.empty()) {
                warningf("Unmatched line: %s", line);
            }
            return null;
        }

        //
        RouteItem item;
        string part3 = matched.captures[3].to!string.strip;

        // 
        if (part3.startsWith(DEFAULT_RESOURCES_ROUTE_LEADER)) {
            ResourceRouteItem routeItem = new ResourceRouteItem();
            string remaining = part3.chompPrefix(DEFAULT_RESOURCES_ROUTE_LEADER);
            string[] subParts = remaining.split(":");

            version(HUNT_HTTP_DEBUG) {
                tracef("Resource route: %s", subParts);
            }

            if(subParts.length > 1) {
                routeItem.resourcePath = subParts[0].strip();
                string s = subParts[1].strip();
                try {
                    routeItem.canListing = to!bool(s);
                } catch(Throwable t) {
                    version(HUNT_DEBUG) warning(t);
                }
            } else {
                routeItem.resourcePath = remaining.strip();
            }

            item = routeItem;
        } else {
            ActionRouteItem routeItem = new ActionRouteItem();
            // actionId
            string actionId = part3;
            string[] mcaArray = split(actionId, ".");

            if (mcaArray.length > 3 || mcaArray.length < 2) {
                logWarningf("this route config actionId length is: %d (%s)", mcaArray.length, actionId);
                return null;
            }

            if (mcaArray.length == 2) {
                routeItem.controller = mcaArray[0];
                routeItem.action = mcaArray[1];
            } else {
                routeItem.moduleName = mcaArray[0];
                routeItem.controller = mcaArray[1];
                routeItem.action = mcaArray[2];
            }
            item = routeItem;
        }

        // methods
        string methods = matched.captures[1].to!string.strip;
        methods = methods.toUpper();

        if (methods.length > 2) {
            if (methods[0] == '[' && methods[$ - 1] == ']')
                methods = methods[1 .. $ - 2];
        }

        if (methods == "*" || methods == "ALL") {
            item.methods = null;
        } else {
            item.methods = split(methods, ",");
        }

        // path
        string path = matched.captures[2].to!string.strip;
        item.path = path;
        item.pattern = MendPath(path);

        // warningf("old: %s, new: %s", path, item.pattern);

        // regex path
        auto matches = path.matchAll(regex(`\{(\w+)(<([^>]+)>)?\}`));
        if (matches) {
            string[int] paramKeys;
            int paramCount = 0;
            string pattern = path;
            string urlTemplate = path;

            foreach (m; matches) {
                paramKeys[paramCount] = m[1];
                string reg = m[3].length ? m[3] : "\\w+";
                pattern = pattern.replaceFirst(m[0], "(" ~ reg ~ ")");
                urlTemplate = urlTemplate.replaceFirst(m[0], "{" ~ m[1] ~ "}");
                paramCount++;
            }

            item.isRegex = true;
            item.pattern = pattern;
            item.paramKeys = paramKeys;
            item.urlTemplate = urlTemplate;
        }

        return item;
    }

    static string MendPath(string path) {
        if (path.empty || path == "/")
            return "/";

        if (path[0] != '/') {
            path = "/" ~ path;
        }

        if (path[$ - 1] != '/')
            path ~= "/";

        return path;
    }
}

/**
 * Examples:
 *  # without component
 *  controller.attachment.attachmentcontroller.upload
 * 
 *  # with component
 *  component.attachment.controller.attachment.attachmentcontroller.upload
 */
string MakeRouteHandlerKey(ActionRouteItem route, RouteGroup group = null) {
    string moduleName = route.moduleName;
    string controller = route.controller;

    string groupName = "";
    if (group !is null && group.name != RouteGroup.DEFAULT)
        groupName = group.name ~ ".";

    string key = format("%scontroller.%s%s.%scontroller.%s", moduleName.empty()
            ? "" : "component." ~ moduleName ~ ".", groupName, controller,
            controller, route.action);
    return key.toLower();
}
