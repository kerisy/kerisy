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

module kerisy.view.ast.Visitor;

private
{
    import kerisy.view.ast.Node;
}

mixin template VisitNode(T)
{
    void Visit(T);
}

interface VisitorInterface
{
    static foreach(NT; NodeTypes)
    {
        mixin VisitNode!NT;
    }
}
