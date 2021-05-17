module kerisy.http.RedirectResponse;

import kerisy.http.Response;

import hunt.Exceptions;
import hunt.http.server;
import hunt.logging.ConsoleLogger;


import std.conv;
import std.datetime;
import std.json;


// import kerisy.util.String;
// import kerisy.Version;
// import kerisy.http.Response;
import kerisy.http.Request;
// import kerisy.http.session;
// import kerisy.Exceptions;

/**
 * RedirectResponse represents an HTTP response doing a redirect.
 *
 */
class RedirectResponse : Response {

    private Request _request;

    // this(string targetUrl, bool use301 = false) {
    //     SetStatus((use301 ? 301 : 302));
    //     Header(HttpHeader.LOCATION, targetUrl);
    //     // connectionClose();
    // }

    this(Request request, string targetUrl, bool use301 = false) {
        // super(request());
        super();
        _request = request;

        SetStatus((use301 ? 301 : 302));
        Header(HttpHeader.LOCATION, targetUrl);
        // connectionClose();
    }

    private HttpSession Session() {
        return _request.Session();
    }

    /**
     * Flash a piece of data to the session.
     *
     * @param  string|array  key
     * @param  mixed  value
     * @return RedirectResponse
     */
    RedirectResponse WithSession(string key, string value) {
        Session.flash(key, value);
        return this;
    }

    /// ditto
    RedirectResponse WithSession(string[string] sessions) {
        foreach (string key, string value; sessions) {
            Session.flash(key, value);
        }
        return this;
    }

    /**
     * Get the request instance.
     *
     * @return \Kerisy\Http\Request|null
     */
   Request GetRequest()
    {
        return _request;
    }

    /**
     * Set the request instance.
     *
     * @param  \Kerisy\Http\Request  request
     * @return void
     */
    void SetRequest(Request request)
    {
        _request = request;
    }

    /**
     * Flash an array of input to the session.
     *
     * @param  array  input
     * @return this
     */
    RedirectResponse WithInput(string[string] input = null) {
        Session.flashInput(input is null ? _request.Input() : input);
        return this;
    }

    /**
     * Remove all uploaded files form the given input array.
     *
     * @param  array  input
     * @return array
     */
    // protected string[string] removeFilesFromInput(string[string] input)
    // {
    //     throw new NotImplementedException("removeFilesFromInput");
    // }

    /**
     * Flash an array of input to the session.
     *
     * @return this
     */
    RedirectResponse OnlyInput(string[] keys...)
    {
        return WithInput(_request.Only(keys));
    }

    /**
     * Flash an array of input to the session.
     *
     * @return this
     */
    RedirectResponse ExceptInput(string[] keys...)
    {
        return WithInput(_request.Except(keys));
    }

    /**
     * Get the original response content.
     *
     * @return null
     */
    // override const(ubyte)[] getOriginalContent()
    // {
    //     return null;
    // }
}
