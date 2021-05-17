module kerisy.http.session.SessionStorage;

import hunt.cache;
//import kerisy.Exceptions;
import kerisy.util.Random;
import hunt.Exceptions;

import std.array;
import std.algorithm;
import std.ascii;
import std.json;
import std.conv;
import std.digest.sha;
import std.format;
import std.datetime;
import std.random;
import std.string;
import std.traits;
import std.variant;

import core.cpuid;

import hunt.http.server.HttpSession;

/**
 * 
 */
class SessionStorage {
	this(Cache cache, string prefix="", int expire = 3600) {
		_cache = cache;
		_expire = expire;
		_prefix = prefix;
	}

	alias set = Put;

	bool Put(HttpSession session) {
		int expire = session.getMaxInactiveInterval;
		if(_expire < expire)
			expire = _expire;
		string key = session.getId();
		_cache.set(GetRealAddr(key), HttpSession.toJson(session), _expire);
		return true;
	}

	HttpSession Get(string key) {
		string keyWithPrefix = GetRealAddr(key);
		string s = cast(string) _cache.get!string(keyWithPrefix);
		if(s.empty) {
			// string sessionId = HttpSession.generateSessionId();
			// return HttpSession.create(sessionId, _sessionStorage.expire);
			return null;
		} else {
			_cache.set(keyWithPrefix , s , _expire);
			return HttpSession.fromJson(key, s);
		}
	}

	// string _get(string key) {
	// 	return cast(string) _cache.get!string(GetRealAddr(key));
	// }

	// alias isset = containsKey;
	bool ContainsKey(string key) {
		return _cache.hasKey(GetRealAddr(key));
	}

	// alias del = erase;
	// alias remove = erase;
	bool Remove(string key) {
		return _cache.remove(GetRealAddr(key));
	}

	static string GenerateSessionId(string sessionName = "hunt_session") {
		SHA1 hash;
		hash.start();
		hash.put(getRandom);
		ubyte[20] result = hash.finish();
		string str = toLower(toHexString(result));

		// JSONValue json;
		// json[sessionName] = str;
		// json["_time"] = cast(int)(Clock.currTime.toUnixTime) + _expire;

		// Put(str, json.toString, _expire);

		return str;
	}

	void SetPrefix(string prefix) {
		_prefix = prefix;
	}

	void Expire(int expire) @property {
		_expire = expire;
	}

	int Expire() @property {
		return _expire;
	}

	string GetRealAddr(string key) {
		return _prefix ~ key;
	}

	void Clear() {
		_cache.clear();
	}

	private {
		string _prefix;
		string _sessionId;

		int _expire;
		Cache _cache;
	}
}

