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

module kerisy.view.Environment;

import kerisy.BasicSimplify;
import kerisy.view.Template;
import kerisy.view.Render;
import kerisy.view.Lexer;
import kerisy.view.Parser;
import kerisy.view.Uninode;
import kerisy.view.ast;
import kerisy.util.uninode.Serialization;

import kerisy.http.Request;
import kerisy.Init;

import hunt.logging.ConsoleLogger;

import std.meta;
import std.traits;
import std.string;
import std.json;
import std.file;
import std.path;
import std.stdio;


class Environment
{
    private 
    {
        Request _request;
        string input_path;
        string output_path;

        alias TemplateLexer = Lexer!(TemplateConfig.init.exprOpBegin,
                TemplateConfig.init.exprOpEnd, TemplateConfig.init.stmtOpBegin, TemplateConfig.init.stmtOpEnd,
                TemplateConfig.init.cmntOpBegin, TemplateConfig.init.cmntOpEnd, TemplateConfig.init.stmtOpInline, TemplateConfig.init.cmntOpInline);
        Parser!TemplateLexer _parser;

        string _routeGroup = DEFAULT_ROUTE_GROUP;
        string _locale = "en-us";
    }

    this()
    {
        auto tpl_path = config().view.path;
        if (tpl_path.length == 0)
            tpl_path = "./views/";
        string p = buildPath(APP_PATH, buildNormalizedPath(tpl_path));
        input_path = output_path = p ~ dirSeparator;
    }

    this(string global_path)
    {
        input_path = output_path = buildNormalizedPath(global_path) ~ dirSeparator;
    }

    this(string input_path, string output_path)
    {
        this.input_path = buildNormalizedPath(input_path) ~ dirSeparator;
        this.output_path = buildNormalizedPath(output_path) ~ dirSeparator;
    }

    Request request() {
        return _request;
    }

    void request(Request value) {
        _request = value;
    }

    void SetRouteGroup(string rg)
    {
        _routeGroup = rg;
    }

    void SetLocale(string locale)
    {
        _locale = locale;
    }

    void SetTemplatePath(string path)
    {
        this.input_path = buildNormalizedPath(path) ~ dirSeparator;
    }

    TemplateNode Parse_template(string filename)
    {
        version (HUNT_FM_DEBUG) trace("parse template file: ", input_path ~ filename);
        return _parser.ParseTreeFromFile(input_path ~ filename);
    }

    string render(TemplateNode tree,JSONValue data)
    {
        import kerisy.util.uninode.Serialization;

        auto render = new Render(tree);
        render.setRouteGroup(_routeGroup);
        render.setLocale(_locale);
        render.request = _request;
        return render.render(JsonToUniNode(data));
    }

    string RenderFile(string path,JSONValue data)
    {
         return render(Parse_template(path),data);
    }

    string render(string str,JSONValue data)
    {
        auto tree = _parser.ParseTree(str,"",input_path);
        auto render = new Render(tree);
        render.setRouteGroup(_routeGroup);
        render.setLocale(_locale);
        render.request = _request;
        return render.render(JsonToUniNode(data));
    } 
}
