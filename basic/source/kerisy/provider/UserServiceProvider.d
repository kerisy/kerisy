module kerisy.provider.UserServiceProvider;


import kerisy.provider.ServiceProvider;
import kerisy.auth.SimpleUserService;
import kerisy.auth.UserService;

import hunt.logging.ConsoleLogger;
import poodinis;


/**
 * 
 */
class UserServiceProvider : ServiceProvider {
    
    override void register() {
        container.register!(UserService, SimpleUserService).singleInstance();
    }
}