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

module kerisy.http.Request;

import kerisy.auth;
import kerisy.file.UploadedFile;
import kerisy.http.session.SessionStorage;
import kerisy.Init;
import kerisy.provider.ServiceProvider;
import kerisy.routing;

import hunt.http.AuthenticationScheme;
import hunt.http.Cookie;
import hunt.http.HttpFields;
import hunt.http.HttpMethod;
import hunt.http.HttpHeader;
import hunt.http.MultipartForm;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpSession;
import hunt.logging.ConsoleLogger;
import hunt.serialization.JsonSerializer;

import std.algorithm;
import std.array : split;
import std.base64;
import std.json;
import std.format;
import std.range;
import std.socket;
import std.string;
import std.regex;
import std.digest.sha;


import core.time;




enum BasicTokenHeader = AuthenticationScheme.Basic ~ " ";
enum BearerTokenHeader = AuthenticationScheme.Bearer ~ " ";

/**
 * 
 */
class Request {

    private HttpSession _session;
    private SessionStorage _sessionStorage;
    private bool _isMultipart = false;
    private bool _isXFormUrlencoded = false;
    private UploadedFile[] _convertedAllFiles;
    private UploadedFile[][string] _convertedMultiFiles;
    private string _routeGroup = DEFAULT_ROUTE_GROUP;
    // private string _actionId = "";
    private Auth _auth;
    private string _guardName;
    private MonoTime _monoCreated;
    private bool _isRestful = false;

    private string[][string] _formats;

    private ActionRouteItem _routeItem;
    private HttpServerRequest _request;
    //alias _request this;

    this(HttpServerRequest request, Address remoteAddress, RouterContex routeContext=null) {
        _request = request;
        if(routeContext !is null) {
            ActionRouteItem routeItem = cast(ActionRouteItem)routeContext.routeItem;
            assert(routeItem !is null);
            _routeItem = routeItem;

            // if(routeItem !is null)
            //     _actionId = routeItem.actionId;
            _routeGroup = routeContext.routeGroup.name;
            _guardName = routeContext.routeGroup.GuardName;
        }
        _monoCreated = MonoTime.currTime;
        _sessionStorage = serviceContainer().resolve!SessionStorage();
        _remoteAddr = remoteAddress;

        .request(this); // Binding this request to the current thread.
    }

    Auth auth() {
        if(_auth is null) {
            _auth = new Auth(this);
        }
        return _auth;
    }

    bool isRestful() {
        return _isRestful;
    }

    void isRestful(bool value) {
        _isRestful = value;
    }

    string actionId() {
        return _routeItem.ActionId;
    }

    string routeGroup() {
        return _routeGroup;
    }

    string guardName() {
        return _guardName;
    }
    
    bool isMultipartForm() {
        return _request.isMultipartForm();
    }

    T get(T = string)(string key, T v = T.init) {
        return _request.get!(T)(key, v);
    }

    HttpFields getFields() {
        return _request.getFields();
    }

    T bindForm(T)() {   
        return _request.bindForm!(T)();
    }

    ref string[string] queries() {
        return _request.queries();
    }

    string[][string] xFormData() {
        return _request.xFormData();
    }

    private bool isContained(string source, string[] keys) {
        foreach (string k; keys) {
            if (canFind(source, k))
                return true;
        }
        return false;
    }

    /**
     * Retrieve a header from the request.
     *
     * @param  string|null  key
     * @param  string|array|null  default
     * @return string|array|null
     */
    string Header(string key) {
        return _request.header(key);
    }
    string Header(HttpHeader h) {
        return _request.header(h);
    }
    // string Header(string key, string defaultValue = null) {
    //     return _request.Header(key, defaultValue);
    // }

    /**
     * Determine if the uploaded data contains a file.
     *
     * @param  string  key
     * @return bool
     */
    bool HasFile(string key) {
        if (!isMultipartForm()) {
            return false;
        } else {
            checkUploadedFiles();

            if (_convertedMultiFiles is null || _convertedMultiFiles.get(key, null) is null) {
                return false;
            }
            return true;
        }
    }

    /**
     * Check that the given file is a valid file instance.
     *
     * @param  mixed  file
     * @return bool
     */
    bool IsValidFile(string file)
    {
        if (_convertedMultiFiles is null || _convertedMultiFiles.get(file, null) is null) {
            return false;
        }
        return true;
    }

    private void checkUploadedFiles() {
        if (_convertedAllFiles.empty()) {
            convertUploadedFiles();
        }
    }

    private void convertUploadedFiles() {
        foreach (Part part; _request.getParts()) {
            MultipartForm multipart = cast(MultipartForm) part;

            version (HUNT_HTTP_DEBUG) {
                tracef("File: key=%s, fileName=%s, actualFile=%s, ContentType=%s, content=%s",
                        multipart.getName(), multipart.getSubmittedFileName(),
                        multipart.getFile(), multipart.getContentType(),
                        cast(string) multipart.getBytes());
            }

            string contentType = multipart.getContentType();
            string submittedFileName = multipart.getSubmittedFileName();
            string key = multipart.getName();
            if (!submittedFileName.empty) {
                // TODO: for upload failed? What's the errorCode? use multipart.isWriteToFile?
                int errorCode = 0;
                multipart.flush();
                auto file = new UploadedFile(multipart.getFile(),
                        submittedFileName, contentType, errorCode);

                this._convertedMultiFiles[key] ~= file;
                this._convertedAllFiles ~= file;
            }
        }
    }


    /**
     * Retrieve a file from the request.
     *
     * @param  string  key
     * @param  mixed default
     * @return UploadedFile
     */
    UploadedFile File(string key)
    {
        if (this.HasFile(key))
        {
            return this._convertedMultiFiles[key][0];
        }

        return null;
    }

    UploadedFile[] Files(string key)
    {
        if (this.HasFile(key))
        {
            return this._convertedMultiFiles[key];
        }

        return null;
    }

     /**
     todo:
     * Filter the given array of files, removing any empty values.
     *
     * @param  mixed  files
     * @return mixed
     */
    string FilterFiles(string files)
    {
        if (_convertedMultiFiles is null || _convertedMultiFiles.get(files, null) is null) {
            return "";
        }

        return "";
    }


    /**
     * Retrieve a parameter item from a given source.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array|null
     */
    T RetrieveItem(T = string)(string key, T v = T.init) {
        return _request.get(key, v);
    }



    @property int elapsed() 
    {
        Duration timeElapsed = MonoTime.currTime - _monoCreated;
        return cast(int)timeElapsed.total!"msecs";
    }


    bool headerExists(HttpHeader code) {
        return getFields().contains(code);
    }

    bool headerExists(string key) {
        return getFields().containsKey(key);
    }

    @property Address remoteAddr() {
        return _remoteAddr;
    }
    private Address _remoteAddr;

    @property string getIp() {
        string s = this.Header(HttpHeader.X_FORWARDED_FOR);
        if(s.empty) {
            s = this.Header("Proxy-Client-IP");
        } else {
            auto arr = s.split(",");
            if(arr.length >= 0)
                s = arr[0];
        }

        if(s.empty) {
            s = this.Header("WL-Proxy-Client-IP");
        }

        if(s.empty) {
            s = this.Header("HTTP_CLIENT_IP");
        }

        if(s.empty) {
            s = this.Header("HTTP_X_FORWARDED_FOR");
        } 

        if(s.empty) {
            Address ad = remoteAddr();
            s = ad.toAddrString();
        }

        return s;
    }    

    @property JSONValue json() {
        if (_json == JSONValue.init)
            _json = parseJSON(getBodyAsString());
        return _json;
    }
    private JSONValue _json;

    /**
     * Get the JSON payload for the request.
     *
     * @param  string  key
     * @param  mixed default
     * @return mixed
     */
    T Json(T = string)(string key, T defaults = T.init) {
        import std.traits;

        auto obj = (key in (json().objectNoRef));
        if (obj is null)
            return defaults;

        static if (isIntegral!(T))
            return cast(T)((*obj).integer);
        else static if (is(T == string))
            return (*obj).str;
        else static if (is(FloatingPointTypeOf!T X))
            return cast(T)((*obj).floating);
        else static if (is(T == bool)) {
            if (obj.type == JSON_TYPE.TRUE)
                return true;
            else if (obj.type == JSON_TYPE.FALSE)
                return false;
            else {
                throw new Exception("json error");
                return false;
            }
        }
        else {
            return (*obj);
        }
    }


    string getBodyAsString() {
        if (stringBody is null) {
            stringBody = _request.getStringBody();
        }
        return stringBody;
    }
    private string stringBody;


    /**
     * Determine if the request is sending JSON.
     *
     * @return bool
     */
    @property bool IsJson() {
        string s = this.Header(HttpHeader.CONTENT_TYPE);
        return canFind(s, "/json") || canFind(s, "+json");
    }

    /**
     * Determine if the current request probably expects a JSON response.
     *
     * @return bool
     */
    @property bool ExpectsJson() {
        return (this.Ajax && !this.Pjax) || this.WantsJson();
    }

    /**
     * Gets a list of content types acceptable by the client browser.
     *
     * @return array List of content types in preferable order
     */
    string[] getAcceptableContentTypes() {
        if (acceptableContentTypes is null) {
            acceptableContentTypes = getFields().getValuesList("Accept");
        }

        return acceptableContentTypes;
    }

    protected string[] acceptableContentTypes = null;

    /**
     * Determine if the current request is asking for JSON.
     *
     * @return bool
     */
    @property bool WantsJson() {
        string[] acceptable = getAcceptableContentTypes();
        if (acceptable is null)
            return false;
        return canFind(acceptable[0], "/json") || canFind(acceptable[0], "+json");
    }

    /**
     * Determines whether the current requests accepts a given content type.
     *
     * Parameters string[] contentTypes
     * 
     * @return bool
     */
    @property bool Accepts(string[] contentTypes) {
        string[] acceptTypes = getAcceptableContentTypes();
        if (acceptTypes is null)
            return true;

        string[] types = contentTypes;
        foreach (string accept; acceptTypes) {
            if (accept == "*/*" || accept == "*")
                return true;

            foreach (string type; types) {
                size_t index = indexOf(type, "/");
                string name = type[0 .. index] ~ "/*";
                if (matchesType(accept, type) || accept == name)
                    return true;
            }
        }
        return false;
    }

    static bool matchesType(string actual, string type) {
        if (actual == type) {
            return true;
        }

        string[] split = split(actual, "/");

        // TODO: Tasks pending completion -@zxp at 5/14/2018, 3:28:15 PM
        // 
        return split.length >= 2; // && preg_match('#'.preg_quote(split[0], '#').'/.+\+'.preg_quote(split[1], '#').'#', type);
    }

    /**
     * Return the most suitable content type from the given array based on content negotiation.
     *
     * Parameters string[] contentTypes
     * 
     * @return bool
     */
    @property string Prefers(string[] contentTypes) {
        string[] acceptTypes = getAcceptableContentTypes();

        foreach (string accept; acceptTypes) {
            if (accept == "*/*" || accept == "*")
                return acceptTypes[0];

            foreach (string contentType; contentTypes) {
                string type = contentType;
                string mimeType = GetMimeType(contentType);
                if (!mimeType.empty)
                    type = mimeType;

                size_t index = indexOf(type, "/");
                string name = type[0 .. index] ~ "/*";
                if (matchesType(accept, type) || accept == name)
                    return contentType;
            }
        }
        return null;
    }

    /**
     * Gets the mime type associated with the format.
     *
     * @param stringformat The format
     *
     * @return string The associated mime type (null if not found)
     */
    string GetMimeType(string format) {
        string[] r = GetMimeTypes(format);
        if (r is null)
            return null;
        else
            return r[0];
    }

    /**
     * Gets the mime types associated with the format.
     *
     * @param stringformat The format
     *
     * @return array The associated mime types
     */
    string[] GetMimeTypes(string format) {
        return _formats.get(format, null);
    }

    /**
     * Gets the format associated with the mime type.
     *
     * @param stringmimeType The associated mime type
     *
     * @return string|null The format (null if not found)
     */
    string GetFormat(string mimeType) {
        string canonicalMimeType = "";
        ptrdiff_t index = indexOf(mimeType, ";");
        if (index >= 0)
            canonicalMimeType = mimeType[0 .. index];
        foreach (string key, string[] value; _formats) {
            if (canFind(value, mimeType))
                return key;
            if (!canonicalMimeType.empty && canFind(canonicalMimeType, mimeType))
                return key;
        }

        return null;
    }

    /**
     * Associates a format with mime types.
     *
     * @param string      format    The format
     * @param string|arraymimeTypes The associated mime types (the preferred one must be the first as it will be used as the content type)
     */
    void SetFormat(string format, string[] mimeTypes) {
        _formats[format] = mimeTypes;
    }

//     /**
//      * Gets the request format.
//      *
//      * Here is the process to determine the format:
//      *
//      *  * format defined by the user (with setRequestFormat())
//      *  * _format request attribute
//      *  *default
//      *
//      * @param stringdefault The default format
//      *
//      * @return string The request format
//      */
//     string getRequestFormat(string defaults = "html") {
//         if (_format.empty)
//             _format = this.mate.get("_format", null);

//         return _format is null ? defaults : _format;
//     }

//     /**
//      * Sets the request format.
//      *
//      * @param stringformat The request format
//      */
//     void setRequestFormat(string format) {
//         _format = format;
//     }

//     protected string _format;

    /**
     * Determine if the current request accepts any content type.
     *
     * @return bool
     */
    @property bool AcceptsAnyContentType() {
        string[] acceptable = getAcceptableContentTypes();

        return acceptable.length == 0 || (acceptable[0] == "*/*" || acceptable[0] == "*");

    }

    /**
     * Determines whether a request accepts JSON.
     *
     * @return bool
     */
    @property bool AcceptsJson() {
        return Accepts(["application/json"]);
    }

    /**
     * Determines whether a request accepts HTML.
     *
     * @return bool
     */
    @property bool AcceptsHtml() {
        return Accepts(["text/html"]);
    }

    /**
     * Get the data format expected in the response.
     *
     * @param  string  defaults
     * @return string 
     */
    string Format(string defaults = "html") {
        string[] acceptTypes = getAcceptableContentTypes();

        foreach (string type; acceptTypes) {
            string r = GetFormat(type);
            if (!r.empty)
                return r;
        }
        return defaults;
    }

    /**
     * Retrieve an old input item.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array
     */
    string[string] Old(string[string] defaults = null)
    {
        return this.HasSession() ? this.Session().getOldInput(defaults) : defaults;
    }

    /**
     * Retrieve an old input item.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string
     */
    string Old(string key, string defaults = null)
    {
        return this.HasSession() ? this.Session().getOldInput(key, defaults) : defaults;
    }

    /**
     * Flash the input for the current request to the session.
     *
     * @return void
     */
    void Flash() {
        if (HasSession())
            _session.flashInput(this.Input());
    }

    /**
     * Flash only some of the input to the session.
     *
     * @param  array|mixed  keys
     * @return void
     */
    void FlashOnly(string[] keys) {
        if (HasSession())
            _session.flashInput(this.Only(keys));

    }

    /**
     * Flash only some of the input to the session.
     *
     * @param  array|mixed  keys
     * @return void
     */
    void FlashExcept(string[] keys) {
        if (HasSession())
            _session.flashInput(this.Only(keys));

    }

    /**
     * Flush all of the old input from the session.
     *
     * @return void
     */
    void Flush() {
        if (_session !is null)
            _sessionStorage.Put(_session);
    }

    /**
     * Gets the HttpSession.
     *
     * @return HttpSession|null The session
     */
    @property HttpSession Session(bool canCreate = true) {
        if (_session !is null || isSessionRetrieved)
            return _session;

        string sessionId = this.cookie(DefaultSessionIdName);
        isSessionRetrieved = true;
        if (!sessionId.empty) {
            _session = _sessionStorage.Get(sessionId);
            if(_session !is null) {
                _session.setMaxInactiveInterval(_sessionStorage.Expire);
                version(HUNT_HTTP_DEBUG) {
                    tracef("session exists: %s, expire: %d", sessionId, _session.getMaxInactiveInterval());
                }
            }
        }

        if (_session is null && canCreate) {
            sessionId = HttpSession.generateSessionId();
            version(HUNT_DEBUG) infof("new session: %s, expire: %d", sessionId, _sessionStorage.Expire);
            _session = HttpSession.create(sessionId, _sessionStorage.Expire);
        }

        return _session;
    }

    private bool isSessionRetrieved = false;

    /**
     * Whether the request contains a HttpSession object.
     *
     * This method does not give any information about the state of the session object,
     * like whether the session is started or not. It is just a way to check if this Request
     * is associated with a HttpSession instance.
     *
     * @return bool true when the Request contains a HttpSession object, false otherwise
     */
    bool HasSession() {
        return Session() !is null;
    }


    /**
     * Set the session instance on the request.
     *
     * @param  HttpSession  session
     * @return void
     */
    void SetSession(HttpSession session)
    {
        _session = session;
    }

    /**
     * Retrieve a server variable from the request.
     *
     * @param  string|null  key
     * @param  string|array|null  default
     * @return string|array|null
     */
    string[] Servers(string key = null, string[] defaults = null) {
       return RetrieveItem(key, defaults);
    }

    string Server(string key = null, string defaults = null) {
       return RetrieveItem(key, defaults);
    }

    /**
     * Determine if a header is set on the request.
     *
     * @param  string key
     * @return bool
     */
    bool HasHeader(string key) {
        return getFields().containsKey(key);
    }

    /**
     * Get the bearer token from the request headers.
     *
     * @return string
     */
    string BearerToken() {
        string v = Header("Authorization");
        if (startsWith(v, BearerTokenHeader)) {
            return v[BearerTokenHeader.length .. $];
        }
        return null;
    }

    /**
     * Get the basic token from the request headers.
     *
     * @return string
     */
    string BasicToken() {
        string v = Header("Authorization");
        if (startsWith(v, BasicTokenHeader)) {
            return v[BasicTokenHeader.length .. $];
        }
        return null;
    }

    /**
     * Determine if the request contains a given input item key.
     *
     * @param  string|array key
     * @return bool
     */
    bool Exists(string key) {
        return Has([key]);
    }

    /**
     * Determine if the request contains a given input item key.
     *
     * @param  string|array  key
     * @return bool
     */
    bool Has(string[] keys) {
        string[string] dict = this.All();
        foreach (string k; keys) {
            string* p = (k in dict);
            if (p is null)
                return false;
        }
        return true;
    }

    /**
     * Determine if the request contains any of the given inputs.
     *
     * @param  dynamic  key
     * @return bool
     */
    bool HasAny(string[] keys...) {
        string[string] dict = this.All();
        foreach (string k; keys) {
            string* p = (k in dict);
            if (p is null)
                return true;
        }
        return false;
    }

    /**
     * Apply the callback if the request contains the given input item key.
     *
     * @param  string key| T callback
     * @return bool
     */
    Request WhenHas(T = string)(string key, void delegate(T) handler) {
        if(Has(key)) {
            T value = get!(T)(key);
            if(handler !is null)
                handler(value);
        }
        return this;
    }

    /**
     * Determine if the request contains a non-empty value for an input item.
     *
     * @param  string|array  key
     * @return bool
     */
    bool Filled(string[] keys) {
        foreach (string k; keys) {
            if (k.empty)
                return false;
        }
        return true;
    }
    /**
     * Determine if the request contains a non-empty value for an input item.
     *
     * @param  string  key
     * @return bool
     */
    bool Filled(string key) {
        return !key.empty;
    }

    /**
     * Determine if the request contains an empty value for an input item.
     *
     * @param  string|array  key
     * @return bool
     */
    bool IsNotFilled(string[] keys) {
        foreach (string k; keys) {
            if (!k.empty)
                return false;
        }

        return true;
    }

    /**
     * Determine if the request contains a non-empty value for any of the given inputs.
     *
     * @param  string|array  key
     * @return bool
     */
    bool AnyFilled(string[] keys) {
        foreach (string k; keys) {
            if (!Filled(k))
                return false;
        }

        return true;
    }

    /**
     * Apply the callback if the request contains a non-empty value for the given input item key.
     *
     * @param  string|array  key
     * @return bool
     */
    T WhenFilled(T = string)(string keys, T callback = T.init){
         if (Filled(keys)) 
            return T;
    }

    /**
     * Determine if the request is missing a given input item key.
     *
     * @param  string|array  key
     * @return bool
     */
    bool Missing(string key)
    {
        return !Has([key]);
    }
    bool Missing(string[] keys)
    {
        return !Has(keys);
    }


    /**
     * Determine if the given input key is an empty string for "has".
     *
     * @param  string  key
     * @return bool
     */
    bool IsEmptyString(string key)
    {
        string value = Input(key);

        return value.empty;
    }

    /**
     * Get the keys for all of the input and files.
     *
     * @return array
     */
    string[] Keys() {
        // return this.Input().keys ~ this.httpForm.fileKeys();
        //implementationMissing(false);
        return this.Input().keys;
    }

    /**
     * Get all of the input and files for the request.
     *
     * @param  array|mixed  keys
     * @return array
     */
    string[string] All(string[] keys = null) {
        string[string] inputs = this.Input();
        if (keys is null) {
            // HttpForm.FormFile[string]  files = this.allFiles;
            // foreach(string k; files.byKey)
            // {
            //     inputs[k] = files[k].fileName;
            // }
            return inputs;
        }

        string[string] results;
        foreach (string k; keys) {
            string* v = (k in inputs);
            if (v !is null)
                results[k] = *v;
        }
        return results;
    }

    /**
     * Retrieve an input item from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array
     */
    string Input(string key, string defaults = null) {
        return GetInputSource().get(key, defaults);
    }

    // ditto
    string[string] Input() {
        return GetInputSource();
    }

    /**
     * Get a subset containing the provided keys with values from the input data.
     *
     * @param  array|mixed  keys
     * @return array
     */
    string[string] Only(string[] keys) {
        string[string] inputs = this.All();
        string[string] results;
        foreach (string k; keys) {
            string* v = (k in inputs);
            if (v !is null)
                results[k] = *v;
        }

        return results;
    }

    /**
     * Get all of the input except for a specified array of items.
     *
     * @param  array|mixed  keys
     * @return array
     */
    string[string] Except(string[] keys) {
        string[string] results = this.All();
        foreach (string k; keys) {
            string* v = (k in results);
            if (v !is null)
                results.remove(k);
        }

        return results;
    }

    /**
     * Retrieve input as a boolean value.
     *
     * Returns true when value is "1", "true", "on", and "yes". Otherwise, returns false.
     *
     * @param  string|null key
     * @param  bool  default
     * @return bool
     */
    bool Boolean(string key, string defaults = null)
    {
        string value = Input(key, defaults);
        return value == "0" || value == "1" || value == "false" || value == "true" || value == "on" || value == "yes";
    }

    /**
     * Retrieve a query string item from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array
     */
    string Query(string key, string defaults = null) {
        return _request.query(key, defaults);
    }

    /**
     * Retrieve a request payload item from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     *
     * @return string|array
     */
    T Post(T = string)(string key, T v = T.init) {
        return _request.post(key, v);
    }

    /**
     * Retrieve a cookie from the request.
     *
     * @param  string  key
     * @param  string  default
     * @return string
     */
    string cookie(string key, string defaultValue = null) {
        return _request.cookie(key, defaultValue);
    }

    /**
     * Determine if a cookie is set on the request.
     *
     * @param  string  key
     * @return bool
     */
    bool HasCookie(string key)
    {
        foreach(Cookie c; _request.getCookies()) {
            if(c.getName == key)
                return true;
        }
        return false;
    }
    bool HasCookie()
    {
        return _request.getCookies().length > 0;
    }


    /*
     * Get an array of all of the files on the request.
     *
     * @return array
     */
    UploadedFile[] AllFiles() {
        checkUploadedFiles();
        return _convertedAllFiles;
    }

    /**
     * Return the Request instance.
     *
     * @return this
     */
    Request Instance()
    {
        return this;
    }

    @property string MethodAsString() {
        return _request.getMethod();
    }
   
    /*
     * Get the request method.
     *
     * @return string
    */
    @property HttpMethod Method() {
        return HttpMethod.fromString(_request.getMethod());
    }

    /**
     * Get the root URL for the application.
     *
     * @return string
     */
    @property string Root()
    {
        string strUrl = format("%s://%s", GetScheme(), _request.host());
        return strUrl;
    }

    /**
     * Get the URL (no query string) for the request.
     *
     * @return string
     */
    @property string Url() {
        return _request.getURIString();
    }

    /**
     * Get the full URL for the request.
     *
     * @return string
     */
    @property string FullUrl()
    {
        string strUrl = format("%s://%s%s", GetScheme(), _request.host(), _request.getURI().toString());
        return strUrl;
    }

    /**
     * Get the full URL for the request with the added query string parameters.
     *
     * @param  string[] strQuery
     * @return string
     */
    string FullUrlWithQuery(string[string] strQuery)
    {
        string strUrl = format("%s://%s%s", GetScheme(), _request.host(), _request.getURI().toString());

        if( strQuery.length > 0 ) 
        {
            strUrl ~= "?";  
            int i = 0;  
            foreach (key, val; strQuery) 
            {
                if(i == 0) {
                    strUrl ~=  key ~ "=" ~ val;        
                }
                else {
                    strUrl ~= "&" ~ key ~ "=" ~ val;           
                }   
                i++;            
            }    
            return strUrl;
        }
        else 
        {
            return strUrl;        
        }
    }

    /**
     * Get the current path info for the request.
     *
     * @return string
     */
    @property string Path() {
        return _request.getURI().getPath();
    }

    /**
     * Get the current decoded path info for the request.
     *
     * @return string
     */
    @property string DecodedPath() {
        return _request.getURI().getDecodedPath();
    }

    /**
     * Gets the request's scheme.
     *
     * @return string
     */
    string GetScheme() {
        return _request.isHttps() ? "https" : "http";
    }

    /**
     * Get a segment from the URI (1 based index).
     *
     * @param  int  index
     * @param  string|null  default
     * @return string|null
     */
    string Segment(int index, string defaults = null) {
        string[] s = Segments();
        if (s.length <= index || index <= 0)
            return defaults;
        return s[index - 1];
    }

    /**
     * Get all of the segments for the request path.
     *
     * @return array
     */
    string[] Segments() {
        string[] t = DecodedPath().split("/");
        string[] r;
        foreach (string v; t) {
            if (!v.empty)
                r ~= v;
        }
        return r;
    }

    /**
     * Determine if the current request URI matches a pattern.
     *
     * @param  patterns
     * @return bool
     */
    bool UriIs(string[] patterns...) {
        string path = DecodedPath();

        foreach (string pattern; patterns) {
            auto s = matchAll(path, regex(pattern));
            if (!s.empty)
                return true;
        }
        return false;
    }

    /**
     * Determine if the route name matches a given pattern.
     *
     * @param  dynamic  patterns
     * @return bool
     */
    bool RouteIs(string[] patterns...) {
        if (_routeItem !is null) {
            string r = _routeItem.path;
            foreach (string pattern; patterns) {
                auto s = matchAll(r, regex(pattern));
                if (!s.empty)
                    return true;
            }
        }
        return false;
    }

    /**
     * Determine if the current request URL and query string matches a pattern.
     *
     * @param  dynamic  patterns
     * @return bool
     */
    bool FullUrlIs(string[] patterns...)
    {
        string r = this.FullUrl();
        foreach (string pattern; patterns)
        {
            auto s = matchAll(r, regex(pattern));
            if (!s.empty)
                return true;
        }

        return false;
    }

    /**
     * Determine if the request is the result of an AJAX call.
     *
     * @return bool
     */
    @property bool Ajax() {
        return getFields().get("X-Requested-With") == "XMLHttpRequest";
    }

    /**
     * Determine if the request is the result of an PJAX call.
     *
     * @return bool
     */
    @property bool Pjax() {
        return getFields().containsKey("X-PJAX");
    }

    /**
     * Determine if the request is the result of a prefetch call.
     *
     * @return bool
     */
    @property bool Prefetch()
    {
        return Header("HTTP_X_MOZ") == "prefetch" || Server("Purpose") == "prefetch";
    }

    /**
     * Determine if the route only responds to HTTPS requests.
     *
     * @return bool
     */
    bool Secure()
    {
        return "https" == GetScheme();
    }

    /**
     * Get the client IP address.
     *
     * @return string
     */
    @property string Ip()
    {
        return getIp();
    }


    /**
     * Get the client user agent.
     *
     * @return string
     */
    @property string UserAgent() {
        return getFields().get("User-Agent");
    }

    /**
     * Retrieve  users' own preferred language.
     */
    string Locale() {
        return _request.locale();
    }

    /**
     * Replace the input for the current request.
     *
     * @param  string[string] param
     *
     * @return Request
     */
    Request Replace(string[string] input) {        
        _request.replace(input);
        return this;
    }

    /**
     * Merge new input into the current request's input array.
     *
     * @param  string[string] param
     *
     * @return Request
     */
    Request Merge(string[string] input) {        
        string[string] inputSource = GetInputSource();
        foreach (string key, string value; input)
        {
            inputSource[key] = value;
        }
        return this;
    }


    /**
     * Get the input source for the request.
     *
     * @param  null
     *
     * @return string[]
     */
    protected string[string] GetInputSource() {
        if (isContained(this.MethodAsString, ["GET", "HEAD"]))
            return queries();
        else {
            string[string] r;
            foreach(string k, string[] v; xFormData()) {
                r[k] = v[0];
            }
            return r;
        }
    }


    /**
     * Get a unique fingerprint for the request / route / IP address.
     *
     * @return string
     */
    string Fingerprint()
    {
        if(_routeItem is null)
            throw new Exception("Unable to generate fingerprint. Route unavailable.");

        string[] r ;
        foreach(size_t key, string m;  _routeItem.methods)
            r ~= m;
        r ~= _routeItem.urlTemplate;
        r ~= this.Ip();

        return toHexString(sha1Of(join(r, "|"))).idup;
    }

    /**
     * Set the JSON payload for the request.
     *
     * @param json
     * @returnthis
     */
    Request SetJson(string[string] json) {
        _json = JSONValue(json);
        return this;
    }

//     /**
//      * Get the user resolver callback.
//      *
//      * @return Closure
//      */
//     Closure getUserResolver() {
//         if (userResolver is null)
//             return (Request) {  };

//         return userResolver;
//     }

//     /**
//      * Set the user resolver callback.
//      *
//      * @param  Closure callback
//      * @returnthis
//      */
//     Request setUserResolver(Closure callback) {
//         userResolver = callback;
//         return this;
//     }

//     /**
//      * Get the route resolver callback.
//      *
//      * @return Closure
//      */
//     Closure getRouteResolver() {
//         if (routeResolver is null)
//             return (Request) {  };

//         return routeResolver;
//     }

//     /**
//      * Set the route resolver callback.
//      *
//      * @param  Closure callback
//      * @returnthis
//      */
//     Request setRouteResolver(Closure callback) {
//         routeResolver = callback;
//         return this;
//     }

    /**
     * Get all of the input and files for the request.
     *
     * @return array
     */
    string[string] ToArray() {
        return this.All();
    }

    /**
     * Determine if the given offset exists.
     *
     * @param  string offset
     * @return bool
     */
    bool OffsetExists(string offset) {
        string[string] a = this.All();
        string* p = (offset in a);

        if (p is null)
            return false; /*_routeItem.hasParameter(offset)*/
        else
            return true;

    }

    /**
     * Get the value at the given offset.
     *
     * @param  string offset
     * @return string
     */
    string OffsetGet(string offset) {
        string[string] dict = this.GetInputSource();
        return dict[offset];
        //return __get(offset);
    }

    /**
     * Set the value at the given offset.
     *
     * @param  string offset
     * @param  mixed value
     * @return void
     */
    void OffsetSet(string offset, string value) {
        string[string] dict = this.GetInputSource();
        dict[offset] = value;
    }

    /**
     * Remove the value at the given offset.
     *
     * @param  string offset
     * @return void
     */
    void OffsetUnset(string offset) {
        string[string] dict = this.GetInputSource();
        dict.remove(offset);
    }

    /**
     * Check if an input element is set on the request.
     *
     * @param  string  key
     * @return bool
     */
    protected bool __IsSet(string key) {
        string v = __Get(key);
        return !v.empty;
    }

    /**
     * Get an input element from the request.
     *
     * @param  string  key
     * @return string
     */
    protected string __Get(string key) {
        string[string] a = this.All();
        string* p = (key in a);

        if (p is null) {
            return "";
        }
        else
            return *p;
    }

    /**
     * Returns the protocol version.
     *
     * If the application is behind a proxy, the protocol version used in the
     * requests between the client and the proxy and between the proxy and the
     * server might be different. This returns the former (from the "Via" header)
     * if the proxy is trusted (see "setTrustedProxies()"), otherwise it returns
     * the latter (from the "SERVER_PROTOCOL" server parameter).
     *
     * @return string
     */
    string GetProtocolVersion() {
        return _request.getHttpVersion().toString();
    }

}


// version(WITH_HUNT_TRACE) {
//     import hunt.trace.Tracer;
// }


private Request _request;

Request request() {
    return _request;
}

void request(Request request) {
    _request = request;
}

HttpSession Session() {
    return request().Session();
}