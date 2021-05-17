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

module kerisy.view.Uninode;

public
{
    import kerisy.util.uninode.Core;
    import kerisy.util.uninode.Serialization :
                serialize = SerializeToUniNode,
                deserialize = DeserializeUniNode;
}


import std.array;
import std.algorithm : among, map, sort;
import std.conv : to;
import std.format: fmt = format;
import std.typecons : Tuple, tuple;

import hunt.logging.ConsoleLogger;

import kerisy.view.Lexer;
import kerisy.view.Exception : TemplateRenderException,
                            assertTemplate = assertTemplateRender;


bool IsNumericNode(ref UniNode n)
{
    return cast(bool)n.kind.among!(
            UniNode.Kind.integer,
            UniNode.Kind.uinteger,
            UniNode.Kind.floating
        );
}


bool IsIntNode(ref UniNode n)
{
    return cast(bool)n.kind.among!(
            UniNode.Kind.integer,
            UniNode.Kind.uinteger
        );
}


bool IsFloatNode(ref UniNode n)
{
    return n.kind == UniNode.Kind.floating;
}


bool IsIterableNode(ref UniNode n)
{
    return cast(bool)n.kind.among!(
            UniNode.Kind.array,
            UniNode.Kind.object,
            UniNode.Kind.text
        );
}

void ToIterableNode(ref UniNode n)
{
    switch (n.kind) with (UniNode.Kind)
    {
        case array:
            return;
        case text:
            auto a = n.get!string.map!(a => UniNode(cast(string)[a])).array;
            if(!a.empty())
                n = UniNode(a);
            return;
        case object:
            UniNode[] arr;
            auto items = n.get!(UniNode[string]);
            if(items !is null) {
                foreach (key, val; items)
                    arr ~= UniNode([UniNode(key), val]);
                n = UniNode(arr);
            }
            return;
        default:
            throw new TemplateRenderException("Can't implicity convert type %s to iterable".fmt(n.kind));
    }
}

void ToCommonNumType(ref UniNode n1, ref UniNode n2)
{
    assertTemplate(n1.IsNumericNode, "Not a numeric type of %s".fmt(n1));
    assertTemplate(n2.IsNumericNode, "Not a numeric type of %s".fmt(n2));

    if (n1.IsIntNode && n2.IsFloatNode)
    {
        n1 = UniNode(n1.get!long.to!double);
        return;
    }

    if (n1.IsFloatNode && n2.IsIntNode)
    {
        n2 = UniNode(n2.get!long.to!double);
        return;
    }
}


void ToCommonCmpType(ref UniNode n1, ref UniNode n2)
{
   if (n1.IsNumericNode && n2.IsNumericNode)
   {
       ToCommonNumType(n1, n2);
       return;
   }
   if (n1.kind != n2.kind)
       throw new TemplateRenderException("Not comparable types %s and %s".fmt(n1.kind, n2.kind));
}


void ToBoolType(ref UniNode n)
{
    switch (n.kind) with (UniNode.Kind)
    {
        case boolean:
            return;
        case integer:
        case uinteger:
            n = UniNode(n.get!long != 0);
            return;
        case floating:
            n = UniNode(n.get!double != 0);
            return;
        case text:
            n = UniNode(n.get!string.length > 0);
            return;
        case array:
        case object:
            n = UniNode(n.length > 0);
            return;
        case nil:
            n = UniNode(false);
            return;
        default:
            throw new TemplateRenderException("Can't cast type %s to bool".fmt(n.kind));
    }
}


void ToStringType(ref UniNode n)
{
    import std.algorithm : map;
    import std.string : join;

    string getString(UniNode n)
    {
        bool quotes = n.kind == UniNode.Kind.text;
        n.ToStringType;
        if (quotes)
            return "'" ~ n.get!string ~ "'";
        else
            return n.get!string;
    }

    string doSwitch()
    {
        final switch (n.kind) with (UniNode.Kind)
        {
            case nil:      return "";
            case boolean:  return n.get!bool.to!string;
            case integer:  return n.get!long.to!string;
            case uinteger: return n.get!ulong.to!string;
            case floating: return n.get!double.to!string;
            case text:     return n.get!string;
            case raw:      return n.get!(ubyte[]).to!string;
            case array:    return "["~n.get!(UniNode[]).map!(a => getString(a)).join(", ").to!string~"]";
            case object:
                string[] results;
                Tuple!(string, UniNode)[] sorted = [];
                foreach (string key, ref value; n)
                    results ~= key ~ ": " ~ getString(value);
                return "{" ~ results.join(", ").to!string ~ "}";
        }
    }

    n = UniNode(doSwitch());
}


string GetAsString(UniNode n)
{
    n.ToStringType;
    return n.get!string;
}


void CheckNodeType(ref UniNode n, UniNode.Kind kind, Position pos)
{
    if (n.kind != kind)
        assertTemplate(0, "Unexpected expression type `%s`, expected `%s`".fmt(n.kind, kind), pos);
}



UniNode Unary(string op)(UniNode lhs)
    if (op.among!(Operator.Plus,
                 Operator.Minus)
    )
{
    assertTemplate(lhs.IsNumericNode, "Expected int got %s".fmt(lhs.kind));

    if (lhs.IsIntNode)
        return UniNode(mixin(op ~ "lhs.get!long"));
    else
        return UniNode(mixin(op ~ "lhs.get!double"));
}



UniNode Unary(string op)(UniNode lhs)
    if (op == Operator.Not)
{
    lhs.ToBoolType;
    return UniNode(!lhs.get!bool);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Plus,
                 Operator.Minus,
                 Operator.Mul)
    )
{
    ToCommonNumType(lhs, rhs);
    if (lhs.IsIntNode)
        return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
    else
        return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.DivInt)
{
    assertTemplate(lhs.IsIntNode, "Expected int got %s".fmt(lhs.kind));
    assertTemplate(rhs.IsIntNode, "Expected int got %s".fmt(rhs.kind));
    return UniNode(lhs.get!long / rhs.get!long);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.DivFloat
        || op == Operator.Rem)
{
    ToCommonNumType(lhs, rhs);

    if (lhs.IsIntNode)
    {
        assertTemplate(rhs.get!long != 0, "Division by zero!");
        return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
    }
    else
    {
        assertTemplate(rhs.get!double != 0, "Division by zero!");
        return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
    }
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Pow)
{
    ToCommonNumType(lhs, rhs);
    if (lhs.IsIntNode)
        return UniNode(lhs.get!long ^^ rhs.get!long);
    else
        return UniNode(lhs.get!double ^^ rhs.get!double);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Eq, Operator.NotEq))
{
    ToCommonCmpType(lhs, rhs);
    return UniNode(mixin("lhs" ~ op ~ "rhs"));
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Less,
                  Operator.LessEq,
                  Operator.Greater,
                  Operator.GreaterEq)
       )
{
    ToCommonCmpType(lhs, rhs);
    switch (lhs.kind) with (UniNode.Kind)
    {
        case integer:
        case uinteger:
            return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
        case floating:
            return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
        case text:
            return UniNode(mixin("lhs.get!string" ~ op ~ "rhs.get!string"));
        default:
            throw new TemplateRenderException("Not comparable type %s".fmt(lhs.kind));
    }
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Or)
{
    lhs.ToBoolType;
    rhs.ToBoolType;
    return UniNode(lhs.get!bool || rhs.get!bool);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.And)
{
    lhs.ToBoolType;
    rhs.ToBoolType;
    return UniNode(lhs.get!bool && rhs.get!bool);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Concat)
{
    lhs.ToStringType;
    rhs.ToStringType;
    return UniNode(lhs.get!string ~ rhs.get!string);
}



UniNode Binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.In)
{
    import std.algorithm.searching : countUntil;

    switch (rhs.kind) with (UniNode.Kind)
    {
        case array:
            foreach(val; rhs)
            {
                if (val == lhs)
                    return UniNode(true);
            }
            return UniNode(false);
        case object:
            if (lhs.kind != UniNode.Kind.text)
                return UniNode(false);
            return UniNode(cast(bool)(lhs.get!string in rhs));
        case text:
            if (lhs.kind != UniNode.Kind.text)
                return UniNode(false);
            return UniNode(rhs.get!string.countUntil(lhs.get!string) >= 0);
        default:
            return UniNode(false);
    }
}
