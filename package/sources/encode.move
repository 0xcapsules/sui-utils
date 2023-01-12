// General purpose functions for converting data types

// Definitions:
// Full-qualified type-name, or just 'type name' for short:
// 0000000000000000000000000000000000000002::devnet_nft::DevNetNFT
// This is <package_id>::<module_name>::<struct_name>
// This does not include the 0x i the package-id
// A 'module address' is just <package_id>::<module_name>

module sui_utils::encode {
    use std::ascii::{Self, String};
    use std::type_name;
    use sui::object::ID;
    use sui_utils::vector2;
    use sui_utils::ascii2;

    // error constants
    const EINVALID_TYPE_NAME: u64 = 0;

    const SUI_ADDRESS_LENGTH: u64 = 20;

    // The string returned is the fully-qualified type name, with no abbreviations or 0x appended to addresses,
    // Examples:
    // 0000000000000000000000000000000000000002::devnet_nft::DevNetNFT
    // 0000000000000000000000000000000000000002::coin::Coin<0000000000000000000000000000000000000002::sui::SUI>
    // 0000000000000000000000000000000000000001::ascii::String
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

        let i = ascii2::index_of(&s1, &delimiter);
        assert!(ascii::length(&s1) > i, EINVALID_TYPE_NAME);

        let s2 = ascii2::sub_string(&s1, i + 2, ascii::length(&s1));
        let j = ascii2::index_of(&s2, &delimiter);
        assert!(ascii::length(&s2) > j, EINVALID_TYPE_NAME);

        // let package_id = ascii2::sub_string(&s1, 0, i);
        // let module_name = ascii2::sub_string(&s2, 0, j);

        let module_addr = ascii2::sub_string(&s1, 0, i + j + 2);
        let struct_name = ascii2::sub_string(&s2, j + 2, ascii::length(&s2));

        (module_addr, struct_name)
    }

    // String must be a module address, such as 0x599::module_name
    public fun decompose_module_addr(s1: String): (String, String) {
        let delimiter = ascii::string(b"::");

        let i = ascii2::index_of(&s1, &delimiter);
        assert!(ascii::length(&s1) > i, EINVALID_TYPE_NAME);

        let package_id = ascii2::sub_string(&s1, 0, i);
        let module_name = ascii2::sub_string(&s1, i + 2, ascii::length(&s1));

        (package_id, module_name)
    }

    public fun package_id<T>(): ID {
        let bytes_full = ascii::into_bytes(type_name<T>());
        // hex doubles the number of characters used
        let bytes = vector2::slice(&bytes_full, 0, SUI_ADDRESS_LENGTH * 2); 
        ascii2::ascii_bytes_into_id(bytes)
    }

    // Returns just the module_name + struct_name, such as coin::Coin<0x599::paul_coin::PaulCoin>,
    // or my_module::CoolStruct
    public fun module_and_struct_names<T>(): String {
        let bytes_full = ascii::into_bytes(type_name<T>());
        vector2::slice_mut(&mut bytes_full, 0, SUI_ADDRESS_LENGTH * 2 + 2);
        ascii::string(bytes_full)
    }

    // Takes the module address of Type T, and appends an arbitrary ascii string to the end of it
    // This creates a fully-qualified address for a struct that may not exist
    public fun append_struct_name<Type>(struct_name: String): String {
        let (module_addr, _) = type_name_<Type>();
        append_struct_name_(module_addr, struct_name)
    }

    public fun append_struct_name_(module_addr: String, struct_name: String): String {
        ascii2::append(&mut module_addr, ascii::string(b"::"));
        ascii2::append(&mut module_addr, struct_name);
        module_addr
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