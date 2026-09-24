# rustler_stored_term

When you implement a NIF (Natively Implemented Function) for Elixir/Erlang using Rust,
you might at some point come across the situation where you want to persist Elixir/Erlang terms across multiple NIF calls.

For instance, you might want to store a bunch of them in a vector or some other collection for later use.

However, this is not easy to do in the general case: If you know for certain that a term passed to a NIF is e.g. a small integer or a string, you can convert it to that particular datatype. But many datatypes (functions, references, ports, big integers, etc.) can _not_ safely be converted on the Rust side at all.
And the terms passed to any individual NIF call are limited by their lifetime to this particular call.

This library allows to keep them longer, by converting them to a stable format.
'Known' datatypes are converted to simple Rust equivalents, and the rest is handled by copying the term to a Rustler `OwnedEnv` (c.f. `TermBox`).

Conversion between `Term`s and `StoredTerm`s is very simple, as it implements Rustlers' `Encoder/Decoder` traits.
