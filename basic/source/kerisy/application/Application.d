/*
 * Kerisy - A high-level D Programming Language Web framework that encourages rapid development and clean, pragmatic design.
 *
 * Copyright (C) 2021, Kerisy.com
 *
 * Website: https://www.kerisy.com
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module kerisy.application.Application;

import kerisy.auth.AuthService;
import kerisy.application.HostEnvironment;
import kerisy.application.closer.RedisCloser;
import kerisy.command.ServeCommand;
import kerisy.Init;
import kerisy.http;
import kerisy.i18n.I18n;
import kerisy.config.ApplicationConfig;
import kerisy.config.ConfigManager;
import kerisy.middleware.MiddlewareInterface;
import kerisy.provider;
import kerisy.provider.listener;
import kerisy.routing;

import hunt.http.server.HttpServer;
import hunt.http.server.HttpServerOptions;
import hunt.http.WebSocketPolicy;
import hunt.http.WebSocketCommon;

import hunt.console;
import hunt.Functions;
import hunt.logging;
import hunt.redis;
import hunt.util.ResoureManager;
import hunt.util.worker;

version (WITH_HUNT_TRACE) {
    import hunt.http.HttpConnection;
    import hunt.net.util.HttpURI;
    import hunt.trace.Constrants;
    import hunt.trace.Endpoint;
    import hunt.trace.Span;
    import hunt.trace.Tracer;
    import hunt.trace.HttpSender;

    import std.format;
}

import poodinis;

import std.array;
import std.conv;
import std.meta;
import std.parallelism : totalCPUs;
import std.path;
import std.socket : Address, parseAddress;
import std.stdio;
import std.string;

alias DefaultServiceProviders = AliasSeq!(UserServiceProvider, AuthServiceProvider,
        ConfigServiceProvider, 
        TranslationServiceProvider, CacheServiceProvider, SessionServiceProvider,
        QueueServiceProvider, RedisServiceProvider,
        TaskServiceProvider, HttpServiceProvider, 
        BreadcrumbServiceProvider, ViewServiceProvider);
//  DatabaseServiceProvider, GrpcServiceProvider,   

alias ServiceRegistionHandler = void delegate(Application app);

private __gshared ServiceRegistionHandler[] _registionHandlers;

void registerService(T)() {
    _registionHandlers ~= (Application app) {
        app.register!(T);
    };
}

// private void registerHandler(ServiceRegistionHandler handler) {
//     _registionHandlers ~= (Application app) {
//         app.register!(GrpcServiceProvider);
//     };
// }


// private void onProviderRegisting(Application app) {
//     app.register!(GrpcServiceProvider);
// }
    
    // registerHandler(&onProviderRegisting);

/**
 * 
 */
final class Application {

    private string _name = DEFAULT_APP_NAME;
    private string _description = DEFAULT_APP_DESCRIPTION;
    private string _ver = DEFAULT_APP_VERSION;

    private HttpServer _server;
    private HttpServerOptions _serverOptions;
    private ApplicationConfig _appConfig;

    private bool _isBooted = false;
    private bool[TypeInfo] _customizedServiceProviders;
    private SimpleEventHandler _launchedHandler;
    private SimpleEventHandler _configuringHandler;
    private HostEnvironment _environment;
    private hunt.console.Command[] _commands;

    // private WebSocketPolicy _webSocketPolicy;
    // private WebSocketHandler[string] webSocketHandlerMap;

    private __gshared Application _app;

    static Application instance() {
        if (_app is null)
            _app = new Application();
        return _app;
    }

    this() {
        _environment = new HostEnvironment();
        SetDefaultLogging();
        InitializeProviderListener();
    }

    this(string name, string ver = DEFAULT_APP_VERSION, string description = DEFAULT_APP_DESCRIPTION) {
        _name = name;
        _ver = ver;
        _description = description;
        _environment = new HostEnvironment();

        SetDefaultLogging();
        InitializeProviderListener();
    }

    void register(T)() if (is(T : ServiceProvider)) {
        if (_isBooted) {
            warning("A provider can't be registered: %s after the app has been booted.", typeid(T));
            return;
        }

        shared(DependencyContainer) container = serviceContainer();

        ServiceProvider provider = new T();
        provider._container = container;
        provider.register();
        container.register!(ServiceProvider, T)().existingInstance(provider);
        container.autowire(provider);
        _providerListener.registered(typeid(T));

        static foreach (S; DefaultServiceProviders) {
            CheckCustomizedProvider!(T, S);
        }
    }

    private void TryRegister(T)() if (is(T : ServiceProvider)) {
        if (!IsRegistered!(T)) {
            register!T();
        }
    }

    private void CheckCustomizedProvider(T, S)() {
        static if (is(T : S)) {
            _customizedServiceProviders[typeid(S)] = true;
        }
    }

    private bool IsRegistered(T)() if (is(T : ServiceProvider)) {
        auto itemPtr = typeid(T) in _customizedServiceProviders;

        return itemPtr !is null;
    }

    // GrpcService grpc() {
    //     return serviceContainer().resolve!GrpcService();
    // }

    HostEnvironment Environment() {
        return _environment;
    }

    alias configuring = Booting;
    Application Booting(SimpleEventHandler handler) {
        _configuringHandler = handler;
        return this;
    }

    deprecated("Using booted instead.")
    alias onBooted = Booted;

    Application Booted(SimpleEventHandler handler) {
        _launchedHandler = handler;
        return this;
    }

    void register(hunt.console.Command cmd) {
        _commands ~= cmd;
    }

    void Run(string[] args, SimpleEventHandler handler) {
        _launchedHandler = handler;
        Run(args);
    }

    /**
      Start the HttpServer , and block current thread.
     */
    void Run(string[] args) {
        TryRegister!ConfigServiceProvider();

        ConfigManager manager = serviceContainer().resolve!ConfigManager;
        manager.hostEnvironment = _environment;

        if(_commands.length > 0) {
            _appConfig = serviceContainer().resolve!ApplicationConfig();
            Bootstrap();
            
            Console console = new Console(_description, _ver);
            console.setAutoExit(false);

            foreach(hunt.console.Command cmd; _commands) {
                console.add(cmd);
            }

            try {
                console.run(args);
            } catch(Exception ex) {
                warning(ex);
            } catch(Error er) {
                error(er);
            }

            return;
        }


        if (args.length > 1) {
            ServeCommand serveCommand = new ServeCommand();
            serveCommand.OnInput((ServeSignature signature) {
                version (HUNT_DEBUG) tracef(signature.to!string);

                //
                string configPath = signature.configPath;
                if(!configPath.empty()) {
                    _environment.configPath = signature.configPath;
                }

                //
                string envName = signature.environment;

                if(envName.empty()) {
                    _environment.name = DEFAULT_RUNTIME_ENVIRONMENT;
                } else {
                    _environment.name = envName;
                }

                // loading config
                _appConfig = serviceContainer().resolve!ApplicationConfig();

                //
                string host = signature.host;
                if(!host.empty()) {
                    _appConfig.http.address = host;
                }

                //
                ushort port = signature.port;
                if(port > 0) {
                    _appConfig.http.port = signature.port;
                }

                Bootstrap();
            });

            Console console = new Console(_description, _ver);
            console.setAutoExit(false);
            console.add(serveCommand);

            try {
                console.run(args);
            } catch(Exception ex) {
                warning(ex);
            } catch(Error er) {
                error(er);
            }

        } else {
            _appConfig = serviceContainer().resolve!ApplicationConfig();
            Bootstrap();
        }
    }

    /**
      Stop the server.
     */
    void Stop() {
        _server.stop();
    }

    // void registGrpcSerive(T)(){

    // }

    /**
     * https://laravel.com/docs/6.x/lifecycle
     */
    private void Bootstrap() {
        // _appConfig = serviceContainer().resolve!ApplicationConfig();

        // 
        RegisterProviders();

        //
        InitializeLogger();

        version (WITH_HUNT_TRACE) {
            initializeTracer();
        }

        // Resolve the HTTP server firstly
        _server = serviceContainer.resolve!(HttpServer);
        _serverOptions = _server.getHttpOptions();

        // 
        if(_configuringHandler !is null) {
            _configuringHandler();
        }

        // booting Providers
        BootProviders();

        //
        ShowLogo();

        // Launch the HTTP server.
        _server.start();

        // Notify that the application is ready.
        if(_launchedHandler !is null) {
            _launchedHandler();
        }
    }

    private void ShowLogo() {
        Address bindingAddress = parseAddress(_serverOptions.getHost(),
                cast(ushort) _serverOptions.getPort());

        // dfmt off
        string cliText = `

  _  __            _                    kerisy ` ~ KERISY_VERSION ~ `        
 | |/ / ___  _ __ (_) ___  _   _ 
 | ' / / _ \| '__|| |/ __|| | | |       Listening: ` ~ bindingAddress.toString() ~ `
 | . \|  __/| |   | |\__ \| |_| |       TLS: ` ~ (_serverOptions.isSecureConnectionEnabled() ? "Enabled" : "Disabled") ~ `
 |_|\_\\___||_|   |_||___/ \__, |       
                           |___/        https://www.kerisy.com 
                
`;
        writeln(cliText);
        // dfmt on

        if (_serverOptions.isSecureConnectionEnabled())
            writeln("Try to browse https://", bindingAddress.toString());
        else
            writeln("Try to browse http://", bindingAddress.toString());
    }

    Application ProviderLisener(ServiceProviderListener listener) {
        _providerListener = listener;
        return this;
    }

    ServiceProviderListener ProviderLisener() {
        return _providerListener;
    }

    private ServiceProviderListener _providerListener;

    private void InitializeProviderListener() {
        _providerListener = new DefaultServiceProviderListener;
    }

    /**
     * Register all the default service providers
     */
    private void RegisterProviders() {
        // Register all the default service providers
        static foreach (T; DefaultServiceProviders) {
            static if (!is(T == ConfigServiceProvider)) {
                TryRegister!T();
            }
        }

        foreach(ServiceRegistionHandler handler; _registionHandlers) {
            if(handler !is null) handler(this);
        }

        // Register all the service provided by the providers
        ServiceProvider[] providers = serviceContainer().resolveAll!(ServiceProvider);
        version(HUNT_DEBUG) infof("Registering all the service providers (%d)...", providers.length);

        // foreach(ServiceProvider p; providers) {
        //     p.register();
        //     _providerListener.registered(typeid(p));
        //     serviceContainer().autowire(p);
        // }

    }

    /**
     * Booting all the providers
     */
    private void BootProviders() {
        ServiceProvider[] providers = serviceContainer().resolveAll!(ServiceProvider);
        version(HUNT_DEBUG) infof("Booting all the service providers (%d)...", providers.length);

        foreach (ServiceProvider p; providers) {
            p.boot();
            _providerListener.booted(typeid(p));
        }
        _isBooted = true;
    }

    private void InitializeLogger() {
        ApplicationConfig.LoggingConfig conf = _appConfig.logging;
        hunt.logging.LogLevel level = hunt.logging.LogLevel.LOG_DEBUG;
        switch (toLower(conf.level)) {
        case "critical":
        case "error":
            level = hunt.logging.LogLevel.LOG_ERROR;
            break;
        case "fatal":
            level = hunt.logging.LogLevel.LOG_FATAL;
            break;
        case "warning":
            level = hunt.logging.LogLevel.LOG_WARNING;
            break;
        case "info":
            level = hunt.logging.LogLevel.LOG_INFO;
            break;
        case "off":
            level = hunt.logging.LogLevel.LOG_Off;
            break;
        default:
            break;
        }        
        // version (HUNT_DEBUG) {
        //     hunt.logging.LogLevel level = hunt.logging.LogLevel.Trace;
        //     switch (toLower(conf.level)) {
        //     case "critical":
        //     case "error":
        //         level = hunt.logging.LogLevel.Error;
        //         break;
        //     case "fatal":
        //         level = hunt.logging.LogLevel.Fatal;
        //         break;
        //     case "warning":
        //         level = hunt.logging.LogLevel.Warning;
        //         break;
        //     case "info":
        //         level = hunt.logging.LogLevel.Info;
        //         break;
        //     case "off":
        //         level = hunt.logging.LogLevel.Off;
        //         break;
        //     default:
        //         break;
        //     }
        // } else {
        //     hunt.logging.LogLevel level = hunt.logging.LogLevel.LOG_DEBUG;
        //     switch (toLower(conf.level)) {
        //     case "critical":
        //     case "error":
        //         level = hunt.logging.LogLevel.LOG_ERROR;
        //         break;
        //     case "fatal":
        //         level = hunt.logging.LogLevel.LOG_FATAL;
        //         break;
        //     case "warning":
        //         level = hunt.logging.LogLevel.LOG_WARNING;
        //         break;
        //     case "info":
        //         level = hunt.logging.LogLevel.LOG_INFO;
        //         break;
        //     case "off":
        //         level = hunt.logging.LogLevel.LOG_Off;
        //         break;
        //     default:
        //         break;
        //     }
        // }


        LogConf logconf;
        logconf.level = level;
        logconf.disableConsole = conf.disableConsole;

        if (!conf.file.empty)
            logconf.fileName = buildPath(conf.path, conf.file);

        logconf.maxSize = conf.maxSize;
        logconf.maxNum = conf.maxNum;

        logLoadConf(logconf);
    }

    version (WITH_HUNT_TRACE) {
        private void initializeTracer() {

            isTraceEnabled = _appConfig.trace.enable;

            // initialize HttpSender
            httpSender().endpoint(_appConfig.trace.zipkin);
        }
    }

    private void SetDefaultLogging() {
        version (HUNT_DEBUG) {
        } else {
            LogConf logconf;
            logconf.level = hunt.logging.LogLevel.LOG_Off;
            logconf.disableConsole = true;
            logLoadConf(logconf);
        }
    }

    // dfmtoff Some helpers
    import hunt.cache.Cache;
    // import hunt.entity.EntityManager;
    // import hunt.entity.EntityManagerFactory;
    import kerisy.breadcrumb.BreadcrumbsManager;
    import kerisy.queue;
    import kerisy.BasicSimplify;
    import kerisy.task;

    ApplicationConfig Config() {
        return _appConfig;
    }

    RouteConfigManager Route() {
        return serviceContainer.resolve!(RouteConfigManager);
    }

    AuthService Auth() {
        return serviceContainer.resolve!(AuthService);
    }

    Redis redis() {
        RedisPool pool = serviceContainer.resolve!RedisPool();
        Redis r = pool.getResource();
        registerResoure(new RedisCloser(r));
        return r;
    }

    RedisCluster redisCluster() {
        RedisCluster cluster = serviceContainer.resolve!RedisCluster();
        return cluster;
    }

    Cache cache() {
        return serviceContainer.resolve!(Cache);
    }

    TaskQueue Queue() {
        return serviceContainer.resolve!(TaskQueue);
    }

    Worker Task() {
        return serviceContainer.resolve!(Worker);
    }

    // deprecated("Using defaultEntityManager instead.")
    // EntityManager entityManager() {
    //     EntityManager _entityManager = serviceContainer.resolve!(EntityManagerFactory).currentEntityManager();
    //     registerResoure(new EntityCloser(_entityManager));
    //     return _entityManager;
    // }

    BreadcrumbsManager Breadcrumbs() {
        if(_breadcrumbs is null) {
            _breadcrumbs = serviceContainer.resolve!BreadcrumbsManager();
        }
        return _breadcrumbs;
    }
    private BreadcrumbsManager _breadcrumbs;

    I18n Translation() {
        return serviceContainer.resolve!(I18n);
    }
    // dfmton
}

/**
 * 
 */
Application app() {
    return Application.instance();
}
