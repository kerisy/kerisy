module kerisy.auth.UserService;

import kerisy.auth.UserDetails;

/**
 * 
 */
interface UserService {

    UserDetails Authenticate(string name, string password);

    // deprecated("This method will be removed in next release.")
    string GetSalt(string name, string password);

    UserDetails GetByName(string name);

    // deprecated("This method will be removed in next release.")
    UserDetails GetById(ulong id);
}