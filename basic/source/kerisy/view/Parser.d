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

module kerisy.view.Parser;

public
{
    import kerisy.view.Lexer : Position;
}

private
{
    import std.array : appender;
    import std.conv : to;
    import std.file : exists, read;
    import std.path : dirName,absolutePath,dirSeparator;
    import std.format: fmt = format;
    import std.range;

    import hunt.logging;
    import kerisy.view.ast;
    import kerisy.view.Lexer;
    import kerisy.view.Exception : TemplateParserException,
                              assertTemplate = assertTemplateParser;
}


struct Parser(Lexer)
{
    struct ParserState
    {
        Token[] tokens;
        BlockNode[string] blocks;
    }

    private
    {
        TemplateNode[string] _parsedFiles;

        Token[] _tokens;
        BlockNode[string] _blocks;

        ParserState[] _states;
    }

    void Preprocess()
    {
        import std.string : stripRight, stripLeft;

        auto newTokens = appender!(Token[]);

        for (int i = 0; i < _tokens.length;)
        {
            if (i < _tokens.length - 1
                && _tokens[i] == Type.StmtBegin
                && _tokens[i+1] == Operator.Minus)
            {
                newTokens.put(_tokens[i]);
                i += 2;
            }
            else if(i < _tokens.length - 1
                    && _tokens[i] == Operator.Minus
                    && _tokens[i+1] == Type.StmtEnd)
            {
                newTokens.put(_tokens[i+1]);
                i += 2;
            }
            else if (_tokens[i] == Type.Raw)
            {
                bool stripR = false;
                bool stripL = false;
                bool stripInlineR = false;

                if (i >= 2 
                    && _tokens[i-2] == Operator.Minus
                    && _tokens[i-1] == Type.StmtEnd
                    )
                    stripL = true;

                if (i < _tokens.length - 2 && _tokens[i+1] == Type.StmtBegin)
                {
                    if (_tokens[i+2] == Operator.Minus)
                        stripR = true;
                    else if (_tokens[i+1].value == Lexer.stmtInline)
                        stripInlineR = true;
                }

                auto str = _tokens[i].value;
                str = stripR ? str.stripRight : str;
                str = stripL ? str.stripLeft : str;
                str = stripInlineR ? str.StripOnceRight : str;
                newTokens.put(Token(Type.Raw, str, _tokens[i].pos));
                i++;
            }
            else
            {
                newTokens.put(_tokens[i]);
                i++;
            }
        }
        _tokens = newTokens.data;
    }


    TemplateNode ParseTree(string str, string filename ,string dirPath)
    {
        StashState();

        auto lexer = Lexer(str, filename);
        auto newTokens = appender!(Token[]);

        while (true)
        {
            auto tkn = lexer.NextToken;
            newTokens.put(tkn); 
            if (tkn.type == Type.EOF)
                break;
        }
        _tokens = newTokens.data;

        Preprocess();

        auto root = ParseStatementBlock(dirPath);
        auto blocks = _blocks;

        if (Front.type != Type.EOF)
            assertTemplate(0, "Expected EOF found %s(%s)".fmt(Front.type, Front.value), Front.pos);

        PopState();

        return new TemplateNode(Position(filename, 1, 1), root, blocks);
    }


    TemplateNode ParseTreeFromFile(string path)
    {
        string dirPath = dirName(path) ~ dirSeparator;
        // path = path.Absolute(_path);
        version(HUNT_FM_DEBUG) logDebug("parse file absolute path : ",path);
        if (auto cached = path in _parsedFiles)
        {
            if (*cached is null)
                assertTemplate(0, "Recursive imports/includes/extends not allowed: ".fmt(path), Front.pos);
            else
                return *cached;
        }

        // Prevent recursive imports
        auto str = cast(string)read(path);
        _parsedFiles[path] = ParseTree(str, path,dirPath);

        return _parsedFiles[path];
    }


private:
    /**
      * exprblock = EXPRBEGIN expr (IF expr (ELSE expr)? )? EXPREND
      */
    ExprNode ParseExpression(string dirPath)
    {
        Node expr;
        auto pos = Front.pos;

        Pop(Type.ExprBegin);
        expr = ParseHighLevelExpression(dirPath);
        Pop(Type.ExprEnd);

        return new ExprNode(pos, expr);
    }

    StmtBlockNode ParseStatementBlock(string dirPath)
    {
        auto block = new StmtBlockNode(Front.pos);

        while (Front.type != Type.EOF)
        {
            auto pos = Front.pos;
            switch(Front.type) with (Type)
            {
                case Raw:
                    auto raw = Pop.value;
                    if (raw.length)
                        block.children ~= new RawNode(pos, raw);
                    break;

                case ExprBegin:
                    block.children ~= ParseExpression(dirPath);
                    break;

                case CmntBegin:
                    ParseComment(dirPath);
                    break;

                case CmntInline:
                    Pop();
                    break;

                case StmtBegin:
                    if (Next.type == Type.Keyword
                        && Next.value.ToKeyword.IsBeginingKeyword)
                        block.children ~= ParseStatement(dirPath);
                    else
                        return block;
                    break;

                default:
                    return block;
            }
        }

        return block;
    }


    Node ParseStatement(string dirPath)
    {
        Pop(Type.StmtBegin);

        switch(Front.value) with (Keyword)
        {
            case If:      return ParseIf(dirPath);
            case For:     return ParseFor(dirPath);
            case Set:     return ParseSet(dirPath);
            case Macro:   return ParseMacro(dirPath);
            case Call:    return ParseCall(dirPath);
            case Filter:  return ParseFilterBlock(dirPath);
            case With:    return ParseWith(dirPath);
            case Import:  return ParseImport(dirPath);
            case From:    return ParseImportFrom(dirPath);
            case Include: return ParseInclude(dirPath);
            case Extends: return ParseExtends(dirPath);

            case Block:
                auto block = ParseBlock( dirPath);
                _blocks[block.name] = block;
                return block;
            default:
                assert(0, "Not implemented kw %s".fmt(Front.value));
        }
    }


    ForNode ParseFor(string dirPath)
    {
        string[] keys;
        bool isRecursive = false;
        Node cond = null;
        auto pos = Front.pos;

        Pop(Keyword.For);

        keys ~= Pop(Type.Ident).value;
        while(Front != Operator.In)
        {
            Pop(Type.Comma);
            keys ~= Pop(Type.Ident).value;
        }

        Pop(Operator.In);

        Node iterable;

        switch (Front.type) with (Type)
        {
            case LParen:  iterable = ParseTuple(dirPath); break;
            case LSParen: iterable = ParseList(dirPath); break;
            case LBrace:  iterable = ParseDict(dirPath); break;
            default:      iterable = ParseIdent(dirPath);
        }

        if (Front == Keyword.If)
        {
            Pop(Keyword.If);
            cond = ParseHighLevelExpression(dirPath);
        }

        if (Front == Keyword.Recursive)
        {
            Pop(Keyword.Recursive);
            isRecursive = true;
        }

        Pop(Type.StmtEnd);

        auto block = ParseStatementBlock(dirPath);

        Pop(Type.StmtBegin);

        switch (Front.value) with (Keyword)
        {
            case EndFor:
                Pop(Keyword.EndFor);
                Pop(Type.StmtEnd);
                return new ForNode(pos, keys, iterable, block, null, cond, isRecursive);
            case Else:
                Pop(Keyword.Else);
                Pop(Type.StmtEnd);
                auto other = ParseStatementBlock(dirPath);
                Pop(Type.StmtBegin);
                Pop(Keyword.EndFor);
                Pop(Type.StmtEnd);
                return new ForNode(pos, keys, iterable, block, other, cond, isRecursive);
            default:
                assertTemplate(0, "Unexpected token %s(%s)".fmt(Front.type, Front.value), Front.pos);
                assert(0);
        }
    }


    IfNode ParseIf(string dirPath)
    {
        auto pos = Front.pos;
        assertTemplate(Front == Keyword.If || Front == Keyword.ElIf, "Expected If/Elif", pos);
        Pop();
        auto cond = ParseHighLevelExpression(dirPath);
        Pop(Type.StmtEnd);

        auto then = ParseStatementBlock(dirPath);

        Pop(Type.StmtBegin);

        switch (Front.value) with (Keyword)
        {
            case ElIf:
                auto other = ParseIf(dirPath);
                return new IfNode(pos, cond, then, other);
            case Else:
                Pop(Keyword.Else, Type.StmtEnd);
                auto other = ParseStatementBlock(dirPath);
                Pop(Type.StmtBegin, Keyword.EndIf, Type.StmtEnd);
                return new IfNode(pos, cond, then, other);
            case EndIf:
                Pop(Keyword.EndIf, Type.StmtEnd);
                return new IfNode(pos, cond, then, null);
            default:
                assertTemplate(0, "Unexpected token %s(%s)".fmt(Front.type, Front.value), Front.pos);
                assert(0);
        }
    }


    SetNode ParseSet(string dirPath)
    {
        auto setPos = Front.pos;

        Pop(Keyword.Set);

        auto assigns = ParseSequenceOf!ParseAssignable(dirPath,Type.Operator);

        Pop(Operator.Assign);

        auto listPos = Front.pos;
        auto exprs = ParseSequenceOf!ParseHighLevelExpression(dirPath,Type.StmtEnd);
        Node expr = exprs.length == 1 ? exprs[0] : new ListNode(listPos, exprs);

        Pop(Type.StmtEnd);

        return new SetNode(setPos, assigns, expr);
    }


    AssignableNode ParseAssignable(string dirPath)
    {
        auto pos = Front.pos;
        string name = Pop(Type.Ident).value;
        Node[] subIdents = [];

        while (true)
        {
            switch (Front.type) with (Type)
            {
                case Dot:
                    Pop(Dot);
                    auto strPos = Front.pos;
                    subIdents ~= new StringNode(strPos, Pop(Ident).value);
                    break;
                case LSParen:
                    Pop(LSParen);
                    subIdents ~= ParseHighLevelExpression(dirPath);
                    Pop(RSParen);
                    break;
                default:
                    return new AssignableNode(pos, name, subIdents);
            }
        }
    }


    MacroNode ParseMacro(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Macro);

        auto name = Pop(Type.Ident).value;
        Arg[] args;

        if (Front.type == Type.LParen)
        {
            Pop(Type.LParen);
            args = ParseFormalArgs( dirPath);
            Pop(Type.RParen);
        }

        Pop(Type.StmtEnd);

        auto block = ParseStatementBlock( dirPath);

        Pop(Type.StmtBegin, Keyword.EndMacro);

        bool ret = false;
        if (Front.type == Type.Keyword && Front.value == Keyword.Return)
        {
            Pop(Keyword.Return);
            block.children ~= ParseHighLevelExpression(dirPath);
            ret = true;
        }
        else
            block.children ~= new NilNode; // void return

        Pop(Type.StmtEnd);

        return new MacroNode(pos, name, args, block, ret);
    }


    CallNode ParseCall(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Call);

        Arg[] formalArgs;

        if (Front.type == Type.LParen)
        {
            Pop(Type.LParen);
            formalArgs = ParseFormalArgs( dirPath);
            Pop(Type.RParen);
        }

        auto macroName = Front.value;
        auto factArgs = ParseCallExpr( dirPath);

        Pop(Type.StmtEnd);

        auto block = ParseStatementBlock( dirPath);
        block.children ~= new NilNode; // void return

        Pop(Type.StmtBegin, Keyword.EndCall, Type.StmtEnd);

        return new CallNode(pos, macroName, formalArgs, factArgs, block);
    }


    FilterBlockNode ParseFilterBlock(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Filter);

        auto filterName = Front.value;
        auto args = ParseCallExpr(dirPath);

        Pop(Type.StmtEnd);

        auto block = ParseStatementBlock(dirPath);

        Pop(Type.StmtBegin, Keyword.EndFilter, Type.StmtEnd);

        return new FilterBlockNode(pos, filterName, args, block);
    }

    StmtBlockNode ParseWith(string dirPath)
    {
        Pop(Keyword.With, Type.StmtEnd);
        auto block = ParseStatementBlock(dirPath);
        Pop(Type.StmtBegin, Keyword.EndWith, Type.StmtEnd);

        return block;
    }


    ImportNode ParseImport(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Import);
        auto path = Pop(Type.String).value.Absolute(dirPath);
        bool withContext = false;

        if (Front == Keyword.With)
        {
            withContext = true;
            Pop(Keyword.With, Keyword.Context);
        }

        if (Front == Keyword.Without)
        {
            withContext = false;
            Pop(Keyword.Without, Keyword.Context);
        }

        Pop(Type.StmtEnd);

        assertTemplate(path.FileExist(dirPath), "Non existing file `%s`".fmt(path), pos);

        auto stmtBlock = ParseTreeFromFile(path);

        return new ImportNode(pos, path, cast(ImportNode.Rename[])[], stmtBlock, withContext);
    }


    ImportNode ParseImportFrom(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.From);
        auto path = Pop(Type.String).value.Absolute(dirPath);
        Pop(Keyword.Import);

        ImportNode.Rename[] macros;

        bool firstName = true;
        while (Front == Type.Comma || firstName)
        {
            if (!firstName)
                Pop(Type.Comma);

            auto was = Pop(Type.Ident).value;
            auto become = was;

            if (Front == Keyword.As)
            {
                Pop(Keyword.As);
                become = Pop(Type.Ident).value;
            }

            macros ~= ImportNode.Rename(was, become);

            firstName = false;
        }

        bool withContext = false;

        if (Front == Keyword.With)
        {
            withContext = true;
            Pop(Keyword.With, Keyword.Context);
        }

        if (Front == Keyword.Without)
        {
            withContext = false;
            Pop(Keyword.Without, Keyword.Context);
        }

        Pop(Type.StmtEnd);

        assertTemplate(path.FileExist(dirPath), "Non existing file `%s`".fmt(path), pos);

        auto stmtBlock = ParseTreeFromFile(path);

        return new ImportNode(pos, path, macros, stmtBlock, withContext);
    }


    IncludeNode ParseInclude(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Include);

        string[] names;

        if (Front == Type.LSParen)
        {
            Pop(Type.LSParen);

            names ~= Pop(Type.String).value;
            while (Front == Type.Comma)
            {
                Pop(Type.Comma);
                names ~= Pop(Type.String).value;
            }

            Pop(Type.RSParen);
        }
        else
            names ~= Pop(Type.String).value;


        bool ignoreMissing = false;
        if (Front == Keyword.Ignore)
        {
            Pop(Keyword.Ignore, Keyword.Missing);
            ignoreMissing = true;
        }

        bool withContext = true;

        if (Front == Keyword.With)
        {
            withContext = true;
            Pop(Keyword.With, Keyword.Context);
        }

        if (Front == Keyword.Without)
        {
            withContext = false;
            Pop(Keyword.Without, Keyword.Context);
        }

        Pop(Type.StmtEnd);

        foreach (name; names)
            if (name.FileExist(dirPath))
                return new IncludeNode(pos, name, ParseTreeFromFile(dirPath ~ name), withContext);
 
        assertTemplate(ignoreMissing, "No existing files `%s`".fmt(names), pos);

        return new IncludeNode(pos, "", null, withContext);
    }


    ExtendsNode ParseExtends(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Extends);
        auto path = Pop(Type.String).value.Absolute(dirPath);
        Pop(Type.StmtEnd);

        assertTemplate(path.FileExist(dirPath), "Non existing file `%s`".fmt(path), pos);

        auto stmtBlock = ParseTreeFromFile(path);

        return new ExtendsNode(pos, path, stmtBlock);
    }


    BlockNode ParseBlock(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Keyword.Block);
        auto name = Pop(Type.Ident).value;
        Pop(Type.StmtEnd);

        auto stmt = ParseStatementBlock( dirPath);

        Pop(Type.StmtBegin, Keyword.EndBlock);

        auto posNameEnd = Front.pos;
        if (Front == Type.Ident)
            assertTemplate(Pop.value == name, "Missmatching block's begin/end names", posNameEnd);

        Pop(Type.StmtEnd);

        return new BlockNode(pos, name, stmt);
    }

    Arg[] ParseFormalArgs(string dirPath)
    {
        Arg[] args = [];
        bool isVarargs = true;

        while(Front.type != Type.EOF && Front.type != Type.RParen)
        {
            auto name = Pop(Type.Ident).value;
            Node def = null;

            if (!isVarargs || Front.type == Type.Operator && Front.value == Operator.Assign)
            {
                isVarargs = false;
                Pop(Operator.Assign);
                def = ParseHighLevelExpression(dirPath);
            }

            args ~= Arg(name, def);

            if (Front.type != Type.RParen)
                Pop(Type.Comma);
        }
        return args;
    }


    Node ParseHighLevelExpression(string dirPath)
    {
        return ParseInlineIf(dirPath);
    }


    /**
      * inlineif = orexpr (IF orexpr (ELSE orexpr)? )?
      */
    Node ParseInlineIf(string dirPath)
    {
        Node expr;
        Node cond = null;
        Node other = null;

        auto pos = Front.pos;
        expr = ParseOrExpr( dirPath);

        if (Front == Keyword.If)
        {
            Pop(Keyword.If);
            cond = ParseOrExpr( dirPath);

            if (Front == Keyword.Else)
            {
                Pop(Keyword.Else);
                other = ParseOrExpr(dirPath);
            }

            return new InlineIfNode(pos, expr, cond, other);
        }

        return expr;
    }

    /**
      * Parse Or Expression
      * or = and (OR or)?
      */
    Node ParseOrExpr(string dirPath)
    {
        auto lhs = ParseAndExpr(dirPath);

        while(true)
        {
            if (Front.type == Type.Operator && Front.value == Operator.Or)
            {
                auto pos = Front.pos;
                Pop(Operator.Or);
                auto rhs = ParseAndExpr( dirPath);
                lhs = new BinOpNode(pos, Operator.Or, lhs, rhs);
            }
            else
                return lhs;
        }
    }

    /**
      * Parse And Expression:
      * and = inis (AND inis)*
      */
    Node ParseAndExpr(string dirPath)
    {
        auto lhs = ParseInIsExpr( dirPath);

        while(true)
        {
            if (Front.type == Type.Operator && Front.value == Operator.And)
            {
                auto pos = Front.pos;
                Pop(Operator.And);
                auto rhs = ParseInIsExpr( dirPath);
                lhs = new BinOpNode(pos, Operator.And, lhs, rhs);
            }
            else
                return lhs;
        }
    }

    /**
      * Parse inis:
      * inis = cmp ( (NOT)? (IN expr |IS callexpr) )?
      */
    Node ParseInIsExpr(string dirPath)
    {
        auto inis = ParseCmpExpr( dirPath);

        auto notPos = Front.pos;
        bool hasNot = false;
        if (Front == Operator.Not && (Next == Operator.In || Next == Operator.Is))
        {
            Pop(Operator.Not);
            hasNot = true;
        }

        auto inisPos = Front.pos;

        if (Front == Operator.In)
        {
            auto op = Pop().value;
            auto rhs = ParseHighLevelExpression( dirPath);
            inis = new BinOpNode(inisPos, op, inis, rhs);
        }

        if (Front == Operator.Is)
        {
            auto op = Pop().value;
            auto rhs = ParseCallExpr( dirPath);
            inis = new BinOpNode(inisPos, op, inis, rhs);
        }

        if (hasNot)
            inis = new UnaryOpNode(notPos, Operator.Not, inis);

        return inis;
    }


    /**
      * Parse compare expression:
      * cmp = concatexpr (CMPOP concatexpr)?
      */
    Node ParseCmpExpr(string dirPath)
    {
        auto lhs = ParseConcatExpr( dirPath);

        if (Front.type == Type.Operator && Front.value.ToOperator.IsCmpOperator)
        {
            auto pos = Front.pos;
            auto op = Pop(Type.Operator).value;
            return new BinOpNode(pos, op, lhs, ParseConcatExpr( dirPath));
        }

        return lhs;
    }

    /**
      * Parse expression:
      * concatexpr = filterexpr (CONCAT filterexpr)*
      */
    Node ParseConcatExpr(string dirPath)
    {
        auto lhsTerm = ParseFilterExpr( dirPath);

        while (Front == Operator.Concat)
        {
            auto pos = Front.pos;
            auto op = Pop(Operator.Concat).value;
            lhsTerm = new BinOpNode(pos, op, lhsTerm, ParseFilterExpr( dirPath));
        }

        return lhsTerm;
    }

    /**
      * filterexpr = mathexpr (FILTER callexpr)*
      */
    Node ParseFilterExpr(string dirPath)
    {
        auto filterexpr = ParseMathExpr( dirPath);

        while (Front == Operator.Filter)
        {
            auto pos = Front.pos;
            auto op = Pop(Operator.Filter).value;
            filterexpr = new BinOpNode(pos, op, filterexpr, ParseCallExpr( dirPath));
        }

        return filterexpr;
    }

    /**
      * Parse math expression:
      * mathexpr = term((PLUS|MINUS)term)*
      */
    Node ParseMathExpr(string dirPath)
    {
        auto lhsTerm = ParseTerm( dirPath);

        while (true)
        {
            if (Front.type != Type.Operator)
                return lhsTerm;

            auto pos = Front.pos;
            switch (Front.value) with (Operator)
            {
                case Plus:
                case Minus:
                    auto op = Pop.value;
                    lhsTerm = new BinOpNode(pos, op, lhsTerm, ParseTerm( dirPath));
                    break;
                default:
                    return lhsTerm;
            }
        }
    }

    /**
      * Parse term:
      * term = unary((MUL|DIVI|DIVF|REM)unary)*
      */
    Node ParseTerm(string dirPath)
    {
        auto lhsFactor = ParseUnary( dirPath);

        while(true)
        {
            if (Front.type != Type.Operator)
                return lhsFactor;

            auto pos = Front.pos;
            switch (Front.value) with (Operator)
            {
                case DivInt:
                case DivFloat:
                case Mul:
                case Rem:
                    auto op = Pop.value;
                    lhsFactor = new BinOpNode(pos, op, lhsFactor, ParseUnary( dirPath));
                    break;
                default:
                    return lhsFactor;
            }
        } 
    }

    /**
      * Parse unary:
      * unary = (pow | (PLUS|MINUS|NOT)unary)
      */
    Node ParseUnary(string dirPath)
    {
        if (Front.type != Type.Operator)
            return ParsePow( dirPath);

        auto pos = Front.pos;
        switch (Front.value) with (Operator)
        {
            case Plus:
            case Minus:
            case Not:
                auto op = Pop.value;
                return new UnaryOpNode(pos, op, ParseUnary( dirPath));
            default:
                assertTemplate(0, "Unexpected operator `%s`".fmt(Front.value), Front.pos);
                assert(0);
        }
    }

    /**
      * Parse pow:
      * pow = factor (POW pow)?
      */
    Node ParsePow(string dirPath)
    {
        auto lhs = ParseFactor(dirPath);

        if (Front.type == Type.Operator && Front.value == Operator.Pow)
        {
            auto pos = Front.pos;
            auto op = Pop(Operator.Pow).value;
            return new BinOpNode(pos, op, lhs, ParsePow( dirPath));
        }

        return lhs;
    }


    /**
      * Parse factor:
      * factor = (ident|(tuple|LPAREN HighLevelExpr RPAREN)|literal)
      */
    Node ParseFactor(string dirPath)
    {
        switch (Front.type) with (Type)
        {
            case Ident:
                return ParseIdent( dirPath);

            case LParen:
                auto pos = Front.pos;
                Pop(LParen);
                bool hasCommas;
                auto exprList = ParseSequenceOf!ParseHighLevelExpression( dirPath,RParen, hasCommas);
                Pop(RParen);
                return hasCommas ? new ListNode(pos, exprList) : exprList[0];

            default:
                return ParseLiteral( dirPath);
        }
    }

    /**
      * Parse ident:
      * ident = IDENT (LPAREN ARGS RPAREN)? (DOT IDENT (LP ARGS RP)?| LSPAREN STR LRPAREN)*
      */
    Node ParseIdent(string dirPath)
    {
        string name = "";
        Node[] subIdents = [];
        auto pos = Front.pos;

        if (Next.type == Type.LParen)
            subIdents ~= ParseCallExpr( dirPath);
        else
            name = Pop(Type.Ident).value;

        while (true)
        {
            switch (Front.type) with (Type)
            {
                case Dot:
                    Pop(Dot);
                    auto posStr = Front.pos;
                    if (Next.type == Type.LParen)
                        subIdents ~= ParseCallExpr( dirPath);
                    else
                        subIdents ~= new StringNode(posStr, Pop(Ident).value);
                    break;
                case LSParen:
                    Pop(LSParen);
                    subIdents ~= ParseHighLevelExpression( dirPath);
                    Pop(RSParen);
                    break;
                default:
                    return new IdentNode(pos, name, subIdents);
            }
        }
    }


    IdentNode ParseCallIdent(string dirPath)
    {
        auto pos = Front.pos;
        return new IdentNode(pos, "", [ParseCallExpr( dirPath)]);
    }


    DictNode ParseCallExpr(string dirPath)
    {
        auto pos = Front.pos;
        string name = Pop(Type.Ident).value;
        Node[] varargs;
        Node[string] kwargs;

        bool parsingKwargs = false;
        void parse(string dirPath)
        {
            if (parsingKwargs || Front.type == Type.Ident && Next.value == Operator.Assign)
            {
                parsingKwargs = true;
                auto name = Pop(Type.Ident).value;
                Pop(Operator.Assign);
                kwargs[name] = ParseHighLevelExpression( dirPath);
            }
            else
                varargs ~= ParseHighLevelExpression( dirPath);
        }

        if (Front.type == Type.LParen)
        {
            Pop(Type.LParen);

            while (Front.type != Type.EOF && Front.type != Type.RParen)
            {
                parse( dirPath);

                if (Front.type != Type.RParen)
                    Pop(Type.Comma);
            }

            Pop(Type.RParen);
        }

        Node[string] callDict;
        callDict["name"] = new StringNode(pos, name);
        callDict["varargs"] = new ListNode(pos, varargs);
        callDict["kwargs"] = new DictNode(pos, kwargs);

        return new DictNode(pos, callDict);
    }

    /**
      * literal = string|number|list|tuple|dict
      */
    Node ParseLiteral(string dirPath)
    {
        auto pos = Front.pos;
        switch (Front.type) with (Type)
        {
            case Integer: return new NumNode(pos, Pop.value.to!long);
            case Float:   return new NumNode(pos, Pop.value.to!double);
            case String:  return new StringNode(pos, Pop.value);
            case Boolean: return new BooleanNode(pos, Pop.value.to!bool);
            case LParen:  return ParseTuple( dirPath);
            case LSParen: return ParseList( dirPath);
            case LBrace:  return ParseDict( dirPath);
            default:
                assertTemplate(0, "Unexpected token while parsing expression: %s(%s)".fmt(Front.type, Front.value), Front.pos);
                assert(0);
        }
    }


    Node ParseTuple(string dirPath)
    {
        //Literally array right now

        auto pos = Front.pos;
        Pop(Type.LParen);
        auto tuple = ParseSequenceOf!ParseHighLevelExpression( dirPath,Type.RParen);
        Pop(Type.RParen);

        return new ListNode(pos, tuple);
    }


    Node ParseList(string dirPath)
    {
        auto pos = Front.pos;
        Pop(Type.LSParen);
        auto list = ParseSequenceOf!ParseHighLevelExpression( dirPath,Type.RSParen);
        Pop(Type.RSParen);

        return new ListNode(pos, list);
    }


    Node[] ParseSequenceOf(alias parser)(string dirPath,Type stopSymbol)
    {
        bool hasCommas;
        return ParseSequenceOf!parser(dirPath,stopSymbol, hasCommas);
    }


    Node[] ParseSequenceOf(alias parser)(string dirPath,Type stopSymbol, ref bool hasCommas)
    {
        Node[] seq;

        hasCommas = false;
        while (Front.type != stopSymbol && Front.type != Type.EOF)
        {
            seq ~= parser(dirPath);

            if (Front.type != stopSymbol)
            {
                Pop(Type.Comma);
                hasCommas = true;
            }
        }

        return seq;
    }


    Node ParseDict(string dirPath)
    {
        Node[string] dict;
        auto pos = Front.pos;

        Pop(Type.LBrace);

        bool isFirst = true;
        while (Front.type != Type.RBrace && Front.type != Type.EOF)
        {
            if (!isFirst)
                Pop(Type.Comma);

            string key;
            if (Front.type == Type.Ident)
                key = Pop(Type.Ident).value;
            else
                key = Pop(Type.String).value;

            Pop(Type.Colon);
            dict[key] = ParseHighLevelExpression( dirPath);
            isFirst = false;
        }

        if (Front.type == Type.Comma)
            Pop(Type.Comma);

        Pop(Type.RBrace);

        return new DictNode(pos, dict);
    }


    void ParseComment(string dirPath)
    {
        Pop(Type.CmntBegin);
        while (Front.type != Type.CmntEnd && Front.type != Type.EOF)
            Pop();
        Pop(Type.CmntEnd);
    }


    Token Front()
    {
        if (_tokens.length)
            return _tokens[0];
        return Token.EOF;
    }

    Token Next()
    {
        if (_tokens.length > 1)
            return _tokens[1];
        return Token.EOF;
    }


    Token Pop()
    {
        auto tkn = Front();
        if (_tokens.length)
            _tokens = _tokens[1 .. $];
        return tkn;
    }


    Token Pop(Type t)
    {
        if (Front.type != t)
            assertTemplate(0, "Unexpected token %s(%s), expected: `%s`".fmt(Front.type, Front.value, t), Front.pos);
        return Pop();
    }


    Token Pop(Keyword kw)
    {
        if (Front.type != Type.Keyword || Front.value != kw)
            assertTemplate(0, "Unexpected token %s(%s), expected kw: %s".fmt(Front.type, Front.value, kw), Front.pos);
        return Pop();
    }


    Token Pop(Operator op)
    {
        if (Front.type != Type.Operator || Front.value != op)
            assertTemplate(0, "Unexpected token %s(%s), expected op: %s".fmt(Front.type, Front.value, op), Front.pos);
        return Pop();
    }


    void Pop(T...)(T args)
        if (args.length > 1)
    {
        foreach(arg; args)
            Pop(arg);
    }


    void StashState()
    {
        ParserState old;
        old.tokens = _tokens;
        old.blocks = _blocks;
        _states ~= old;
        _tokens = [];
        _blocks = (BlockNode[string]).init;
    }


    void PopState()
    {
        assertTemplate(_states.length > 0, "Unexpected empty state stack");

        auto state = _states.back;
        _states.popBack;
        _tokens = state.tokens;
        _blocks = state.blocks;
    }
}


private:


string Absolute(string file,string path)
{
    //TODO
    // return path;
    import std.path : absolutePath;
    return (path ~ file);
}

bool FileExist(string file,string path)
{
    import std.path : absolutePath;
    version(HUNT_FM_DEBUG) logDebug("path.absolutePath : ",(path ~ file).absolutePath);
    return (file.exists) || ((path ~ file).absolutePath.exists);
}

string StripOnceRight(string str)
{
    import std.uni;
    import std.utf : codeLength;

    import std.traits;
    alias C = Unqual!(ElementEncodingType!string);

    bool stripped = false;
    foreach_reverse (i, dchar c; str)
    {
        if (!isWhite(c))
            return str[0 .. i + codeLength!C(c)];

        if (c == '\n' || c == '\r' || c == 0x2028 || c == 0x2029)
        {
            return str[0 .. i];
        }
    }

    return str[0 .. 0];
}

unittest
{
    assert(StripOnceRight("\n") == "", StripOnceRight("\n"));
}
