module kerisy.provider.SessionServiceProvider;

import kerisy.provider.ServiceProvider;
import kerisy.config.ApplicationConfig;

import kerisy.http.session.SessionStorage;
import kerisy.Init;
import hunt.cache.Cache;

import poodinis;

/**
 * 
 */
class SessionServiceProvider : ServiceProvider {

    override void register() {
        container.register!(SessionStorage)(() {
            ApplicationConfig config = container.resolve!ApplicationConfig();
            Cache cache = container.resolve!Cache;
            return new SessionStorage(cache, config.session.prefix, config.session.expire);
        }).singleInstance();
    }
}