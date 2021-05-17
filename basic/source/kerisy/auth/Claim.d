module kerisy.auth.Claim;

import std.variant;

/**
 * 
 */
class Claim {

    private string _type;
    private Variant _value;
    
    this(T)(string type, T value) {
        _type = type;
        static if(is(T == Variant)) {
            _value = value;
        } else {
            _value = Variant(value);
        }
    }

    string Type() {
        return _type;
    }

    Variant Value() {
        return _value;
    }

    override string toString() {
        return _type ~ " => " ~ _value.toString();
    }
}
