module kerisy.provider.QueueServiceProvider;

import kerisy.provider.ServiceProvider;
import kerisy.config.ApplicationConfig;
import kerisy.queue;

import hunt.redis;
import hunt.logging.ConsoleLogger;

import poodinis;

/**
 * 
 */
class QueueServiceProvider : ServiceProvider {

    override void register() {
        container.register!(TaskQueue)(&build).singleInstance();
    }

    protected TaskQueue build() {
        ApplicationConfig config = container.resolve!ApplicationConfig();
        if(config.queue.enabled) {
            QueueManager manager = new QueueManager(config);
            return manager.Build();
        } else {
            // return null;
            throw new Exception("Queue is disabled.");
        }
    }
}
