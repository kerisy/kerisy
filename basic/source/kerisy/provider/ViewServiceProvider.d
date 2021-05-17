module kerisy.provider.ViewServiceProvider;

import kerisy.config.ApplicationConfig;
import kerisy.provider.ServiceProvider;
import kerisy.Init;
import kerisy.view.View;
import kerisy.view.Environment;

import hunt.logging.ConsoleLogger;
import poodinis;

import std.path;

/**
 * 
 */
class ViewServiceProvider : ServiceProvider {

    private ApplicationConfig _appConfig;

    override void register() {

        container.register!(View)(() {
            auto view = new View(new Environment);
            string path = buildNormalizedPath(APP_PATH, _appConfig.view.path);

            version (HUNT_DEBUG) {
                tracef("Setting the view path: %s", path);
            }

            view.SetTemplatePath(path)
                .SetTemplateExt(_appConfig.view.ext)
                .ArrayDepth(_appConfig.view.arrayDepth);

            return view;
        }).newInstance();
    }

    override void boot() {
        _appConfig = container.resolve!ApplicationConfig();
    }
}