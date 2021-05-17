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

module kerisy.view.algo.Filters;

private
{
    import kerisy.view.algo.Wrapper;
    import kerisy.view.Uninode;
}

// dfmt off
Function[string] GlobalFilters()
{
    return cast(immutable)
        [
            "default": wrapper!DefaultVal,
            "d":       wrapper!DefaultVal,
            "escape":  wrapper!Escape,
            "e":       wrapper!Escape,
            "upper":   wrapper!Upper,
            "lower":   wrapper!Lower, 
            "sort":    wrapper!Sort,
            "keys":    wrapper!Keys,
        ];
}
// dfmt on

UniNode DefaultVal(UniNode value, UniNode default_value = UniNode(""), bool boolean = false)
{
    if (value.kind == UniNode.Kind.nil)
        return default_value;

    if (!boolean)
        return value;

    value.ToBoolType;
    if (!value.get!bool)
        return default_value;

    return value;
}


string Escape(string s)
{
    import std.array : appender;

    auto w = appender!string;
    w.reserve(s.length);

    foreach (char ch; s)
        switch (ch)
        {
            case '&':  w.put("&amp;");  break;
            case '\"': w.put("&quot;"); break;
            case '\'': w.put("&apos;"); break;
            case '<':  w.put("&lt;");   break;
            case '>':  w.put("&gt;");   break;
            default:   w.put(ch);       break;
        }

    return w.data;
}


string Upper(string str)
{
    import std.uni : toUpper;
    return str.toUpper;
}

string Lower(string str)
{
    import std.uni : toLower;
    return str.toLower;
}

UniNode Sort(UniNode value)
{
    import std.algorithm : sort;

    switch (value.kind) with (UniNode.Kind)
    {
        case array:
            auto arr = value.get!(UniNode[]);
            sort!((a, b) => a.GetAsString < b.GetAsString)(arr);
            return UniNode(arr);

        case object:
            UniNode[] arr;
            foreach (string key, val; value)
                arr ~= UniNode([UniNode(key), val]);
            sort!"a[0].get!string < b[0].get!string"(arr);
            return UniNode(arr);

        default:
            return value;
    }
}


UniNode Keys(UniNode value)
{
    if (value.kind != UniNode.Kind.object)
        return UniNode(null);

    UniNode[] arr;
    foreach (string key, val; value)
        arr ~= UniNode(key);
    return UniNode(arr);
}
