/*
 * Kerisy - Hunt is a high-level D Programming Language Web framework that encourages rapid development and clean, pragmatic design. It lets you build high-performance Web applications quickly and easily.
 *
 * Copyright (C) 2015-2018  Shanghai Putao Technology Co., Ltd
 *
 * Website: www.huntframework.com
 *
 * Licensed under the Apache-2.0 License.
 *
 */

module kerisy.Exceptions;

import hunt.Exceptions;

mixin ExceptionBuild!("Kerisy","");

mixin ExceptionBuild!("Http","Kerisy");

mixin ExceptionBuild!("HttpErro","Http");

mixin ExceptionBuild!("CreateResponse","HttpErro");

