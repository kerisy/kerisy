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

module kerisy.view.Util;

import std.stdio;
import std.regex;

class Util
{
    static string[string] ParseFormData(string idstring)
    {
        import std.string;
        string[string] params;
        auto idstr = strip(idstring);
        string[] param_section;
        param_section = split(idstr, '&');
        foreach(section; param_section) {
            auto param = split(section,"=");
            if(param.length == 2)
            {
                params[param[0]] = param[1];
            }
        }

        return params;
    }
}
