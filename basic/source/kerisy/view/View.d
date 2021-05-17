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

module kerisy.view.View;

import kerisy.view.Environment;
import kerisy.view.Template;
import kerisy.view.Util;
import kerisy.view.Exception;
import kerisy.Init;

// import kerisy.BasicSimplify;

import hunt.serialization.JsonSerializer;
import hunt.logging;

import std.json : JSONValue;
import std.path;

class View {
    private {
        string _templatePath = "./views/";
        string _extName = ".html";
        uint _arrayDepth = 3;
        Environment _env;
        string _routeGroup = DEFAULT_ROUTE_GROUP;
        JSONValue _context;
    }

    this(Environment env) {
        _env = env;
    }

    Environment env() {
        return _env;
    }

    View SetTemplatePath(string path) {
        _templatePath = path;
        _env.SetTemplatePath(path);

        return this;
    }

    View SetTemplateExt(string fileExt) {
        _extName = fileExt;
        return this;
    }

    string GetTemplatePath() {
        return _templatePath;
    }

    View SetRouteGroup(string rg) {
        _routeGroup = rg;
        //if (_routeGroup != DEFAULT_ROUTE_GROUP)
        _env.SetRouteGroup(rg);
        _env.SetTemplatePath(buildNormalizedPath(_templatePath) ~ dirSeparator ~ _routeGroup);

        return this;
    }

    View SetLocale(string locale) {
        _env.SetLocale(locale);
        return this;
    }

    int ArrayDepth() {
        return _arrayDepth;
    }

    View ArrayDepth(int value) {
        _arrayDepth = value;
        return this;
    }

    string render(string tempalteFile) {
        version (HUNT_VIEW_DEBUG) {
            tracef("---tempalteFile: %s, _extName:%s, rend context: %s",
                    tempalteFile, _extName, _context.toString);
        }
        return _env.RenderFile(tempalteFile ~ _extName, _context);
    }

    void Assign(T)(string key, T t) {
        this.Assign(key, toJson(t));
    }

    void Assign(string key, JSONValue t) {
        _context[key] = t;
    }
}

