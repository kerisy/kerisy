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

module kerisy.util.uninode.Serialization;

import std.stdio;

private
{
    import std.traits;
    import std.json;
    import kerisy.util.uninode.Core;
    import hunt.serialization.JsonSerializer;
}

/**
 * Serialize object to UniNode
 *
 * Params:
 * object = serialized object
 */
UniNode SerializeToUniNode(T)(T object)
{
    return _SerializeToUniNode!T(object);
}

/**
 * Deserialize object form UniNode
 *
 * Params:
 * src = UniNode value
 */
T DeserializeUniNode(T)(UniNode src)
{
    return _DeserializeUniNode!T(src);
}

/**
 * Serialize object to UniNode
 *
 * Params:
 * object = serialized object
 */
UniNode JsonToUniNode(JSONValue object)
{
    return _JsonToUniNode(object);
}

/**
 * Deserialize object form UniNode
 *
 * Params:
 * src = UniNode value
 */
JSONValue UniNodeToJSON(UniNode src)
{
    return _UniNodeToJSON(src);
}


private
{
    /**
    * Serialize object to UniNode
    *
    * Params:
    * object = serialized object
    */
    UniNode _SerializeToUniNode(T)(T object)
    {
        static if (is(T == UniNode))
        {
            return object;
        }
        else static if (isUniNodeType!(T, UniNode))
        {
            static if (isUniNodeInnerType!T)
            {
                return UniNode(object);
            }
            else static if (isUniNodeArray!(T, UniNode))
            {
                return UniNode(object);
            }
            else static if (isUniNodeObject!(T, UniNode))
            {
                return UniNode(object);
            }
        }
        else static if (is(T == struct) || is(T == class))
        {
            return _JsonToUniNode(toJson(object));
        }
        else static if (isStaticArray!T)
        {
            UniNode[object.length] nodes;
            foreach (node; object)
            {
                nodes ~= _SerializeToUniNode(node);
            }

            return UniNode(nodes);
        }
        else static if (isDynamicArray!T)
        {
            UniNode[] nodes;
            foreach (node; object)
            {
                nodes ~= _SerializeToUniNode(node);
            }

            return UniNode(nodes);
        }
    }

    /**
    * Convert JSONValue to UniNode
    *
    * Params:
    * data = JSONValue
    */
    UniNode _JsonToUniNode(JSONValue data)
    {
        if (data.type == JSONType.integer)
        {
            return UniNode(data.integer);
        }
        else if (data.type == JSONType.null_)
        {
            return UniNode((null));
        }
        else if (data.type == JSONType.string)
        {
            return UniNode(data.str);
        }
        else if (data.type == JSONType.false_)
        {
            return UniNode(false);
        }
        else if (data.type == JSONType.true_)
        {
            return UniNode(true);
        }
        else if (data.type == JSONType.float_)
        {
            return UniNode(data.floating);
        }
        else if (data.type == JSONType.uinteger)
        {
            return UniNode(data.uinteger);
        }
        else if (data.type == JSONType.array)
        {
            UniNode[] nodes;
            foreach (value; data.array)
            {
                nodes ~= _JsonToUniNode(value);
            }
            return UniNode(nodes);
        }
        else if (data.type == JSONType.object)
        {
            UniNode[string] node;
            foreach (k, v; data.object)
            {
                node[k] = _JsonToUniNode(v);
            }
            return UniNode(node);
        }
        return UniNode(null);
    }
    /**
    * Deserialize object form UniNode
    *
    * Params:
    * src = UniNode value
    */
    T _DeserializeUniNode(T)(UniNode src)
    {
        static if (is(T == UniNode))
        {
            return src;
        }
        else static if (isUniNodeType!(T, UniNode))
        {
            return src.get!T();
        }
        else static if (is(T == struct) || is(T == class))
        {
            return toObject!T(_UniNodeToJSON(src));
        }
        else
        {
            return unserialize!(T)(cast(byte[])(src.get!(ubyte[])));
        }
    }
    /**
    * Convert UniNode to JSONValue
    *
    * Params:
    * data = UniNode
    */
    JSONValue _UniNodeToJSON(UniNode node)
    {
        JSONValue data;
        if (node.kind == UniNode.Kind.nil)
        {
            return data;
        }
        else if (node.kind == UniNode.Kind.boolean)
        {
            data = node.get!bool();
        }
        else if (node.kind == UniNode.Kind.uinteger)
        {
            data = node.get!ulong();
        }
        else if (node.kind == UniNode.Kind.integer)
        {
            data = node.get!long();
        }
        else if (node.kind == UniNode.Kind.floating)
        {
            data = node.get!real();
        }
        else if (node.kind == UniNode.Kind.text)
        {
            data = node.get!string();
        }
        else if (node.kind == UniNode.Kind.raw)
        {
            data = node.get!(ubyte[])();
        }
        else if (node.kind == UniNode.Kind.array)
        {
            JSONValue[] values;
            foreach (value; node)
            {
                values ~= _UniNodeToJSON(value);
            }
            data = values;
        }
        else if (node.kind == UniNode.Kind.object)
        {
            foreach (string k, UniNode v; node)
            {
                data[k] = _UniNodeToJSON(v);
            }
        }
        return data;
    }
}
