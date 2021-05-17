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

module kerisy.view.Template;

private
{
    import std.meta;
    import std.traits;

    import kerisy.view.Render;
    import kerisy.view.Lexer;
    import kerisy.view.Parser;
    import kerisy.view.Uninode;
    import kerisy.view.ast;
}

struct TemplateConfig
{
    string exprOpBegin  = "{{";
    string exprOpEnd    = "}}";
    string stmtOpBegin  = "{%";
    string stmtOpEnd    = "%}";
    string cmntOpBegin  = "{#";
    string cmntOpEnd    = "#}";
    string cmntOpInline = "##!";
    string stmtOpInline = "#!";
}

TemplateNode LoadData(TemplateConfig config = defaultConfig)(string tmpl)
{
    alias TemplateLexer = Lexer!(
                            config.exprOpBegin,
                            config.exprOpEnd,
                            config.stmtOpBegin,
                            config.stmtOpEnd,
                            config.cmntOpBegin,
                            config.cmntOpEnd,
                            config.stmtOpInline,
                            config.cmntOpInline
                        );

    Parser!TemplateLexer parser;
    return parser.parseTree(tmpl);
}

TemplateNode LoadFile(TemplateConfig config = defaultConfig)(string path)
{
    alias TemplateLexer = Lexer!(
                            config.exprOpBegin,
                            config.exprOpEnd,
                            config.stmtOpBegin,
                            config.stmtOpEnd,
                            config.cmntOpBegin,
                            config.cmntOpEnd,
                            config.stmtOpInline,
                            config.cmntOpInline
                        );

    Parser!TemplateLexer parser;
    return parser.ParseTreeFromFile(path);
}

string render(T...)(TemplateNode tree)
{
    alias Args = AliasSeq!T;
    alias Idents = staticMap!(Ident, T);

    auto render = new Render(tree);

    auto data = UniNode.EmptyObject();

    foreach (i, arg; Args)
    {
        static if (isSomeFunction!arg)
            render.registerFunction!arg(Idents[i]);
        else
            data[Idents[i]] = arg.serialize;
    }

    return render.render(data.serialize);
}

string RenderData(T...)(string tmpl)
{
    static if (T.length > 0 && is(typeof(T[0]) == TemplateConfig))
        return render!(T[1 .. $])(loadData!(T[0])(tmpl));
    else
        return render!(T)(loadData!defaultConfig(tmpl));
}

string RenderFile(T...)(string path)
{
    static if (T.length > 0 && is(typeof(T[0]) == TemplateConfig))
        return render!(T[1 .. $])(loadFile!(T[0])(path));
    else
        return render!(T)(loadFile!defaultConfig(path));
}



void Print(TemplateNode tree)
{
    auto printer = new Printer;
    tree.accept(printer);
}

private:

enum defaultConfig = TemplateConfig.init;

template Ident(alias A)
{
    enum Ident = __traits(identifier, A);
}
