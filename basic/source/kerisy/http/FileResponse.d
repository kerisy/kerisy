module kerisy.http.FileResponse;

import std.array;
import std.conv;
import std.datetime;
import std.json;
import std.path;
import std.file;
import std.stdio;

import kerisy.http.Response;
import kerisy.Init;
import kerisy.util.String;

import hunt.logging.ConsoleLogger;
import hunt.http.server;

/**
 * FileResponse represents an HTTP response delivering a file.
 */
class FileResponse : Response {
    private string _file;
    private string _name = "undefined.file";
    private string _contentType;

    this(string filename) {
        this.SetFile(filename);
    }

    FileResponse SetFile(string filename) {
        _file = buildPath(APP_PATH, filename);
        string contentType = GetMimeTypeByFilename(_file);

        version(HUNT_DEBUG) logInfof("_file=>%s, contentType=%s", _file, contentType);

        this.SetMimeType(contentType);
        this.SetName(baseName(filename));
        this.LoadData();
        return this;
    }

    FileResponse SetName(string name) {
        _name = name;
        return this;
    }

    FileResponse SetMimeType(string contentType) {
        _contentType = contentType;
        return this;
    }

    FileResponse LoadData() {
        version(HUNT_DEBUG) logDebug("downloading file: ", _file);

        if (exists(_file) && !isDir(_file)) {
            // SetData([0x11, 0x22]);
            // FIXME: Needing refactor or cleanup -@zxp at 5/24/2018, 6:49:23 PM
            // download a huge file.
            // read file
            auto f = std.stdio.File(_file, "r");
            scope (exit)
                f.close();

            f.seek(0);
            // logDebug("file size: ", f.size);
            auto buf = f.rawRead(new ubyte[cast(uint) f.size]);
            SetData(buf);
        } else
            throw new Exception("File does not exist: " ~ _file);

        return this;
    }

    FileResponse SetData(in ubyte[] data) {
        Header(HttpHeader.CONTENT_DISPOSITION,
                "attachment; filename=" ~ _name ~ "; size=" ~ (to!string(data.length)));
        SetContent(data, _contentType);
        return this;
    }
}
