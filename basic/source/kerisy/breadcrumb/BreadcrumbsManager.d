module kerisy.breadcrumb.BreadcrumbsManager;

import kerisy.breadcrumb.BreadcrumbItem;
import kerisy.breadcrumb.Breadcrumbs;

import std.array;

/**
 * 
 */
class BreadcrumbsManager {
    private Breadcrumbs generator;
    private Handler[string] callbacks;

    this() {
        generator = new Breadcrumbs();
    }

    void Register(string name, Handler handler) {
        if (name in callbacks)
            throw new Exception("Breadcrumb name " ~ name ~ " has already been registered");
        callbacks[name] = handler;
    }

    bool Exists(string name) {
        auto itemPtr = name in callbacks;
        return itemPtr !is null;
    }

    BreadcrumbItem[] Generate(string name, Object[] params...) {
        string origName = name;

        if (name.empty) {
            return [];
        }

        try {
            return this.generator.Generate(this.callbacks, name, params);
        } catch (Exception ex) {
            return [];
        }
    }

    string Render(string name, Object[] params...) {
        BreadcrumbItem[] breadcrumbs = Generate(name, params);
        string r;
        bool isFirst = true;
        foreach(BreadcrumbItem item; breadcrumbs) {
            if(isFirst) {
                isFirst = false;
            } else {
                r ~= " / ";
            }
            r ~= item.title ~ "[url=\"" ~ item.link ~ "\"]";
        }
        return r;
    }


}

// private __gshared BreadcrumbsManager _breadcrumbsManager;

// BreadcrumbsManager breadcrumbsManager() {
//     if (_breadcrumbsManager is null) {
//         _breadcrumbsManager = new BreadcrumbsManager;
//     }

//     return _breadcrumbsManager;
// }
