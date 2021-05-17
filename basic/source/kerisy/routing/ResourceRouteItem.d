module kerisy.routing.ResourceRouteItem;

import kerisy.routing.RouteItem;
import std.conv;

/**
 * 
 */
final class ResourceRouteItem : RouteItem {

    /// Is a folder for static content?
    bool canListing = false;

    string resourcePath;

    override string toString() {
        return "path: " ~ path ~ ", methods: " ~ methods.to!string()
            ~ ", resource path: " ~ resourcePath;
    }
}
