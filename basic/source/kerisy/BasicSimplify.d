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

module kerisy.BasicSimplify;

public import kerisy.config.ApplicationConfig;
public import kerisy.config.ConfigManager;
public import kerisy.Init;
public import kerisy.routing;
public import hunt.util.DateTime : time, date;

import kerisy.provider;
import hunt.logging.ConsoleLogger;
import hunt.util.TaskPool;
import hunt.util.ResoureManager;

import poodinis;

import std.array;
import std.string;
import std.json;

ConfigManager configManager() {
    return serviceContainer().resolve!(ConfigManager);
}

ApplicationConfig config() {
    return serviceContainer().resolve!(ApplicationConfig);
}

RouteConfigManager routeConfig() {
    return serviceContainer().resolve!(RouteConfigManager);
}

string Url(string mca) {
    return Url(mca, null);
}


string Url(string mca, string[string] params, string group) {
    return routeConfig().CreateUrl(mca, params, group);
}

string Url(string mca, string[string] params) {
    // admin:user.user.view
    string[] items = mca.split(":");
    string group = "";
    string pathItem = "";
    if (items.length == 1) {
        group = "";
        pathItem = mca;
    } else if (items.length == 2) {
        group = items[0];
        pathItem = items[1];
    } else {
        throw new Exception("Bad format for mca");
    }

    // return app().createUrl(pathItem, params, group);
    return routeConfig().CreateUrl(pathItem, params, group);
}

// public import hunt.entity.EntityManager;

// import hunt.entity.DefaultEntityManagerFactory;
// import hunt.entity.EntityManagerFactory;
// import kerisy.application.closer.EntityCloser;
// import hunt.util.Common;

// version(HUNT_TEST) {
//     import std.datetime;
//     import std.format;
//     import core.atomic;
//     import core.sync.mutex;
//     import core.thread ;

//     import kerisy.http.Request;
//     import hunt.util.ThreadHelper;
//     import hunt.collection.ArrayList;
//     import hunt.collection.ArrayList;


//     class EntityManagerInfo {
//         ThreadID threadId;
//         int number;
//         string path;
//         SysTime holdUpTime;
//         SysTime releaseTime;
//         // string connection;

//         this() {
//             threadId = getTid();
//             holdUpTime = Clock.currTime;
//             releaseTime = holdUpTime;
//             number = atomicOp!"+="(counter, 1);
//             Request req = request();
//             if(req is null) {
//                 warning("Called from a non-Controller thread.");
//             } else {
//                 path = req.Path();
//             }
//         }

//         override string toString() {
//             string str = format("%6d | %05d | %s | %s | %s | %s", 
//                 threadId, number, holdUpTime, releaseTime, releaseTime-holdUpTime, path);

//             return str;
//         }

//         shared static int counter;
//         __gshared EntityManagerInfo[] _entityManagers;
//         __gshared Mutex _mtx;

//         shared static this() {
//             // entityManagers = new ArrayList!EntityManagerInfo(500);
//             _mtx = new Mutex();
//         }

//         static void append() {
//             EntityManagerInfo managerInfo = new EntityManagerInfo();
//             _mtx.lock();
//             scope(exit) _mtx.unlock();
//             _entityManagers ~= managerInfo;

//             error(managerInfo.toString());
//         }

//         static void remove() {
//             ThreadID tid = getTid();
            
//             string reqPath;
//             Request req = request();
//             if(req !is null)
//                 reqPath = req.Path();

//             _mtx.lock();
//             scope(exit) _mtx.unlock();

//             bool isRemoved = false;
//             foreach(size_t index, EntityManagerInfo managerInfo; _entityManagers) {
//                 if(managerInfo.threadId == tid && managerInfo.path == reqPath) {
//                     managerInfo.releaseTime = Clock.currTime;

//                     error(managerInfo);
//                     if(index == 0) {
//                         _entityManagers = _entityManagers[index+1 .. $];
//                     } else if(index + 1 == _entityManagers.length) {
//                         _entityManagers =  _entityManagers[0 .. index];
//                     } else {
//                         _entityManagers =  _entityManagers[0 .. index] ~  _entityManagers[index+1 .. $];
//                     }
//                     isRemoved = true;
//                     break;
//                 }

//                 if(!isRemoved) {
//                     warningf("Nothing removed: ", tid, reqPath);
//                 }
//             }
//         }

//         static string[] listAll() {
//             string[] result;
//             _mtx.lock();
//             scope(exit) _mtx.unlock();

//             foreach(EntityManagerInfo managerInfo; _entityManagers) {
//                 result ~= managerInfo.toString();
//             }

//             return result;
//         }
//     }


//     //global entity manager
//     private EntityManager _em;
//     EntityManager defaultEntityManager() {
//         if (_em is null) {
//             _em = serviceContainer.resolve!(EntityManagerFactory).currentEntityManager();
//             registerResoure(new class Closeable {
//                 void close() {
//                     closeDefaultEntityManager();
//                     EntityManagerInfo.remove();
//                 }
//             });

//             EntityManagerInfo.append();
//         }
//         return _em;
//     }

// } else {
//     //global entity manager
//     private EntityManager _em;
//     EntityManager defaultEntityManager() {
//         if (_em is null) {
//             _em = serviceContainer.resolve!(EntityManagerFactory).currentEntityManager();
//             registerResoure(new class Closeable {
//                 void close() {
//                     closeDefaultEntityManager();
//                 }
//             });
//         }
//         return _em;
//     }
// }

// //close global entity manager
// void closeDefaultEntityManager() {
//     if (_em !is null) {
//         _em.close();
//         _em = null;
//     }
// }

// i18n
import kerisy.i18n.I18n;

private __gshared string _local /* = I18N_DEFAULT_LOCALE */ ;

@property string GetLocale() {
    if (_local)
        return _local;
    return serviceContainer.resolve!(I18n).DefaultLocale;
}

@property SetLocale(string _l) {
    _local = toLower(_l);
}

string Trans(A...)(string key, lazy A args) {
    import std.format;

    Appender!string buffer;
    string text = _Trans(key);
    version (HUNT_DEBUG)
        tracef("format string: %s, key: %s, args.length: ", text, key, args.length);
    formattedWrite(buffer, text, args);

    return buffer.data;
}

string TransWithLocale(A...)(string locale, string key, lazy A args) {
    import std.format;

    Appender!string buffer;
    string text = _TransWithLocale(locale, key);
    formattedWrite(buffer, text, args);

    return buffer.data;
}

string TransWithLocale(string locale, string key, JSONValue args) {
    import kerisy.util.Formatter;

    string text = _TransWithLocale(locale, key);
    return StrFormat(text, args);
}

///key is [filename.key]
private string _Trans(string key) {
    string defaultValue = key;
    I18n i18n = serviceContainer.resolve!(I18n);
    if (!i18n.IsResLoaded) {
        logWarning("The lang resources haven't loaded yet!");
        return key;
    }

    auto p = GetLocale in i18n.Resources;
    if (p !is null) {
        return p.get(key, defaultValue);
    }
    logWarning("unsupported local: ", GetLocale, ", use default now: ", i18n.DefaultLocale);

    p = i18n.DefaultLocale in i18n.Resources;

    if (p !is null) {
        return p.get(key, defaultValue);
    }

    logWarning("unsupported locale: ", i18n.DefaultLocale);

    return defaultValue;
}

///key is [filename.key]
private string _TransWithLocale(string locale, string key) {
    string defaultValue = key;
    I18n i18n = serviceContainer.resolve!(I18n);
    if (!i18n.IsResLoaded) {
        logWarning("The lang resources has't loaded yet!");
        return key;
    }

    auto p = locale in i18n.Resources;
    if (p !is null) {
        return p.get(key, defaultValue);
    }
    version(HUNT_DEBUG) { 
        logWarning("No language resource found for ", locale, 
            ". Use the default now: ", i18n.DefaultLocale);
    }

    locale = i18n.DefaultLocale;
    p = locale in i18n.Resources;

    if (p !is null) {
        return p.get(key, defaultValue);
    }

    warning("No language resource found for: ", locale);

    return defaultValue;
}


import hunt.util.worker;

TaskQueue taskQueue() {
    return serviceContainer.resolve!(TaskQueue);
}