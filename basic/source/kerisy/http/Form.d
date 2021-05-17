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

module kerisy.http.Form;

// import hunt.validation.ConstraintValidatorContext;
import hunt.validation.Valid;

import hunt.serialization.JsonSerializer;

interface Form : Valid
{
}

mixin template MakeForm()
{
    mixin MakeValid;
}

alias FormProperty = JsonProperty;
