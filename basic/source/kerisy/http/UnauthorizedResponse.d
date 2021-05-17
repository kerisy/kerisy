module kerisy.http.UnauthorizedResponse;

import kerisy.http.HttpErrorResponseHandler;
import kerisy.http.Response;
import kerisy.application.Application;
import kerisy.config.ApplicationConfig;
import kerisy.provider.ServiceProvider;
import kerisy.view.View;

import hunt.http.server;

import std.format;
import std.range;

/**
 * 
 */
class UnauthorizedResponse : Response {

    enum int StatusCode = 401;

    this(string content = null, bool isRestful = false, AuthenticationScheme authType = AuthenticationScheme.None) {
        SetStatus(StatusCode);

        if(isRestful) {
            if(!content.empty) SetContent(content, MimeType.APPLICATION_JSON_VALUE);
        } else {
            ApplicationConfig.AuthConf appConfig = app().Config().auth;

            if(authType == AuthenticationScheme.Basic) {
                Header(HttpHeader.WWW_AUTHENTICATE, format("Basic realm=\"%s\"", appConfig.basicRealm));
            }
            
            if (content.empty) {
                content = ErrorPageHtml(StatusCode);
            }

            SetContent(content, MimeType.TEXT_HTML_VALUE);
        }

    }
}
