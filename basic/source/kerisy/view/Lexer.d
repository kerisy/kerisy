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

module kerisy.view.Lexer;


private
{
    import kerisy.view.Exception : TemplateException;

    import std.conv : to;
    import std.traits : EnumMembers;
    import std.utf;
    import std.range;
}


enum Type
{
    Unknown,
    Raw,
    Keyword,
    Operator,

    StmtBegin,
    StmtEnd,
    ExprBegin,
    ExprEnd,
    CmntBegin,
    CmntEnd,
    CmntInline,

    Ident,
    Integer,
    Float,
    Boolean,
    String,

    LParen,
    RParen,
    LSParen,
    RSParen,
    LBrace,
    RBrace,

    Dot,
    Comma,
    Colon,

    EOL,
    EOF,
}


enum Keyword : string
{
    Unknown = "",
    For = "for",
    Recursive = "recursive",
    EndFor = "endfor",
    If = "if",
    ElIf = "elif",
    Else = "else",
    EndIf = "endif",
    Block = "block",
    EndBlock = "endblock",
    Extends = "extends",
    Macro = "macro",
    EndMacro = "endmacro",
    Return = "return",
    Call = "call",
    EndCall = "endcall",
    Filter = "filter",
    EndFilter = "endfilter",
    With = "with",
    EndWith = "endwith",
    Set = "set",
    EndSet = "endset",
    Ignore = "ignore",
    Missing = "missing",
    Import = "import",
    From = "from",
    As = "as",
    Without = "without",
    Context = "context",
    Include = "include",
}

bool IsBeginingKeyword(Keyword kw)
{
    import std.algorithm : among;

    return cast(bool)kw.among(
                Keyword.If,
                Keyword.Set,
                Keyword.For,
                Keyword.Block,
                Keyword.Extends,
                Keyword.Macro,
                Keyword.Call,
                Keyword.Filter,
                Keyword.With,
                Keyword.Include,
                Keyword.Import,
                Keyword.From,
        );
}

Keyword ToKeyword(string key)
{
    switch (key) with (Keyword)
    {
        static foreach(member; EnumMembers!Keyword)
        {
            case member:
                return member;
        }
        default :
            return Unknown;
    }
}


bool IsKeyword(string key)
{
    return key.ToKeyword != Keyword.Unknown;
}


bool IsBoolean(string key)
{
    return key == "true" || key == "false" ||
           key == "True" || key == "False";
}


enum Operator : string
{
    // The first in order is the first in priority

    Eq = "==",
    NotEq = "!=",
    LessEq = "<=",
    GreaterEq = ">=",
    Less = "<",
    Greater = ">",

    And = "and",
    Or = "or",
    Not = "not",

    In = "in",
    Is = "is",

    Assign = "=",
    Filter = "|",
    Concat = "~",

    Plus = "+",
    Minus = "-",

    DivInt = "//",
    DivFloat = "/",
    Rem = "%",
    Pow = "**",
    Mul = "*",
}


Operator ToOperator(string key)
{
    switch (key) with (Operator)
    {
        static foreach(member; EnumMembers!Operator)
        {
            case member:
                return member;
        }
        default :
            return cast(Operator)"";
    }
}

bool IsOperator(string key)
{
    switch (key) with (Operator)
    {
        static foreach(member; EnumMembers!Operator)
        {
            case member:
        }
                return true;
        default :
            return false;
    }
}

bool IsCmpOperator(Operator op)
{
    import std.algorithm : among;

    return cast(bool)op.among(
            Operator.Eq,
            Operator.NotEq,
            Operator.LessEq,
            Operator.GreaterEq,
            Operator.Less,
            Operator.Greater
        );
}


bool IsIdentOperator(Operator op)()
{
    import std.algorithm : filter;
    import std.uni : isAlphaNum;

    static if (!(cast(string)op).filter!isAlphaNum.empty)
        return true;
    else
        return false;
}


struct Position
{
    string filename;
    ulong line, column;

    string toString()
    {
        return filename ~ "(" ~ line.to!string ~ "," ~ column.to!string ~ ")";
    }
}


struct Token
{
    enum EOF = Token(Type.EOF, Position("", 0, 0));

    Type type;
    string value;
    Position pos;

    this (Type t, Position p)
    {
        type = t;
        pos = p;
    }

    this(Type t, string v, Position p)
    {
        type = t;
        value = v;
        pos = p;
    }

    bool opEquals(Type type){
        return this.type == type;
    }

    bool opEquals(Keyword kw){
        return this.type == Type.Keyword && value == kw;
    }

    bool opEquals(Operator op){
        return this.type == Type.Operator && value == op;
    }
}


struct Lexer(
        string exprOpBegin, string exprOpEnd,
        string stmtOpBegin, string stmtOpEnd,
        string cmntOpBegin, string cmntOpEnd,
        string stmtOpInline, string cmntOpInline)
{
    static assert(exprOpBegin.length, "Expression begin operator can't be empty");
    static assert(exprOpEnd.length, "Expression end operator can't be empty");

    static assert(stmtOpBegin.length, "Statement begin operator can't be empty");
    static assert(stmtOpEnd.length, "Statement end operator can't be empty");

    static assert(cmntOpBegin.length, "Comment begin operator can't be empty");
    static assert(cmntOpEnd.length, "Comment end operator can't be empty");

    static assert(stmtOpInline.length, "Statement inline operator can't be empty");
    static assert(cmntOpInline.length, "Comment inline operator can't be empty");

    //TODO check uniq


    enum stmtInline = stmtOpInline;
    enum EOF = 255;

    private
    {
        Position _beginPos;
        bool _isReadingRaw; // State of reading raw data
        bool _isInlineStmt; // State of reading inline statement
        string _str;
        string _filename;
        ulong _line, _column;
    }

    this(string str, string filename = "")
    {
        _str = str;
        _isReadingRaw = true;
        _isInlineStmt = false;
        _filename = filename;
        _line = 1;
        _column = 1;
    }

    Token NextToken()
    {
        _beginPos = position();

        // Try to read raw data
        if (_isReadingRaw)
        {
            auto raw = SkipRaw();
            _isReadingRaw = false;
            if (raw.length)
                return Token(Type.Raw, raw, _beginPos);
        }

        SkipWhitespaces();
        _beginPos = position();

        // Check inline statement end
        if (_isInlineStmt &&
            (TryToSkipNewLine() || cmntOpInline == SliceOp!cmntOpInline))
        {
            _isInlineStmt = false;
            _isReadingRaw = true;
            return Token(Type.StmtEnd, "\n", _beginPos);
        }

        // Allow multiline inline statements with '\'
        while (true)
        {
            if (_isInlineStmt && Front == '\\')
            {
                Pop();
                if (!TryToSkipNewLine())
                    return Token(Type.Unknown, "\\", _beginPos);
            }
            else
                break;

            SkipWhitespaces();
            _beginPos = position();
        }

        // Check begin operators
        if (exprOpBegin == SliceOp!exprOpBegin)
        {
            SkipOp!exprOpBegin;
            return Token(Type.ExprBegin, exprOpBegin, _beginPos);
        }
        if (stmtOpBegin == SliceOp!stmtOpBegin)
        {
            SkipOp!stmtOpBegin;
            return Token(Type.StmtBegin, stmtOpBegin, _beginPos);
        }
        if (cmntOpBegin == SliceOp!cmntOpBegin)
        {
            SkipOp!cmntOpBegin;
            SkipComment();
            return Token(Type.CmntBegin, cmntOpBegin, _beginPos);
        }

        // Check end operators
        if (exprOpEnd == SliceOp!exprOpEnd)
        {
            _isReadingRaw = true;
            SkipOp!exprOpEnd;
            return Token(Type.ExprEnd, exprOpEnd, _beginPos);
        }
        if (stmtOpEnd == SliceOp!stmtOpEnd)
        {
            _isReadingRaw = true;
            SkipOp!stmtOpEnd;
            return Token(Type.StmtEnd, stmtOpEnd, _beginPos);
        }
        if (cmntOpEnd == SliceOp!cmntOpEnd)
        {
            _isReadingRaw = true;
            SkipOp!cmntOpEnd;
            return Token(Type.CmntEnd, cmntOpEnd, _beginPos);
        }

        // Check begin inline operators
        if (cmntOpInline == SliceOp!cmntOpInline)
        {
            SkipInlineComment();
            _isReadingRaw = true;
            return Token(Type.CmntInline, cmntOpInline, _beginPos);
        }
        if (stmtOpInline == SliceOp!stmtOpInline)
        {
            SkipOp!stmtOpInline;
            _isInlineStmt = true;
            return Token(Type.StmtBegin, stmtOpInline, _beginPos);
        }

        // Trying to read non-ident operators
        static foreach(op; EnumMembers!Operator)
        {
            static if (!IsIdentOperator!op)
            {
                if (cast(string)op == SliceOp!op)
                {
                    SkipOp!op;
                    return Token(Type.Operator, op, _beginPos);
                }
            }
        }

        // Check remainings 
        switch (Front)
        {
            // End of file
            case EOF:
                return Token(Type.EOF, _beginPos);


            // Identifier or keyword
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
            case '_':
                auto ident = PopIdent();
                if (ident.ToKeyword != Keyword.Unknown)
                    return Token(Type.Keyword, ident, _beginPos);
                else if (ident.IsBoolean)
                    return Token(Type.Boolean, ident, _beginPos);
                else if (ident.IsOperator)
                    return Token(Type.Operator, ident, _beginPos);
                else
                    return Token(Type.Ident, ident, _beginPos);

            // Integer or float
            case '0': .. case '9':
                return PopNumber();

            // String
            case '"':
            case '\'':
                return Token(Type.String, PopString(), _beginPos);

            case '(': return Token(Type.LParen, PopChar, _beginPos);
            case ')': return Token(Type.RParen, PopChar, _beginPos);
            case '[': return Token(Type.LSParen, PopChar, _beginPos);
            case ']': return Token(Type.RSParen, PopChar, _beginPos);
            case '{': return Token(Type.LBrace, PopChar, _beginPos);
            case '}': return Token(Type.RBrace, PopChar, _beginPos);
            case '.': return Token(Type.Dot, PopChar, _beginPos);
            case ',': return Token(Type.Comma, PopChar, _beginPos);
            case ':': return Token(Type.Colon, PopChar, _beginPos);

            default:
                return Token(Type.Unknown, PopChar, _beginPos);
        }
    }


private:


    dchar Front()
    {
        if (_str.length > 0)
            return _str.front;
        else
            return EOF;
    }


    dchar Next()
    {
        auto chars = _str.take(2).array;
        if (chars.length < 2)
            return EOF;
        return chars[1];
    }

    dchar Pop()
    {
        if (_str.length > 0)
        {
            auto ch  = _str.front;

            if (ch.IsNewLine && !(ch == '\r' && Next == '\n'))
            {
                _line++;
                _column = 1;
            }
            else
                _column++;

            _str.popFront();
            return ch;
        } 
        else
            return EOF;
    }


    string PopChar()
    {
        return Pop.to!string;
    }


    string SliceOp(string op)()
    {
        enum length = op.walkLength;

        if (length >= _str.length)
            return _str;
        else
            return _str[0 .. length];
    }


    void SkipOp(string op)()
    {
        enum length = op.walkLength;

        if (length >= _str.length)
            _str = "";
        else
            _str = _str[length .. $];
        _column += length;
    }


    Position position()
    {
        return Position(_filename, _line, _column);
    }


    void SkipWhitespaces()
    {
        while (true)
        {
            if (Front.IsWhiteSpace)
            {
                Pop();
                continue;
            }

            if (IsFronNewLine)
            {
                // Return for handling NL as StmtEnd
                if (_isInlineStmt)
                    return;
                TryToSkipNewLine();
                continue;
            }

            return;
        }
    }


    string PopIdent()
    {
        string ident = "";
        while (true)
        {
            switch(Front)
            {
                case 'a': .. case 'z':
                case 'A': .. case 'Z':
                case '0': .. case '9':
                case '_':
                    ident ~= Pop();
                    break;
                default:
                    return ident;
            }
        }
    }


    Token PopNumber()
    {
        auto type = Type.Integer;
        string number = "";

        while (true)
        {
            switch (Front)
            {
                case '0': .. case '9':
                    number ~= Pop();
                    break;
                case '.':
                    if (type == Type.Integer)
                    {
                        type = Type.Float;
                        number ~= Pop();
                    }
                    else
                        return Token(type, number, _beginPos);
                    break;
                case '_':
                    Pop();
                    break;
                default:
                    return Token(type, number, _beginPos);
            }
        }
    }


    string PopString()
    {
        auto ch = Pop();
        string str = "";
        auto prev = ch;

        while (true)
        {
            if (Front == EOF)
                return str;

            if (Front == '\\')
            {
                Pop();
                if (Front != EOF)
                {
                    prev = Pop();
                    switch (prev)
                    {
                        case 'n': str ~= '\n'; break;
                        case 'r': str ~= '\r'; break;
                        case 't': str ~= '\t'; break;
                        default: str ~= prev; break;
                    }
                }
                continue;
            }

            if (Front == ch)
            {
                Pop();
                return str;
            }

            prev = Pop();
            str ~= prev;
        }
    }


    string SkipRaw()
    {
        string raw = "";

        while (true)
        {
            if (Front == EOF)
                return raw;

            if (exprOpBegin == SliceOp!exprOpBegin)
                return raw;
            if (stmtOpBegin == SliceOp!stmtOpBegin)
                return raw;
            if (cmntOpBegin == SliceOp!cmntOpBegin)
                return raw;
            if (stmtOpInline == SliceOp!stmtOpInline)
                return raw;
            if (cmntOpInline == SliceOp!cmntOpInline)
                return raw;

            raw ~= Pop();
        }
    }


    void SkipComment()
    {
        while(Front != EOF)
        {
            if (cmntOpEnd == SliceOp!cmntOpEnd)
                return;
            Pop();
        }
    }


    void SkipInlineComment()
    {
        auto column = _column;

        while(Front != EOF)
        {
            if (Front == '\n')
            {
                // Eat new line if whole line is comment
                if (column == 1)
                    Pop();
                return;
            }
            Pop();
        }
    }


    bool IsFronNewLine()
    {
        auto ch = Front;
        return ch == '\r' || ch == '\n' || ch == 0x2028 || ch == 0x2029; 
    }

    /// true if NL was skiped
    bool TryToSkipNewLine()
    {
        switch (Front)
        {
            case '\r':
                Pop();
                if (Front == '\n')
                    Pop();
                return true;

            case '\n':
            case 0x2028:
            case 0x2029:
                Pop();
                return true;

            default:
                return false;
        }
    }
}


bool IsWhiteSpace(dchar ch)
{
    return ch == ' ' || ch == '\t' || ch == 0x205F || ch == 0x202F || ch == 0x3000
           || ch == 0x00A0 || (ch >= 0x2002 && ch <= 0x200B);
}

bool IsNewLine(dchar ch)
{
    return ch == '\r' || ch == '\n' || ch == 0x2028 || ch == 0x2029;
}
