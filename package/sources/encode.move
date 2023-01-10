// General purpose functions for converting data types

// Definitions:
// Full-qualified type-name, or just 'type name' for short:
// 0000000000000000000000000000000000000002::devnet_nft::DevNetNFT
// This is <package_id>::<module_name>::<struct_name>
// This does not include the 0x i the package-id, and they are all utf8 strings.
// A 'module address' is just <package_id>::<module_name>

module sui_utils::encode {
    use std::vector;
    use std::ascii::{Self, String};
    use std::type_name;
    use sui::bcs;
    use sui::object::{Self, ID};
    use sui_utils::vector::slice;
    use sui_utils::ascii as string;

    // error constants
    const EINVALID_TYPE_NAME: u64 = 0;
    const ENOT_ASCII_CHARACTER: u64 = 1;

    // The string returned is the fully-qualified type name, with no abbreviations or 0x appended to addresses,
    // Examples:
    // 0000000000000000000000000000000000000002::devnet_nft::DevNetNFT
    // 0000000000000000000000000000000000000002::coin::Coin<0000000000000000000000000000000000000002::sui::SUI>
    // 0000000000000000000000000000000000000001::string::String
    public fun type_name<T>(): String {
        type_name::into_string(type_name::get<T>())
    }

    // Returns the typename as a module_addr + struct_name tuple
    public fun type_name_<T>(): (String, String) {
        decompose_type_name(type_name<T>())
    }

    // Accepts a full-qualified type-name strings and decomposes them into the tuple:
    // (package-id::module name, struct name).
    // Example:
    // (0000000000000000000000000000000000000002::devnet_nft, DevnetNFT)
    // Aborts if the string does not conform to the `address::module::type` format
    public fun decompose_type_name(s1: String): (String, String) {
        let delimiter = ascii::string(b"::");

        let i = string::index_of(&s1, &delimiter);
        assert!(ascii::length(&s1) > i, EINVALID_TYPE_NAME);

        let s2 = string::sub_string(&s1, i + 2, ascii::length(&s1));
        let j = string::index_of(&s2, &delimiter);
        assert!(ascii::length(&s2) > j, EINVALID_TYPE_NAME);

        // let package_id = string::sub_string(&s1, 0, i);
        // let module_name = string::sub_string(&s2, 0, j);

        let module_addr = string::sub_string(&s1, 0, i + j + 2);
        let struct_name = string::sub_string(&s2, j + 2, ascii::length(&s2));

        (module_addr, struct_name)
    }

    // String must be a module address, such as 0x599::module_name
    public fun decompose_module_addr(s1: String): (String, String) {
        let delimiter = ascii::string(b"::");

        let i = string::index_of(&s1, &delimiter);
        assert!(ascii::length(&s1) > i, EINVALID_TYPE_NAME);

        let package_id = string::sub_string(&s1, 0, i);
        let module_name = string::sub_string(&s1, i + 2, ascii::length(&s1));

        (package_id, module_name)
    }

    public fun package_id<T>(): ID {
        let bytes_full = ascii::into_bytes(type_name<T>());
        let bytes = slice(&bytes_full, 0, 40);
        ascii_bytes_into_id(bytes)
    }

    // Takes the module address of Type T, and appends an arbitrary utf8 string to the end of it
    // This creates a fully-qualified address for a struct that may not exist
    public fun append_struct_name<Type>(struct_name: String): String {
        let (type_name, _) = type_name_<Type>();
        string::append(&mut type_name, ascii::string(b"::"));
        string::append(&mut type_name, struct_name);
        
        type_name
    }

    // =============== ASCII Helpers ===============

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

    public fun ascii_into_id(str: ascii::String): ID {
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
        assert!(ascii::is_valid_char(char), ENOT_ASCII_CHARACTER);

        if (char < 58) {
            char - 48
        } else {
            char - 87
        }
    }

    public fun to_lower_case(string: ascii::String): ascii::String {
        let (bytes, i) = (ascii::into_bytes(string), 0);
        while (i < vector::length(&bytes)) {
            let byte = vector::borrow_mut(&mut bytes, i);
            if (*byte <= 65 && *byte <= 90) *byte = *byte + 32u8;
            i = i + 1;
        };
        ascii::string(bytes)
    }

    // =============== Module Comparison ===============

    public fun is_same_module<Type1, Type2>(): bool {
        let (module1, _) = type_name_<Type1>();
        let (module2, _) = type_name_<Type2>();

        (module1 == module2)
    }

    public fun is_same_module_(type_name1: String, type_name2: String): bool {
        let (module1, _) = decompose_type_name(type_name1);
        let (module2, _) = decompose_type_name(type_name2);

        (module1 == module2)
    }
}

#[test_only]
module sui_utils::encode_test {
    use std::debug;
    use sui::test_scenario;
    use std::ascii;
    use std::string;
    use sui::object;
    use sui::bcs;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui_utils::encode;

    // test failure codes
    const EID_DOES_NOT_MATCH: u64 = 1;

    // bcs bytes != utf8 bytes
    #[test]
    #[expected_failure]
    public fun bcs_is_not_utf8() {
        let scenario = test_scenario::begin(@0x5);
        let ctx = test_scenario::ctx(&mut scenario);
        {
            let uid = object::new(ctx);
            let addr = object::uid_to_address(&uid);
            let addr_string = string::utf8(bcs::to_bytes(&addr));
            debug::print(&addr_string);
            object::delete(uid);
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
            let string = encode::addr_into_string(&addr);
            assert!(ascii::string(b"fdc6d587c83a348e456b034e1e0c31e9a7e1a3aa") == string, 0);
            object::delete(uid);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun decompose_sui_coin_type_name() {
        let scenario = test_scenario::begin(@0x77);
        let _ctx = test_scenario::ctx(&mut scenario);
        {
            let name = encode::type_name<Coin<SUI>>();
            let (module_addr, struct_name) = encode::decompose_type_name(name);
            assert!(ascii::string(b"0000000000000000000000000000000000000002::coin") == module_addr, 0);
            assert!(ascii::string(b"Coin<0000000000000000000000000000000000000002::sui::SUI>") == struct_name, 0);
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun match_modules() {
        let scenario = test_scenario::begin(@0x420);
        let _ctx = test_scenario::ctx(&mut scenario);
        {
            assert!(encode::is_same_module<coin::Coin<SUI>, coin::TreasuryCap<SUI>>(), 0);
            assert!(!encode::is_same_module<bcs::BCS, object::ID>(), 0);
        };
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = encode::EINVALID_TYPE_NAME)]
    public fun invalid_string() {
        let scenario = test_scenario::begin(@0x69);
        {
            let (_addr, _type) = encode::decompose_type_name(ascii::string(b"1234567890"));
        };
        test_scenario::end(scenario);
    }

    #[test]
    public fun package_id_test() {
        let scenario = test_scenario::begin(@0x79);
        let _ctx = test_scenario::ctx(&mut scenario);
        {
            assert!(encode::package_id<Coin<SUI>>() == object::id_from_address(@0x2), EID_DOES_NOT_MATCH);
        };
        test_scenario::end(scenario);
    }
}