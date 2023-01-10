module sui_utils::ascii {
    use std::vector;
    use std::ascii::{Self, String, Char};
    use sui_utils::vector::slice;

    // Error enums
    const EINVALID_SUB_STRING: u64 = 0;

    // Appends a string.
    public fun append(s: &mut String, r: String) {
        let i = 0;
        while (i < ascii::length(&r)) {
            ascii::push_char(s, borrow(&r, i));
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
                if (borrow(haystack, i + j) == borrow(needle, j)) {
                    if (j == 0) return i
                    else j = j - 1;
                } else break;
            };
            i = i + 1;
        };

        i + end // No result found
    }

    // Similar interface to vector::borrow
    public fun borrow(string: &String, i: u64): Char {
        ascii::char(
            *vector::borrow(
                &ascii::into_bytes(*string), i))
    }
}

#[test_only]
module sui_utils::ascii_test {
    use std::ascii::{string, length};
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
}