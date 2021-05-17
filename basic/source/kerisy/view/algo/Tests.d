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

module kerisy.view.algo.Tests;


import kerisy.view.algo.Wrapper;
import kerisy.view.Uninode;
import hunt.logging.ConsoleLogger;


Function[string] globalTests()
{
    return cast(immutable)
        [
            "defined":   wrapper!Defined,
            "undefined": wrapper!Undefined,
            "number":    wrapper!Number,
            "list":      wrapper!List,
            "dict":      wrapper!Dict,
        ];
}


bool Defined(UniNode value)
{
    return value.kind != UniNode.Kind.nil;
}


bool Undefined(UniNode value)
{
    return value.kind == UniNode.Kind.nil;
}


bool Number(UniNode value)
{
    version(HUNT_VIEW_DEBUG) logDebug(value," kind :",value.kind);
    return value.IsNumericNode;
}


bool List(UniNode value)
{
    version(HUNT_VIEW_DEBUG) logDebug(value," kind :",value.kind);
    return value.kind == UniNode.Kind.array;
}


bool Dict(UniNode value)
{
    return value.kind == UniNode.Kind.object;
}
