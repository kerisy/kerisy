module kerisy.http.NotFoundResponse;

import kerisy.http.HttpErrorResponseHandler;
import kerisy.http.Response;
import hunt.http.server;

import std.range;

/**
 * 
 */
class NotFoundResponse : Response {
    this(string content = null) {
        SetStatus(404);

        if (content.empty)
            content = ErrorPageHtml(404);

        SetContent(content, MimeType.TEXT_HTML_VALUE);
    }
}
