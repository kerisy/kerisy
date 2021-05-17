module kerisy.provider.TranslationServiceProvider;

import kerisy.provider.ServiceProvider;
import kerisy.config.ApplicationConfig;

import kerisy.i18n.I18n;
import kerisy.Init;
import hunt.logging.ConsoleLogger;

import poodinis;
import std.path;

/**
 * 
 */
class TranslationServiceProvider : ServiceProvider {

    override void register() {
        container.register!(I18n)(() {
            ApplicationConfig config = container.resolve!ApplicationConfig();
            string langLocation = config.application.langLocation;
            langLocation = buildPath(DEFAULT_RESOURCE_PATH, langLocation); 

            I18n i18n = new I18n();
            i18n.DefaultLocale = config.application.defaultLanguage;
            i18n.LoadLangResources(langLocation);
            return i18n;
        }).singleInstance();
    }
}