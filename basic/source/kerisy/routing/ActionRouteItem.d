module kerisy.routing.ActionRouteItem;

import kerisy.routing.RouteItem;
import std.conv;

/**
 * 
 */
final class ActionRouteItem : RouteItem {

    // module
    string moduleName;

    // controller
    string controller;

    // action
    string action;

    string ActionId() {
        return (moduleName ? moduleName ~ "." : "") ~ controller ~ "." ~ action;
    }

    override string toString() {
        return "path: " ~ path ~ ", methods: " ~ methods.to!string() ~ ", actionId: " ~ ActionId;
    }
}
