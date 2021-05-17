module kerisy.provider.BreadcrumbServiceProvider;

import kerisy.provider.ServiceProvider;
import kerisy.breadcrumb.BreadcrumbsManager;
import kerisy.breadcrumb.Breadcrumbs;

import poodinis;

/**
 * 
 */
class BreadcrumbServiceProvider : ServiceProvider {

    BreadcrumbsManager breadcrumbs() {
        return container.resolve!BreadcrumbsManager();
    }

    override void register() {
        container.register!(BreadcrumbsManager).singleInstance();
    }
}
