## How To Use

In your Move.toml file, under "[dependencies]" add:

`Utils = { git = "https://github.com/0xnoots/sui-utils.git" subdir = "modules", rev = "master" }`

You can then import packages like `use sui_utils::encode` at the top of your module file.

## Diem Throwback

This module is a classic throwback to the good old days of Diem!

In Diem, you had these crazy powerful global storage operators; you would specify:
`borrow_global<T>(addr)`
which would reach into the specified address and pull out the object T at addr (if it exists).

This operation was subject to the following rules:

1. an address can only possess one T at a time
2. operators can only be used on T from within T's declaring module
3. move_to(address) required a signature from address; all other operators did not

Rule #3 means it was impossible to 'clog up' someone else's storage without their authorization by putting an object T at their address. This also gave modules god-like power over their own resources, in that if they declared T they could grab any T in existence, even without the owner's signature, and do whatever they want, including modifying and destroying T.

In Diem, intra-validator partitioning would have been done by module + module's types.

Sui eliminated these operators. Sui intra-validator partitioning will likely be done based on object-id and child objects of that id. This should make parallelization easier.

## Local Storage Operator

LSO (Local Storage Operator) replicates Diem's old API. Instead of grabbing items from global storage based on address, it grabs items from local storage based on object O's id (address).

It is subject to the following rules:

1. object O can only possess one T at a time
2. caller must have access to the O's UID

Rule #2 means that the caller is either O's declaring module, or O's declaring module exposed some ability for external functions to obtain O's UIDs.

Note that I had to change the function names slightly because the old names are still reserved by the Move VM.
