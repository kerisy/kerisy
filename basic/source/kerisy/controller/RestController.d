
module kerisy.controller.RestController;

import kerisy.controller.Controller;
import kerisy.http.Request;

/**
 * 
 */
class RestController : Controller {

    override Request request() {
        return CreateRequest(true);
    }

    override protected void HandleAuthResponse() {
        // do nothing
    }

}