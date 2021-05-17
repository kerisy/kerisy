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

module kerisy.view.ast.Printer;

private
{
    import kerisy.view.ast.Node;
    import kerisy.view.ast.Visitor;
}


class NullVisitor : VisitorInterface
{
    static foreach(NT; NodeTypes)
    {
        void Visit(NT node)
        {
            import std.stdio: wl = writeln;
            wl("# ", NT.stringof, " #");
        }
    }
}


class Printer : NullVisitor
{
    import std.stdio: wl = writeln, w = write;
    import std.format: fmt = format;

    uint _tab = 0;

    override void Visit(StmtBlockNode node)
    {
        print("Statement Block:"); 
        _tab++;
        foreach(ch; node.children)
        {
            ch.accept(this);
        }
        _tab--;
    }


    override void Visit(TemplateNode node)
    {
        print("Template:");

        _tab++;

        if (!node.blocks.length)
            print("Blocks: NONE");
        else
        {
            print("Blocks:");
            _tab++;
            foreach (key, block; node.blocks)
                print(key);
            _tab--;
        }

        print("Statements:");
        _tab++;
        if (!node.stmt.isNull)
            node.stmt.get.accept(this);
        _tab--;

        _tab--;
    }


    override void Visit(BlockNode node)
    {
        print("Block: %s".fmt(node.name));
        _tab++;
        if (!node.stmt.isNull)
            node.stmt.get.accept(this);
        _tab--;
    }


    override void Visit(RawNode node)
    {
        import std.array : replace;
        print("Raw block: \"%s\"".fmt(node.raw.replace("\n", "\\n").replace(" ", ".")));
    }


    override void Visit(ExprNode node)
    {
        print("Expression block:");
        _tab++;
        node.expr.get.accept(this);
        _tab--;
    }


    override void Visit(InlineIfNode node)
    {
        print("Inline If:");

        _tab++;

        if (node.cond.isNull)
            print("If: NONE");
        else
        {
            print("If:");
            _tab++;
            node.cond.get.accept(this);
            _tab--;
        }

        print("Expression:");
        _tab++;
        node.expr.get.accept(this);
        _tab--;

        if (node.other.isNull)
            print("Else: nil");
        else
        {
            print("Else:");
            _tab++;
            node.other.get.accept(this);
            _tab--;
        }

        _tab--;
    }


    override void Visit(BinOpNode node)
    {
        print("BinaryOp: %s".fmt(node.op));
        _tab++;
        node.lhs.accept(this);
        node.rhs.accept(this);
        _tab--;
    }


    override void Visit(UnaryOpNode node)
    {
        print("UnaryOp: %s".fmt(node.op));
        _tab++;
        node.expr.accept(this);
        _tab--;
    }


    override void Visit(NumNode node)
    {
        if (node.type == NumNode.Type.Integer)
            print("Integer: %d".fmt(node.data._integer));
        else
            print("Float: %f".fmt(node.data._float));
    }


    override void Visit(BooleanNode node)
    {
        print("Bool: %s".fmt(node.boolean));
    }


    override void Visit(NilNode node)
    {
        print("Nil");
    }


    override void Visit(IdentNode node)
    {
        print("Ident: '%s'".fmt(node.name));
        if (node.subIdents.length)
        {
            print("Sub idents:");
            _tab++;
            foreach (id; node.subIdents)
                id.accept(this);
            _tab--;
        }
    }


    override void Visit(AssignableNode node)
    {
        print("Assignable: %s".fmt(node.name));
        if (node.subIdents.length)
        {
            _tab++;
            print("Sub idents:");
            _tab++;
            foreach (id; node.subIdents)
                id.accept(this);
            _tab--;
            _tab--;
        }
    }


    override void Visit(StringNode node)
    {
        print("String: %s".fmt(node.str));
    }


    override void Visit(ListNode node)
    {
        print("List:");
        _tab++;
        foreach (l; node.list)
            l.accept(this);
        _tab--;
    }


    override void Visit(DictNode node)
    {
        print("Dict:");
        _tab++;
        foreach (key, value; node.dict)
        {
            print("Key: %s".fmt(key));
            print("Value:");
            _tab++;
            value.accept(this);
            _tab--;
        }
        _tab--;
    }


    override void Visit(IfNode node)
    {
        print("If:");
        _tab++;

        print("Condition:");
        _tab++;
        node.cond.accept(this);
        _tab--;

        print("Then:");
        _tab++;
        node.then.accept(this);
        _tab--;

        if (node.other)
        {
            print("Else:");
            _tab++;
            node.other.accept(this);
            _tab--;
        }
        else
            print("Else: NONE");
        _tab--;
    }


    override void Visit(ForNode node)
    {
        print("For:");
        _tab++;

        print("Keys:");
        _tab++;
        foreach (key; node.keys)
            print(key);
        _tab--;

        print("Iterable:");
        _tab++;
        node.iterable.get.accept(this);
        _tab--;

        print("Block:");
        _tab++;
        node.block.get.accept(this);
        _tab--;

        if (!node.cond.isNull)
        {
            print("Condition:");
            _tab++;
            node.cond.get.accept(this);
            _tab--;
        }
        else
            print("Condition: NONE");


        if (!node.other.isNull)
        {
            print("Else:");
            _tab++;
            node.other.get.accept(this);
            _tab--;
        }
        else
            print("Else: NONE");

        print("Recursive: %s".fmt(node.isRecursive));

        _tab--;
    }


    override void Visit(SetNode node)
    {
        print("Set:");
        _tab++;

        print("Assigns:");
        _tab++;
        foreach (assign; node.assigns)
            assign.accept(this);
        _tab--;

        print("Expression:");
        _tab++;
        node.expr.accept(this);
        _tab--;

        _tab--;
    }


    override void Visit(MacroNode node)
    {
        print("Macro: '%s'".fmt(node.name));

        _tab++;
        if (!node.args.length)
            print("Args: NONE");
        else
        {
            print("Args:");
            _tab++;
            foreach(arg; node.args)
            {
                print("Name: %s".fmt(arg.name));
                if (!arg.defaultExpr.isNull)
                {
                    _tab++;
                    print("Default:");
                    _tab++;
                    arg.defaultExpr.get.accept(this);
                    _tab--;
                    _tab--;
                }
            }
            _tab--;
        }

        print("Body:");
        _tab++;
        node.block.get.accept(this);
        _tab--;

        _tab--;

        print("Return: %s".fmt(node.isReturn));
    }


    override void Visit(CallNode node)
    {
        print("Call: '%s'".fmt(node.macroName));

        _tab++;

        if (!node.formArgs.length)
            print("Formal args: NONE");
        else
        {
            print("Formal args:");
            _tab++;
            foreach(arg; node.formArgs)
            {
                print("Name: %s".fmt(arg.name));
                if (!arg.defaultExpr.isNull)
                {
                    _tab++;
                    print("Default:");
                    _tab++;
                    arg.defaultExpr.get.accept(this);
                    _tab--;
                    _tab--;
                }
            }
            _tab--;
        }

        if (node.factArgs.isNull)
            print("Fact args: NONE");
        else
        {
            print("Fact args:");
            _tab++;
            node.factArgs.get.accept(this);
            _tab--;
        }

        print("Body:");
        _tab++;
        node.block.get.accept(this);
        _tab--;

        _tab--;
    }


    override void Visit(FilterBlockNode node)
    {
        print("Filter: '%s'".fmt(node.filterName));

        _tab++;

        if (node.args.isNull)
            print("Args: NONE");
        else
        {
            print("Args:");
            _tab++;
            node.args.get.accept(this);
            _tab--;
        }

        print("Body:");
        _tab++;
        node.block.get.accept(this);
        _tab--;

        _tab--;
    }


    override void Visit(ImportNode node)
    {
        print("Import: '%s'".fmt(node.fileName));

        _tab++;

        if (!node.macrosNames.length)
            print("Macros: all");
        else
        {
            print("Macros:");
            _tab++;
            foreach(name; node.macrosNames)
                print("%s -> %s".fmt(name.was, name.become));
            _tab--;
        }

        if (node.tmplBlock.isNull)
            print("Block: Missing");
        else
            print("Block: %s children".fmt(node.tmplBlock.get.stmt.get.children.length));

        if (node.withContext)
            print("Context: with");
        else
            print("Context: without");

        _tab--;
    }


    override void Visit(IncludeNode node)
    {
        print("Include: '%s'".fmt(node.fileName));

        _tab++;

        if (node.tmplBlock.isNull)
            print("Block: Missing");
        else
            print("Block: %s children".fmt(node.tmplBlock.get.stmt.get.children.length));

        if (node.withContext)
            print("Context: with");
        else
            print("Context: without");

        _tab--;
    }


    override void Visit(ExtendsNode node)
    {
        print("Extends: '%s'".fmt(node.fileName));

        _tab++;

        if (node.tmplBlock.isNull)
            print("Block: Missing");
        else
            print("Block: %s children".fmt(node.tmplBlock.get.stmt.get.children.length));

        _tab--;
    }


protected:


    void print(string str)
    {
        foreach(i; 0 .. _tab)
            w("-   ");
        wl(str);
    }
}
