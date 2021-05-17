module kerisy.auth.AuthService;

import kerisy.auth.guard;

import hunt.logging.ConsoleLogger;

/**
 * 
 */
class AuthService {

    private Guard[string] _guards;

    void AddGuard(Guard guard) {
        string name = guard.name();
        _guards[name] = guard;
    }

    Guard guard(string name) {
        auto itemPtr = name in _guards;
        if(itemPtr is null) {
            warning("No guard found: " ~ name);
            return null;
        }
        return *itemPtr;
    }

    Guard[] Guards() {
        return _guards.values;
    }

    void boot() {

        foreach(string key, Guard g; _guards) {
            g.boot();
        }

    }
}