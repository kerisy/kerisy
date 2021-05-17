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

module kerisy.view.Render;


private
{
    import std.range;
    import std.format: fmt = format;

    import kerisy.view.ast.Node;
    import kerisy.view.ast.Visitor;
    import kerisy.view.algo;
    import kerisy.view.algo.Wrapper;
    import kerisy.view.Lexer;
    import kerisy.view.Parser;
    import kerisy.view.Exception : TemplateRenderException,
                              assertTemplate = assertTemplateRender;

    import kerisy.view.Uninode;
    import kerisy.http.Request;

    import kerisy.BasicSimplify;
    import kerisy.view.Util;
    import hunt.logging.ConsoleLogger;
}




struct FormArg
{
    string name;
    Nullable!UniNode def;

    this (string name)
    {
        this.name = name;
        this.def = Nullable!UniNode.init;
    }

    this (string name, UniNode def)
    {
        this.name = name;
        this.def = Nullable!UniNode(def);
    }
}


struct Macro
{
    FormArg[] args;
    Nullable!Context context;
    Nullable!Node block;

    this(FormArg[] args, Context context, Node block)
    {
        this.args = args;
        this.context = context.toNullable;
        this.block = block.toNullable;
    }
}


class Context
{
    private Context prev;

    UniNode data;
    Function[string] functions;
    Macro[string] macros;

    this ()
    {
        prev = null;
        data = UniNode.EmptyObject();
    }

    this (Context ctx, UniNode data)
    {
        prev = ctx;
        this.data = data;
    }

    Context previos() @property
    {
        if (prev !is null)
            return prev;
        return this;
    }

    bool has(string name)
    {
        if (name in data)
            return true;
        if (prev is null)
            return false;
        return prev.has(name);
    }

    UniNode get(string name)
    {
        if (name in data)
            return data[name];
        if (prev is null)
            return UniNode(null);
        return prev.get(name);
    }

    UniNode* getPtr(string name)
    {
        if (name in data)
            return &(data[name]);
        if (prev is null)
            assertTemplate(0, "Non declared var `%s`".fmt(name));
        return prev.getPtr(name);
    }

    T get(T)(string name)
    {
        return this.get(name).get!T;
    }

    bool hasFunc(string name)
    {
        if (name in functions)
            return true;
        if (prev is null)
            return false;
        return prev.hasFunc(name);
    }


    Function getFunc(string name)
    {
        if (name in functions)
            return functions[name];
        if (prev is null)
            assertTemplate(0, "Non declared function `%s`".fmt(name));
        return prev.getFunc(name);
    }


    bool hasMacro(string name)
    {
        if (name in macros)
            return true;
        if (prev is null)
            return false;
        return prev.hasMacro(name);
    }


    Macro getMacro(string name)
    {
        if (name in macros)
            return macros[name];
        if (prev is null)
            assertTemplate(0, "Non declared macro `%s`".fmt(name));
        return prev.getMacro(name);
    }
}


struct AppliedFilter
{
    string name;
    UniNode args;
}


class Render : VisitorInterface
{
    private
    {
        TemplateNode    _root;
        Context         _globalContext;
        Context         _rootContext;
        UniNode[]       _dataStack;
        AppliedFilter[] _appliedFilters;
        TemplateNode[]  _extends;

        Context         _context;
        Request _request;

        string          _renderedResult;
        bool            _isExtended;

        string _routeGroup = DEFAULT_ROUTE_GROUP;
        string _locale = "en-us";
    }

    this(TemplateNode root)
    {
        _root = root;
        _rootContext = new Context();

        foreach(key, value; globalFunctions) {
            _rootContext.functions[key] = cast(Function)value;
        }

        foreach(key, value; GlobalFilters) {
            _rootContext.functions[key] = cast(Function)value;
        }

        foreach(key, value; globalTests) {
            _rootContext.functions[key] = cast(Function)value;
        }

        _rootContext.functions["input"] = &input;
    }

    Request request() {
        return _request;
    }

    void request(Request value) {
        _request = value;
    }

    UniNode input(UniNode node) {
        version(HUNT_VIEW_DEBUG) {
            tracef("node: %s,  kind: %s", node.toString(), node.kind());
        }

        if(_request is null) {
            warningf("The reques does NOT set for node: %s", node.toString());
            return UniNode("");
        }

        UniNode varargs = node["varargs"];
        if(varargs.length == 0) {
            UniNode[string] data;

            foreach(string key, string value; _request.Input()) {
                data[key] = UniNode(value);
            }
            return UniNode(data);
        } else  {
            UniNode[] argNodes = varargs.get!(UniNode[])();
            UniNode keyNode = argNodes[0];
            UniNode defaultValueNode = UniNode("");

            if(varargs.length >= 2) {
                defaultValueNode = argNodes[1];
            }
            
            if(keyNode.kind == UniNode.Kind.text) {
                string key = keyNode.get!string();
                string[string] allInputs = _request.Input();
                auto itemPtr = key in allInputs;
                if(itemPtr is null) {
                    warning(fmt("No value found for %s", key));
                    return defaultValueNode;
                } else {
                    return UniNode(*itemPtr);
                }
            } else {
                // return UniNode("Only string can be accepted.");
                warning("Only string can be accepted.");
                return defaultValueNode;
            }
        }
    }

    void setRouteGroup(string rg)
    {
        _routeGroup = rg;
    }

    void setLocale(string locale)
    {
        _locale = locale;
    }

    string render(UniNode data)
    {
        import hunt.logging;
        version(HUNT_VIEW_DEBUG) logDebug("----render data : ", data);
        _context = new Context(_rootContext, data);
        _globalContext = _context;

        _extends = [_root];
        _isExtended = false;

        _renderedResult = "";
        if (_root !is null)
            TryAccept(_root);
        return _renderedResult;
    }


    override void Visit(TemplateNode node)
    {
        TryAccept(node.stmt.get);
    }

    override void Visit(BlockNode node)
    {
        void super_()
        {
            TryAccept(node.stmt.get);
        }

        foreach (tmpl; _extends[0 .. $-1])
            if (node.name in tmpl.blocks)
            {
                PushNewContext();
                _context.functions["super"] = wrapper!super_;
                TryAccept(tmpl.blocks[node.name].stmt.get);
                PopContext();
                return;
            }

        super_();
    }


    override void Visit(StmtBlockNode node)
    {
        PushNewContext();
        foreach(ch; node.children)
            TryAccept(ch);
        PopContext();
    }

    override void Visit(RawNode node)
    {
        WriteToResult(node.raw);
    }

    override void Visit(ExprNode node)
    {
        TryAccept(node.expr.get);
        auto n = Pop();
        n.ToStringType;
        WriteToResult(n.get!string);
    }

    override void Visit(InlineIfNode node)
    {
        bool condition = true;

        if (!node.cond.isNull)
        {
            TryAccept(node.cond.get);
            auto res = Pop();
            res.ToBoolType;
            condition = res.get!bool;
        }

        if (condition)
        {
            TryAccept(node.expr.get);
        }
        else if (!node.other.isNull)
        {
            TryAccept(node.other.get);
        }
        else
        {
            Push(UniNode(null));
        }
    }

    override void Visit(BinOpNode node)
    {
        UniNode calc(Operator op)()
        {
            TryAccept(node.lhs);
            UniNode lhs = Pop();

            TryAccept(node.rhs);
            auto rhs = Pop();

            return Binary!op(lhs, rhs);
        }

        UniNode calcLogic(bool stopCondition)()
        {
            TryAccept(node.lhs);
            auto lhs = Pop();
            lhs.ToBoolType;
            if (lhs.get!bool == stopCondition)
                return UniNode(stopCondition);

            TryAccept(node.rhs);
            auto rhs = Pop();
            rhs.ToBoolType;
            return UniNode(rhs.get!bool);
        }

        UniNode calcCall(string type)()
        {
            TryAccept(node.lhs);
            auto lhs = Pop();

            TryAccept(node.rhs);
            auto args = Pop();
            auto name = args["name"].get!string;
            args["varargs"] = UniNode([lhs] ~ args["varargs"].get!(UniNode[]));

            if (_context.hasFunc(name))
                return VisitFunc(name, args);
            else if (_context.hasMacro(name))
                return VisitMacro(name, args);
            else
                assertTemplate(0, "Undefined " ~ type ~ " %s".fmt(name), node.pos);
            assert(0);
        }

        UniNode calcFilter()
        {
            return calcCall!"filter";
        }

        UniNode calcIs()
        {
            auto res = calcCall!"test";
            res.ToBoolType;
            return res;
        }

        UniNode doSwitch()
        {
            switch (node.op) with (Operator)
            {
                case Concat:    return calc!Concat;
                case Plus:      return calc!Plus;
                case Minus:     return calc!Minus;
                case DivInt:    return calc!DivInt;
                case DivFloat:  return calc!DivFloat;
                case Rem:       return calc!Rem;
                case Mul:       return calc!Mul;
                case Greater:   return calc!Greater;
                case Less:      return calc!Less;
                case GreaterEq: return calc!GreaterEq;
                case LessEq:    return calc!LessEq;
                case Eq:        return calc!Eq;
                case NotEq:     return calc!NotEq;
                case Pow:       return calc!Pow;
                case In:        return calc!In;

                case Or:        return calcLogic!true;
                case And:       return calcLogic!false;

                case Filter:    return calcFilter;
                case Is:        return calcIs;

                default:
                    assert(0, "Not implemented Binary operator");
            }
        }

        Push(doSwitch());
    }

    override void Visit(UnaryOpNode node)
    {
        TryAccept(node.expr);
        auto res = Pop();
        UniNode doSwitch()
        {
            switch (node.op) with (Operator)
            {
                case Plus:      return Unary!Plus(res);
                case Minus:     return Unary!Minus(res);
                case Not:       return Unary!Not(res);
                default:
                    assert(0, "Not implemented Unary operator");
            }
        }

        Push(doSwitch());
    }

    override void Visit(NumNode node)
    {
        if (node.type == NumNode.Type.Integer)
            Push(UniNode(node.data._integer));
        else
            Push(UniNode(node.data._float));
    }

    override void Visit(BooleanNode node)
    {
        Push(UniNode(node.boolean));
    }

    override void Visit(NilNode node)
    {
        Push(UniNode(null));
    }

    override void Visit(IdentNode node)
    {
        UniNode curr;
        if (node.name.length)
            curr = _context.get(node.name);
        else
            curr = UniNode(null);

        auto lastPos = node.pos;
        foreach (sub; node.subIdents)
        {
            TryAccept(sub);
            auto key = Pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    curr.CheckNodeType(array, lastPos);
                    if (key.get!size_t < curr.length)
                        curr = curr[key.get!size_t];
                    else
                        assertTemplate(0, "Range violation  on %s...[%d]".fmt(node.name, key.get!size_t), sub.pos);
                    break;

                // Key of dict
                case text:
                    auto keyStr = key.get!string;
                    if (curr.kind == UniNode.Kind.object && keyStr in curr)
                        curr = curr[keyStr];
                    else if (_context.hasFunc(keyStr))
                    {
                        auto args = [
                            "name": UniNode(keyStr),
                            "varargs": UniNode([curr]),
                            "kwargs": UniNode.EmptyObject
                        ];
                        curr = VisitFunc(keyStr, UniNode(args));
                    }
                    else if (_context.hasMacro(keyStr))
                    {
                        auto args = [
                            "name": UniNode(keyStr),
                            "varargs": UniNode([curr]),
                            "kwargs": UniNode.EmptyObject
                        ];
                        curr = VisitMacro(keyStr, UniNode(args));
                    }
                    else
                    {
                        curr.CheckNodeType(object, lastPos);
                        assertTemplate(0, "Unknown attribute %s".fmt(key.get!string), sub.pos);
                    }
                    break;

                // Call of function
                case object:
                    auto name = key["name"].get!string;

                    if (!curr.isNull)
                        key["varargs"] = UniNode([curr] ~ key["varargs"].get!(UniNode[]));

                    if (_context.hasFunc(name))
                    {
                        curr = VisitFunc(name, key);
                    }
                    else if (_context.hasMacro(name))
                    {
                        curr = VisitMacro(name, key);
                    }
                    else
                        assertTemplate(0, "Not found any macro, function or filter `%s`".fmt(name), sub.pos);
                    break;

                default:
                    assertTemplate(0, "Unknown attribute %s for %s".fmt(key.toString, node.name), sub.pos);
            }

            lastPos = sub.pos;
        }

        Push(curr);
    }

    override void Visit(AssignableNode node)
    {
        auto expr = Pop();

        // TODO: check flag of set scope
        if (!_context.has(node.name))
        {
            if (node.subIdents.length)
                assertTemplate(0, "Unknow variable %s".fmt(node.name), node.pos);
            _context.data[node.name] = expr;
            return;
        }

        UniNode* curr = _context.getPtr(node.name);

        if (!node.subIdents.length)
        {
            (*curr) = expr;
            return;
        }

        auto lastPos = node.pos;
        for(int i = 0; i < cast(int)(node.subIdents.length) - 1; i++)
        {
            TryAccept(node.subIdents[i]);
            auto key = Pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    CheckNodeType(*curr, array, lastPos);
                    if (key.get!size_t < curr.length)
                        curr = &((*curr)[key.get!size_t]);
                    else
                        assertTemplate(0, "Range violation  on %s...[%d]".fmt(node.name, key.get!size_t), node.subIdents[i].pos);
                    break;

                // Key of dict
                case text:
                    CheckNodeType(*curr, object, lastPos);
                    if (key.get!string in *curr)
                        curr = &((*curr)[key.get!string]);
                    else
                        assertTemplate(0, "Unknown attribute %s".fmt(key.get!string), node.subIdents[i].pos);
                    break;

                default:
                    assertTemplate(0, "Unknown attribute %s for %s".fmt(key.toString, node.name), node.subIdents[i].pos);
            }
            lastPos = node.subIdents[i].pos;
        }

        if (node.subIdents.length)
        {
            TryAccept(node.subIdents[$-1]);
            auto key = Pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    CheckNodeType(*curr, array, lastPos);
                    if (key.get!size_t < curr.length)
                        (*curr).opIndex(key.get!size_t) = expr; // ¯\_(ツ)_/¯
                    else
                        assertTemplate(0, "Range violation  on %s...[%d]".fmt(node.name, key.get!size_t), node.subIdents[$-1].pos);
                    break;

                // Key of dict
                case text:
                    CheckNodeType(*curr, object, lastPos);
                    (*curr)[key.get!string] = expr;
                    break;

                default:
                    assertTemplate(0, "Unknown attribute %s for %s".fmt(key.toString, node.name, node.subIdents[$-1].pos));
            }
        }
    }

    override void Visit(StringNode node)
    {
        Push(UniNode(node.str));
    }

    override void Visit(ListNode node)
    {
        UniNode[] list = [];
        foreach (l; node.list)
        {
            TryAccept(l);
            list ~= Pop();
        }
        Push(UniNode(list));
    }

    override void Visit(DictNode node)
    {
        UniNode[string] dict;
        foreach (key, value; node.dict)
        {
            TryAccept(value);
            dict[key] = Pop();
        }
        Push(UniNode(dict));
    }

    override void Visit(IfNode node)
    {
        TryAccept(node.cond);

        auto cond = Pop();
        cond.ToBoolType;

        if (cond.get!bool)
        {
            TryAccept(node.then);
        }
        else if (node.other)
        {
            TryAccept(node.other);
        }
    }

    override void Visit(ForNode node)
    {
        bool iterated = false;
        int depth = 0;
        bool calcCondition()
        {
            bool condition = true;
            if (!node.cond.isNull)
            {
                TryAccept(node.cond.get);
                auto cond = Pop();
                cond.ToBoolType;
                condition = cond.get!bool;
            }
            return condition;
        }

        UniNode cycle(UniNode loop, UniNode varargs)
        {
            if (!varargs.length)
                return UniNode(null);
            return varargs[loop["index0"].get!size_t % varargs.length];
        }


        void loop(UniNode iterable)
        {
            Nullable!UniNode lastVal;
            bool changed(UniNode loop, UniNode val)
            {
                if (!lastVal.isNull && val == lastVal.get)
                    return false;
                lastVal = val;
                return true;
            }

            depth++;
            PushNewContext();

            iterable.ToIterableNode;

            if (!node.cond.isNull)
            {
                auto newIterable = UniNode.EmptyArray;
                for (int i = 0; i < iterable.length; i++)
                {
                    if (node.keys.length == 1)
                        _context.data[node.keys[0]] = iterable[i];
                    else
                    {
                        iterable[i].CheckNodeType(UniNode.Kind.array, node.iterable.get.pos);
                        assertTemplate(iterable[i].length >= node.keys.length, "Num of keys less then values", node.iterable.get.pos);
                        foreach(j, key; node.keys)
                            _context.data[key] = iterable[i][j];
                    }

                    if (calcCondition())
                        newIterable ~= iterable[i];
                }
                iterable = newIterable;
            }

            _context.data["loop"] = UniNode.EmptyObject;
            _context.data["loop"]["length"] = UniNode(iterable.length);
            _context.data["loop"]["depth"] = UniNode(depth);
            _context.data["loop"]["depth0"] = UniNode(depth - 1);
            _context.functions["cycle"] = wrapper!cycle;
            _context.functions["changed"] = wrapper!changed;

            for (int i = 0; i < iterable.length; i++)
            {
                _context.data["loop"]["index"] = UniNode(i + 1);
                _context.data["loop"]["index0"] = UniNode(i);
                _context.data["loop"]["revindex"] = UniNode(iterable.length - i);
                _context.data["loop"]["revindex0"] = UniNode(iterable.length - i - 1);
                _context.data["loop"]["first"] = UniNode(i == 0);
                _context.data["loop"]["last"] = UniNode(i == iterable.length - 1);
                _context.data["loop"]["previtem"] = i > 0 ? iterable[i - 1] : UniNode(null);
                _context.data["loop"]["nextitem"] = i < iterable.length - 1 ? iterable[i + 1] : UniNode(null);

                if (node.isRecursive)
                    _context.functions["loop"] = wrapper!loop;

                if (node.keys.length == 1)
                    _context.data[node.keys[0]] = iterable[i];
                else
                {
                    iterable[i].CheckNodeType(UniNode.Kind.array, node.iterable.get.pos);
                    assertTemplate(iterable[i].length >= node.keys.length, "Num of keys less then values", node.iterable.get.pos);
                    foreach(j, key; node.keys)
                        _context.data[key] = iterable[i][j];
                }

                TryAccept(node.block.get);
                iterated = true;
            }
            PopContext();
            depth--;
        }



        TryAccept(node.iterable.get);
        UniNode iterable = Pop();
        loop(iterable);

        if (!iterated && !node.other.isNull)
            TryAccept(node.other.get);
    }


    override void Visit(SetNode node)
    {
        TryAccept(node.expr);

        if (node.assigns.length == 1)
            TryAccept(node.assigns[0]);
        else
        {
            auto expr = Pop();
            expr.CheckNodeType(UniNode.Kind.array, node.expr.pos);

            if (expr.length < node.assigns.length)
                assertTemplate(0, "Iterable length less then number of assigns", node.expr.pos);

            foreach(idx, assign; node.assigns)
            {
                Push(expr[idx]);
                TryAccept(assign);
            }
        }
    }


    override void Visit(MacroNode node)
    {
        FormArg[] args;

        foreach(arg; node.args)
        {
            if (arg.defaultExpr.isNull)
                args ~= FormArg(arg.name);
            else
            {
                TryAccept(arg.defaultExpr.get);
                args ~= FormArg(arg.name, Pop());
            }
        }

        _context.macros[node.name] = Macro(args, _context, node.block.get);
    }


    override void Visit(CallNode node)
    {
        FormArg[] args;

        foreach(arg; node.formArgs)
        {
            if (arg.defaultExpr.isNull)
                args ~= FormArg(arg.name);
            else
            {
                TryAccept(arg.defaultExpr.get);
                args ~= FormArg(arg.name, Pop());
            }
        }

        auto caller = Macro(args, _context, node.block.get);

        TryAccept(node.factArgs.get);
        auto factArgs = Pop();

        VisitMacro(node.macroName, factArgs, caller.nullable);
    }


    override void Visit(FilterBlockNode node)
    {
        TryAccept(node.args.get);
        auto args = Pop();

        PushFilter(node.filterName, args);
        TryAccept(node.block.get);
        PopFilter();
    }


    override void Visit(ImportNode node)
    {
        if (node.tmplBlock.isNull)
            return;

        auto stashedContext = _context;
        auto stashedResult = _renderedResult;

        if (!node.withContext)
            _context = _globalContext;

        _renderedResult = "";

        PushNewContext();

        foreach (child; node.tmplBlock.get.stmt.get.children)
            TryAccept(child);

        auto macros = _context.macros;

        PopContext();

        _renderedResult = stashedResult;

        if (!node.withContext)
            _context = stashedContext;

        if (node.macrosNames.length)
            foreach (name; node.macrosNames)
            {
                assertTemplate(cast(bool)(name.was in macros), "Undefined macro `%s` in `%s`".fmt(name.was, node.fileName), node.pos);
                _context.macros[name.become] = macros[name.was];
            }
        else
            foreach (key, val; macros)
                _context.macros[key] = val;
    }


    override void Visit(IncludeNode node)
    {
        if (node.tmplBlock.isNull)
            return;

        auto stashedContext = _context;

        if (!node.withContext)
            _context = _globalContext;

        TryAccept(node.tmplBlock.get);

        if (!node.withContext)
            _context = stashedContext;
    }


    override void Visit(ExtendsNode node)
    {
        _extends ~= node.tmplBlock;
        TryAccept(node.tmplBlock.get);
        _extends.popBack;
        _isExtended = true;
    }

    private void TryAccept(Node node)
    {
        if (!_isExtended)
            node.accept(this);
    }


    private UniNode VisitFunc(string name, UniNode args)
    {
        version(HUNT_VIEW_DEBUG) info("---Func: ", name,", args: ",args);

        if(name == "trans")
        {
            if("varargs" in args)
            {
                return DoTrans(args["varargs"]);
            }
        }
        else if(name == "date")
        {
            import hunt.util.DateTime;
            auto format = args["varargs"][0].get!string;
            auto timestamp = args["varargs"][1].get!int;
            return UniNode(date(format, timestamp));
        }
        else if(name == "url")
        {
            import kerisy.BasicSimplify : Url;

            auto mca = args["varargs"][0].get!string;
            auto params = args["varargs"][1].get!string;
            return UniNode(Url(mca, Util.ParseFormData(params), _routeGroup));
        }
        return _context.getFunc(name)(args);
    }

    private UniNode DoTrans(UniNode arg)
    {
        import kerisy.i18n;
        import kerisy.util.uninode.Serialization;

        if(arg.kind == UniNode.Kind.array)
        {
            if(arg.length == 1)
            {
                return UniNode(TransWithLocale(_locale,arg[0].get!string));
            }
            else if(arg.length > 1)
            {
                string msg = arg[0].get!string;
                UniNode[] args;
                for(int i=1; i < arg.length ; i++)
                {
                     args ~= arg[i];
                }
                
                return UniNode(TransWithLocale(_locale,msg,UniNodeToJSON(UniNode(args))));
            }
        }
        throw new TemplateRenderException("unsupport param : " ~ arg.toString);
    }


    private UniNode VisitMacro(string name, UniNode args, Nullable!Macro caller = Nullable!Macro.init)
    {
        UniNode result;

        auto macro_ = _context.getMacro(name);
        auto stashedContext = _context;
        _context = macro_.context.get;
        PushNewContext();

        UniNode[] varargs;
        UniNode[string] kwargs;

        foreach(arg; macro_.args)
            if (!arg.def.isNull)
                _context.data[arg.name] = arg.def.get;

        for(int i = 0; i < args["varargs"].length; i++)
        {
            if (i < macro_.args.length)
                _context.data[macro_.args[i].name] = args["varargs"][i];
            else
                varargs ~= args["varargs"][i];
        }

        foreach (string key, value; args["kwargs"])
        {
            if (macro_.args.has(key))
                _context.data[key] = value;
            else
                kwargs[key] = value;
        }

        _context.data["varargs"] = UniNode(varargs);
        _context.data["kwargs"] = UniNode(kwargs);

        foreach(arg; macro_.args)
            if (arg.name !in _context.data)
                assertTemplate(0, "Missing value for argument `%s` in macro `%s`".fmt(arg.name, name));

        if (!caller.isNull)
            _context.macros["caller"] = caller.get();

        TryAccept(macro_.block.get);
        result = Pop();

        PopContext();
        _context = stashedContext;

        return result;
    }

    private void WriteToResult(string str)
    {
        if (!_appliedFilters.length)
        {
            _renderedResult ~= str;
        }
        else
        {
            UniNode curr = UniNode(str);
            foreach_reverse (filter; _appliedFilters)
            {
                auto args = filter.args;
                args["varargs"] = UniNode([curr] ~ args["varargs"].get!(UniNode[]));

                if (_context.hasFunc(filter.name))
                    curr = VisitFunc(filter.name, args);
                else if (_context.hasMacro(filter.name))
                    curr = VisitMacro(filter.name, args);
                else
                    assert(0);

                curr.ToStringType;
            }

            _renderedResult ~= curr.get!string;
        }
    }

    private void PushNewContext()
    {
        _context = new Context(_context, UniNode.EmptyObject);
    }


    private void PopContext()
    {
        _context = _context.previos;
    }


    private void Push(UniNode un)
    {
        _dataStack ~= un;
    }


    private UniNode Pop()
    {
        if (!_dataStack.length)
            assertTemplate(0, "Unexpected empty stack");

        auto un = _dataStack.back;
        _dataStack.popBack;
        return un;
    }


    private void PushFilter(string name, UniNode args)
    {
        _appliedFilters ~= AppliedFilter(name, args);
    }


    private void PopFilter()
    {
        if (!_appliedFilters.length)
            assertTemplate(0, "Unexpected empty filter stack");

        _appliedFilters.popBack;
    }
}


void RegisterFunction(alias func)(Render render, string name)
{
    render._rootContext.functions[name] = wrapper!func;
}


void RegisterFunction(alias func)(Render render)
{
    enum name = __traits(identifier, func);
    render._rootContext.functions[name] = wrapper!func;
}


private bool has(FormArg[] arr, string name)
{
    foreach(a; arr) {
        if (a.name == name)
            return true;
    }
    return false;
}
