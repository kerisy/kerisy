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

module kerisy.Version;

import std.conv : to;

// define Kerisy versions
enum int KERISY_MAJOR_VERSION = 0;
enum int KERISY_MINOR_VERSION = 1;
enum int KERISY_PATCH_VERSION = 0;

enum KERISY_VERSION = KERISY_MAJOR_VERSION.to!string ~ "." ~ to!string(KERISY_MINOR_VERSION) ~ "." ~ to!string(KERISY_PATCH_VERSION);
enum KERISY_X_POWERED_BY = "Kerisy v" ~ KERISY_VERSION;
enum KERISY_FRAMEWORK_SERVER = "Kerisy/" ~ KERISY_VERSION;
