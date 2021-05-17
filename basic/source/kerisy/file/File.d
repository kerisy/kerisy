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

module kerisy.file.File;

import kerisy.file.Exceptions;
import kerisy.BasicSimplify;
import kerisy.util.String;

import std.path : dirName, buildPath;
import std.file : getSize, rename, isFile, isDir, exists;
import std.format;

class File
{
    private string _path;

    /**
     * Constructs a new file from the given path.
     *
     * @param string $path      The path to the file
     * @param bool   $checkPath Whether to check the path or not
     *
     * @throws FileNotFoundException If the given path is not a file
     */
    public this(string path, bool checkPath = true)
    {
        if (checkPath && isFile(path)) {
            throw new FileNotFoundException(path);
        }
        
        this._path = buildPath(APP_PATH, path);
    }

    public string Path()
    {
        return this._path;
    }

    public long Size()
    {
        return getSize(this._path);
    }

    /**
     * Returns the extension based on the mime type.
     *
     * If the mime type is unknown, returns null.
     *
     * This method uses the mime type as guessed by GetMimeType()
     * to guess the file extension.
     *
     * @return string|null The guessed extension or null if it cannot be guessed
     *
     * @see MimeTypes
     * @see GetMimeType()
     */
    public string Extension()
    {
        // return MimeTypes::getDefault().getExtensions(this.GetMimeType())[0] ?? null;
        return null;
    }

    /**
     * Returns the mime type of the file.
     *
     * The mime type is guessed using a MimeTypeGuesserInterface instance,
     * which uses finfo_file() then the "file" system binary,
     * depending on which of those are available.
     *
     * @return string|null The guessed mime type (e.g. "application/pdf")
     *
     * @see MimeTypes
     */
    public string MimeType()
    {
        return GetMimeTypeByFilename(this.Path());
    }

    /**
     * Moves the file to a new location.
     *
     * @param string $path The file realpath
     *
     * @return self A File object representing the new file
     *
     * @throws FileException if the target file could not be created
     */
    public bool Move(string path)
    {
        string target = this.GetTargetFile(path);
        
        // error to throw FileException
        rename(this.Path(), target);

        version (Posix)
        {
            import std.exception : assertNotThrown;
            import std.conv : octal;
            import std.file : setAttributes;

            assertNotThrown!FileException(target.setAttributes(octal!644));
        }
        
        return true;
    }

    protected string GetTargetFile(string path)
    {
        string target = buildPath(APP_PATH, path);
        // if (isDir(target)) {
        //     throw new FileException(format("Unable to create the \"%s\" directory.", target));
        // }

        if (exists(target))
        {
            throw new FileException(format("The file or directory \"%s\" exists.", target));
        }

        return target;
    }

    /**
     * Returns locale independent base name of the given path.
     *
     * @param string $name The new file name
     *
     * @return string containing
     */
    protected string getName(string name = null)
    {
        import std.string : lastIndexOf, replace;

        string originalName;

        if (name.length == 0)
        {
            originalName = this._path;
        }
        else
        {
            originalName = name;
        }

        originalName = originalName.replace("\\", "/");
        ptrdiff_t index = lastIndexOf(originalName, '/');
        if(index>=0) {
            originalName = originalName[index..$];
        }

        return originalName;
    }
}
