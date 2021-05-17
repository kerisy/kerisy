module kerisy.http.JsonResponse;

import kerisy.http.Response;

import std.conv;
import std.datetime;
import std.json;

import hunt.logging.ConsoleLogger;
import hunt.serialization.JsonSerializer;
import hunt.util.MimeType;

// import kerisy.http.cookie;
// import kerisy.util.String;
// import kerisy.Version;
// import kerisy.http.Request;

// import hunt.http.codec.http.model.HttpHeader;


/**
 * Response represents an HTTP response in JSON format.
 *
 * Note that this class does not force the returned JSON content to be an
 * object. It is however recommended that you do return an object as it
 * protects yourself against XSSI and JSON-JavaScript Hijacking.
 *
 * @see https://www.owasp.org/index.php/OWASP_AJAX_Security_Guidelines#Always_return_JSON_with_an_Object_on_the_outside
 *
 */
class JsonResponse : Response {
    
    this() {
        super();
    }

    this(T)(T data) {
        super();
        this.SetJson(data.toJson());
    }

    /**
     * Get the json_decoded data from the response.
     *
     * @return JSONValue
     */
    // JSONValue getData()
    // {
    //     return parseJSON(getContent());
    // }

    /**
     * Sets a raw string containing a JSON document to be sent.
     *
     * @param string data
     *
     * @return this
     */
    JsonResponse SetJson(JSONValue data) {
        this.SetContent(data.toString(), MimeType.APPLICATION_JSON_UTF_8.toString());
        return this;
    }
}
