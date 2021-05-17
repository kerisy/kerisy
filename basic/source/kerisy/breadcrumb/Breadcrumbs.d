module kerisy.breadcrumb.Breadcrumbs;

// import kerisy.BasicSimplify;
import kerisy.breadcrumb.BreadcrumbItem;
import std.container.array;
import std.array;

alias Handler = void delegate(Breadcrumbs crumb, Object[]...);

class Breadcrumbs {
    private Array!BreadcrumbItem items;
    private Handler[string] callbacks;

    BreadcrumbItem[] Generate(Handler[string] callbacks, string name, Object[] params...) {
        items.clear();
        this.callbacks = callbacks;
        this.Call(name, params);
        return items.array;
    }

    protected void Call(string name, Object[] params...) {
        auto itemPtr = name in callbacks;
        if (itemPtr is null)
            throw new Exception("Breadcrumb not found with name " ~ name);
        (*itemPtr)(this, params);
    }

    void Parent(string name, Object[] params...) {
        this.Call(name, params);
    }

    // void push(string mca, string[string] params) {
    //     push(mca, createUrl(mca, params));
    // }

    void Push(string title, string url) {
        BreadcrumbItem item = new BreadcrumbItem();
        item.title = title;
        item.link = url;

        items.insertBack(item);
    }

}
