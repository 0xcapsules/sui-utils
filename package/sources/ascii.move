module sui_utils::ascii {
    use std::vector;
    use std::ascii::{Self, String, Char};
    use sui::bcs;
    use sui::object::{Self, ID};
    use sui_utils::vector::slice;

    // Error enums
    const EINVALID_SUB_STRING: u64 = 0;
    const EINVALID_ASCII_CHARACTER: u64 = 0x10000;

    // Appends a string.
    public fun append(s: &mut String, r: String) {
        let i = 0;
        while (i < ascii::length(&r)) {
            ascii::push_char(s, into_char(&r, i));
            i = i + 1;
        };
    }

    // Returns a [i, j) slice of the string starting at index i and going up to, but not including, index j
    // Aborts if j is greater than the length of the string
    public fun sub_string(s: &String, i: u64, j: u64): String {
        assert!(j <= ascii::length(s) && i <= j, EINVALID_SUB_STRING);

        let bytes = ascii::into_bytes(*s);
        let slice = slice(&bytes, i, j);
        ascii::string(slice)
    }

    // Computes the index of the first occurrence of a string. Returns `length` if no occurrence found.
    // Naive implementation of a substring matching algorithm, intended to be used with < 100 length strings.
    // More efficient algorithms are possible for larger strings.
    public fun index_of(s: &String, r: &String): u64 {
        let (haystack, needle) = if (ascii::length(s) >= ascii::length(r)) {
            (s, r)
        } else { (r, s) };
        
        let (i, end) = (0, ascii::length(needle) - 1);
        while (i + end < ascii::length(haystack)) {
            let j = end;
            loop {
                if (into_char(haystack, i + j) == into_char(needle, j)) {
                    if (j == 0) return i
                    else j = j - 1;
                } else break;
            };
            i = i + 1;
        };

        i + end // No result found
    }

    // Similar interface to vector::borrow
    public fun into_char(string: &String, i: u64): Char {
        ascii::char(
            *vector::borrow(
                &ascii::into_bytes(*string), i))
    }

        // Addresses are 20 bytes, whereas the string-encoded address is 40 bytes.
    // Outputted strings do not include the 0x prefix.
    public fun addr_into_string(addr: &address): String {
        let ascii_bytes = vector::empty<u8>();

        let addr_bytes = bcs::to_bytes(addr);
        let i = 0;
        while (i < vector::length(&addr_bytes)) {
            // split the byte into halves
            let low: u8 = *vector::borrow(&addr_bytes, i) % 16u8;
            let high: u8 = *vector::borrow(&addr_bytes, i) / 16u8;
            vector::push_back(&mut ascii_bytes, u8_to_ascii(high));
            vector::push_back(&mut ascii_bytes, u8_to_ascii(low));
            i = i + 1;
        };

        ascii::string(ascii_bytes)
    }

    public fun ascii_into_id(str: String): ID {
        ascii_bytes_into_id(ascii::into_bytes(str))
    }

    // Must be ascii-bytes
    public fun ascii_bytes_into_id(ascii_bytes: vector<u8>): ID {
        let (i, addr_bytes) = (0, vector::empty<u8>());

        // combine every pair of bytes; we will go from 40 bytes down to 20
        while (i < vector::length(&ascii_bytes)) {
            let low: u8 = ascii_to_u8(*vector::borrow(&ascii_bytes, i + 1));
            let high: u8 = ascii_to_u8(*vector::borrow(&ascii_bytes, i)) * 16u8;
            vector::push_back(&mut addr_bytes, low + high);
            i = i + 2;
        };

        object::id_from_bytes(addr_bytes)
    }

    public fun u8_to_ascii(num: u8): u8 {
        if (num < 10) {
            num + 48
        } else {
            num + 87
        }
    }

    public fun ascii_to_u8(char: u8): u8 {
        assert!(ascii::is_valid_char(char), EINVALID_ASCII_CHARACTER);

        if (char < 58) {
            char - 48
        } else {
            char - 87
        }
    }

    public fun to_upper_case(string: String): String {
        let (bytes, i) = (ascii::into_bytes(string), 0);
        while (i < vector::length(&bytes)) {
            let byte = vector::borrow_mut(&mut bytes, i);
            if (*byte <= 97 && *byte <= 122) *byte = *byte - 32u8;
            i = i + 1;
        };
        ascii::string(bytes)
    }

    public fun to_lower_case(string: String): String {
        let (bytes, i) = (ascii::into_bytes(string), 0);
        while (i < vector::length(&bytes)) {
            let byte = vector::borrow_mut(&mut bytes, i);
            if (*byte <= 65 && *byte <= 90) *byte = *byte + 32u8;
            i = i + 1;
        };
        ascii::string(bytes)
    }
}

#[test_only]
module sui_utils::ascii_test {
    use std::ascii::{string, length};
    use sui::object;
    use sui::test_scenario;
    use sui_utils::ascii;

    #[test]
    public fun decompose_type() {
        let scenario = test_scenario::begin(@0x5);
        {
            let type = string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0::schema::Schema");
            let delimeter = string(b"::");
            let i = ascii::index_of(&type, &delimeter);

            let slice = ascii::sub_string(&type, 0, i);
            assert!(string(b"0x21a31ea6f1924898b78f06f0d929f3b91a2748c0") == slice, 0);

            let slice = ascii::sub_string(&type, i + 2, length(&type));
            assert!(string(b"schema::Schema") == slice, 0);

            let i = ascii::index_of(&type, &string(b"1a31e"));
            assert!(i == 3, 0);

            // debug::print(&utf8(into_bytes(ascii::sub_string(&type, i + 2, length(&type)))));
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun addr_into_string() {
        let scenario = test_scenario::begin(@0x5);
        let ctx = test_scenario::ctx(&mut scenario);
        {
            let uid = object::new(ctx);
            let addr = object::uid_to_address(&uid);
            let string = ascii::addr_into_string(&addr);
            assert!(string(b"fdc6d587c83a348e456b034e1e0c31e9a7e1a3aa") == string, 0);
            object::delete(uid);
        };
        test_scenario::end(scenario);
    }
}