## How To Use

In your Move.toml file, under "[dependencies]" add:

`SuiUtils = { git = "https://github.com/0xnoots/sui-utils.git", subdir = "package", rev = "master" }`

You can then import packages like `use sui_utils::encode` at the top of your module file.

## Encode

Super useful module for authority-checking; it can convert Move-types into module addresses, package-ids, and struct-names. This allows functions in Sui Move to figure out what types they're dealing with dynamically at runtime. For example, you can check to see if two types were declared by the same module, or the same package-id.

**Example application:** you tie module-authority over an object to a specific witness struct. You can encode the fully qualified address of this struct, and then recall it at runtime later, and compare it to the witness you've been passed in as an argument; if they're the same, then the module-authority check passes, otherwise it fails and aborts.
