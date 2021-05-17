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

module kerisy.DbSimplify;

import kerisy.application.Application;

import hunt.entity.EntityManager;

import kerisy.provider.ServiceProvider;
import hunt.entity.DefaultEntityManagerFactory;
import hunt.entity.EntityManagerFactory;
import hunt.util.Common;
import hunt.util.ResoureManager;

version(HUNT_TEST)
{
    import std.datetime;
    import std.format;

    import core.atomic;
    import core.sync.mutex;
    import core.thread;

    import kerisy.http.Request;

    import hunt.util.ThreadHelper;
    import hunt.collection.ArrayList;
    import hunt.collection.ArrayList;

    class EntityManagerInfo
    {
        ThreadID threadId;
        int number;
        string path;
        SysTime holdUpTime;
        SysTime releaseTime;
        // string connection;

        this() {
            threadId = getTid();
            holdUpTime = Clock.currTime;
            releaseTime = holdUpTime;
            number = atomicOp!"+="(counter, 1);
            Request req = request();
            if(req is null) {
                warning("Called from a non-Controller thread.");
            } else {
                path = req.Path();
            }
        }

        override string toString() {
            string str = format("%6d | %05d | %s | %s | %s | %s", 
                threadId, number, holdUpTime, releaseTime, releaseTime-holdUpTime, path);

            return str;
        }

        shared static int counter;
        __gshared EntityManagerInfo[] _entityManagers;
        __gshared Mutex _mtx;

        shared static this() {
            // entityManagers = new ArrayList!EntityManagerInfo(500);
            _mtx = new Mutex();
        }

        static void append() {
            EntityManagerInfo managerInfo = new EntityManagerInfo();
            _mtx.lock();
            scope(exit) _mtx.unlock();
            _entityManagers ~= managerInfo;

            error(managerInfo.toString());
        }

        static void remove() {
            ThreadID tid = getTid();
            
            string reqPath;
            Request req = request();
            if(req !is null)
                reqPath = req.Path();

            _mtx.lock();
            scope(exit) _mtx.unlock();

            bool isRemoved = false;
            foreach(size_t index, EntityManagerInfo managerInfo; _entityManagers) {
                if(managerInfo.threadId == tid && managerInfo.path == reqPath) {
                    managerInfo.releaseTime = Clock.currTime;

                    error(managerInfo);
                    if(index == 0) {
                        _entityManagers = _entityManagers[index+1 .. $];
                    } else if(index + 1 == _entityManagers.length) {
                        _entityManagers =  _entityManagers[0 .. index];
                    } else {
                        _entityManagers =  _entityManagers[0 .. index] ~  _entityManagers[index+1 .. $];
                    }
                    isRemoved = true;
                    break;
                }

                if(!isRemoved) {
                    warningf("Nothing removed: ", tid, reqPath);
                }
            }
        }

        static string[] listAll() {
            string[] result;
            _mtx.lock();
            scope(exit) _mtx.unlock();

            foreach(EntityManagerInfo managerInfo; _entityManagers) {
                result ~= managerInfo.toString();
            }

            return result;
        }
    }


    //global entity manager
    private EntityManager _em;
    EntityManager defaultEntityManager() {
        if (_em is null) {
            _em = serviceContainer.resolve!(EntityManagerFactory).currentEntityManager();
            registerResoure(new class Closeable {
                void close() {
                    closeDefaultEntityManager();
                    EntityManagerInfo.remove();
                }
            });

            EntityManagerInfo.append();
        }
        return _em;
    }

} else {
    //global entity manager
    private EntityManager _em;
    EntityManager defaultEntityManager() {
        if (_em is null) {
            _em = serviceContainer.resolve!(EntityManagerFactory).currentEntityManager();
            registerResoure(new class Closeable {
                void close() {
                    closeDefaultEntityManager();
                }
            });
        }
        return _em;
    }
}

//close global entity manager
void closeDefaultEntityManager() {
    if (_em !is null) {
        _em.close();
        _em = null;
    }
}
