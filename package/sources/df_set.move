// Cannot change types of value; this will abort if the Value-type of the existing object is wrong. The value top must be droppable

module sui_utils::df_set {
    use sui::object::UID;
    use sui::dynamic_field;

    public fun set<Key: store + copy + drop, Value: store + drop>(uid: &mut UID, key: Key, value: Value) {
        drop<Key, Value>(uid, key);
        dynamic_field::add(uid, key, value);
    }

    public fun drop<Key: store + copy + drop, Value: store + drop>(uid: &mut UID, key: Key) {
        if (dynamic_field::exists_(uid, key)) {
            dynamic_field::remove<Key, Value>(uid, key);
        };
    }
}