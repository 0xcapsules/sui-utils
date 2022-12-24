// Cannot change types of value; this will abort if the Value-type of the existing object is wrong. The value top must be droppable

module sui_utils::df_set {
    use sui::object::UID;
    use sui::dynamic_field;

    public fun set<Key: store + copy + drop, Value: store + drop>(id: &mut UID, key: Key, value: Value) {
        if (dynamic_field::exists_(id, key)) {
            dynamic_field::remove<Key, Value>(id, key);
        };

        dynamic_field::add(id, key, value);
    }
}