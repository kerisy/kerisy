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

module kerisy.http.Response;

import kerisy.http.HttpErrorResponseHandler;
import hunt.http.HttpStatus;
import hunt.http.server;
import hunt.io.ByteBuffer;
import hunt.serialization.JsonSerializer;
import hunt.logging.ConsoleLogger;

import std.conv;
import std.json;
import std.range;
import std.traits;

/**
 * 
 */
class Response {
    protected HttpServerResponse _response;
    private bool _bodySet = false;

    this() {
        _response = new HttpServerResponse();
    }

    this(string content) {
        HttpBody hb = HttpBody.create(content);
        this(hb);
    }

    this(HttpBody bodyContent) {
        this(new HttpServerResponse(bodyContent));
    }

    this(HttpServerResponse response) {
        this._response = response;
    }

    HttpServerResponse httpResponse() {
        return _response;
    }

    HttpFields getFields() {
        return _response.getFields();
    }

    /**
     * Get a header from the response.
     *
     * @param  string  header
     * @param  T  value
     * @return Response
     */
    Response Header(T)(string header, T value) {
        getFields().put(header, value);
        return this;
    }

    Response Header(T)(HttpHeader header, T value) {
        getFields().put(header, value);
        return this;
    }

    /**
     * Get the headers from the response.
     *
     * @return Response
     */
    Response Headers(T = string)(T[string] headers) {
        foreach (string k, T v; headers)
            getFields().add(k, v);
        return this;
    }

    Response setRestContent(T)(T content) {
        if(_bodySet) {
            version(HUNT_DEBUG) warning("The body is set again.");
        }

        string contentType = MimeType.APPLICATION_JSON_VALUE;

        static if(is(T : ByteBuffer)) {
            HttpBody hb = HttpBody.create(contentType, content);
        } else static if(isSomeString!T) {
            HttpBody hb = HttpBody.create(contentType, content);
        } else {
            JSONValue js = JsonSerializer.toJson(content);
            string c = js.toString();
            HttpBody hb = HttpBody.create(contentType, c);
        }
        _response.setBody(hb);
        _bodySet = true;
        return this;        
    }

    /**
     * Get the content of the response..
     *
     * @return this
     */
    string Content()
    {
        return  _response.getBody().asString();
    }

    /**
     * Sets the response content.
     *
     * @return this
     */
    Response SetContent(T)(T content, string contentType = MimeType.TEXT_HTML_VALUE) {
        if(_bodySet) {
            version(HUNT_DEBUG) warning("The body is set again.");
        }

        static if(is(T : ByteBuffer)) {
            HttpBody hb = HttpBody.create(contentType, content);
        } else static if(isSomeString!T) {
            HttpBody hb = HttpBody.create(contentType, content);
        } else static if(is(T : K[], K) && is(Unqual!K == ubyte)) {
            HttpBody hb = HttpBody.create(contentType, content);
        } else {
            string c = content.to!string();
            HttpBody hb = HttpBody.create(contentType, c);
        }
        _response.setBody(hb);
        _bodySet = true;
        return this;
    }

    /**
     * Sets the response Html content.
     *
     * @return this
     */
    Response SetHtmlContent(string content) {
        SetContent(content, MimeType.TEXT_HTML_UTF_8.toString());
        return this;
    }

    /**
     * set http status.
     *
     * @return this
     */
    Response SetStatus(int status) {
        _response.setStatus(status);
        return this;
    }

    /**
     * Get the status code for the response.
     *
     * @return int
     */
    int Status() @property {
        return _response.getStatus();
    }

    /**
     * set http Reason.
     *
     * @return this
     */
    Response SetReason(string reason) {
        _response.setReason(reason);
        return this;
    }

    ///download file 
    Response Download(string filename, ubyte[] file, string content_type = "binary/octet-stream") {
        Header(HttpHeader.CONTENT_TYPE, content_type);
        Header(HttpHeader.CONTENT_DISPOSITION,
                "attachment; filename=" ~ filename ~ "; size=" ~ (file.length.to!string));
        SetContent(file);

        return this;
    }

    /**
     * Add a cookie to the response.
     *
     * @param  Cookie cookie
     * @return this
     */
    Response WithCookie(Cookie cookie) {
        _response.withCookie(cookie);
        return this;
    }

    /**
     * Expire a cookie when sending the response.
     *
     * @param  Cookie cookie
     * @param  string|null path
     * @param  string|null domain
     * @return this
     */
    Response WithoutCookie(Cookie cookie, string path = null, string domain = null)
    {
        if(!path.empty){
            cookie.setPath(path);
        }

        if(!domain.empty){
            cookie.setDomain(domain);
        }    

        cookie.setMaxAge(-2628000);

       _response.withCookie(cookie);

        return this;
    }

    /**
     * Determine if the given content should be turned into JSON.
     *
     * @param  mixed  content
     * @return bool
     */
    bool ShouldBeJson(T)(T content)
    {
        return JsonSerializer.toObject(T);
    }

    /**
     * Morph the given content into JSON.
     *
     * @param  mixed  content
     * @return string
     */
    string MorphToJson(T)(T content)
    {
        JSONValue jvalue = parseJSON(content);

        return jvalue;
    }

//     /// the session store implementation.
//     @property HttpSession Session() {
//         return _request.Session();
//     }

//     /// ditto
//     // @property void Session(HttpSession se) {
//     //     _session = se;
//     // }


//     // void redirect(string url, bool is301 = false)
//     // {
//     //     if (_isDone)
//     //         return;

//     //     SetStatus((is301 ? 301 : 302));
//     //     setHeader(HttpHeader.LOCATION, url);

//     //     connectionClose();
//     //     Done();
//     // }

    void Do404(string body_ = "", string contentype = "text/html;charset=UTF-8") {
        DoError(404, body_, contentype);
    }

    void Do403(string body_ = "", string contentype = "text/html;charset=UTF-8") {
        DoError(403, body_, contentype);
    }

    void DoError(ushort code, string body_ = "", string contentype = "text/html;charset=UTF-8") {

        SetStatus(code);
        getFields().put(HttpHeader.CONTENT_TYPE, contentype);
        SetContent(ErrorPageHtml(code, body_));
    }

    void DoError(ushort code, Throwable exception, string contentype = "text/html;charset=UTF-8") {

        SetStatus(code);
        getFields().put(HttpHeader.CONTENT_TYPE, contentype);

        version(HUNT_DEBUG) {
            SetContent(ErrorPageWithStack(code, "<pre>" ~ exception.toString() ~ "/<pre>"));
        } else {
            SetContent(ErrorPageWithStack(code, exception.msg));
        }
    }    

    void SetHttpError(ushort code) {
        this.SetStatus(code);
        this.SetContent(ErrorPageHtml(code));
    }

    
    alias setHeader = Header;
    alias withHeaders = Headers;
    alias withContent = SetContent;
}
