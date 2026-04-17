# Aski Design — Established Constraints

These are settled design decisions. They are not open for
reconsideration. New syntax, new dialects, and new engine work
must conform to all of them.


## Sema Is the Thing

Sema is a universal typed binary format. It IS the thing.
No strings. No unsized data. Domain variants as bytes.
Everything else exists to serve sema.

**Only semac produces sema.** Everything upstream (askicc,
askic) produces rkyv-serialized data that still has strings.
It becomes sema when semac resolves all strings to domain
variants. If it has unsized data, it is not sema.

Aski is one notation for specifying sema — a text-based,
human-readable stepping stone. Aski will eventually be replaced
by better ways to represent sema for human consumption.

semac (the sema compiler) is the permanent backend. It reads
rkyv data and produces sema + Rust. Any tool that produces
valid rkyv parse trees can feed semac.

The criome is the endgoal — the runtime that hosts sema worlds.

Do not treat aski as the center of the system. Sema is the
center. Aski is one path to it.


## Domain = Any Data Definition

A **domain** is the overarching concept for any data definition.
Enum, struct, and newtype are three forms of domain:

- **Enum** `()` — one-of. `(Element Fire Earth Air Water)`
- **Struct** `{}` — all-of. `{Point (Horizontal F64) (Vertical F64)}`
- **Newtype** bare — wraps one type. `Counter U32`

The delimiter determines the form. All three are domains.
Enums and structs are two sides of the same thing — the two
shapes that composed data takes.

The enum form specifically is called "enum."


## Everything Is a Type

There are no variables in aski. What other languages call a
"variable declaration" is a **type instance declaration**.

`@Counter U32/new(0)` declares a newtype domain `Counter`
wrapping a `U32` instance. The `@` sigil means "this is a
thing now" — it brings a type into existence and creates an
instance of it.

`@Counter` is PascalCase because it is a THING, not an action.
PascalCase = types, enums, structs, modules, variants, fields.
camelCase = traits, methods. There is no camelCase after `@`.


## Names Are Meaningful

There are no pointer names. No `T`, `X`, `A`, `B`. Every name
describes what the thing IS.

Type parameters use the `$` sigil. The name after `$` is the
semantic identity of the parameter:

- `$Value` — the broadest category of what something contains
- `$Output` — what a computation produces
- `$Failure` — what goes wrong
- `$Clone&Debug` — the bounds ARE the name

Two different things always have different names. `$LeftValue`
and `$RightValue` are different even if they share qualities.


## Delimiter-First

Aski uses six delimiter pairs. The opening delimiter comes first,
then position derives meaning. There are no keywords.

Type application uses `[]`:

```aski
[Vec Element]               ;; not Vec<Element>
[Option $Value]             ;; not Option<T>
[Result $Output $Failure]   ;; not Result<T, E>
```

`<>` is NOT an aski delimiter. It appears only in synth files
as dialect references (`<Type>`, `<Body>`), which are parser
instructions, not source syntax.


## Position Defines Meaning

The same delimiter means different things in different contexts.
Synth dialects define what each position means. There are no
keywords or special tokens to disambiguate — the dialect's
parse position is the sole authority.

`()` at root level = enum or module declaration.
`()` inside a struct = typed field.
`()` inside a body = arguments.

The parser always knows which dialect is active, so there is
never ambiguity.


## No Newline Significance

Newlines are never significant in any aski-family language
(aski, synth, nexus, and any future members). Whitespace
(including newlines) is only a token separator. Parsing is
purely token-based.


## Synth Drives Parsing

Every syntactic construct is defined by a synth dialect. If
something is "handled by the engine" rather than by a synth
rule, that is a design flaw to be fixed.


## No Opaque Strings

Every value in the data-tree is structured. If a name or type
is stored as a flat string, that is a bug. Names are typed
domain variants. Types are structured node trees.

In sema, string fields are transitional — every string is a
placeholder for a domain composition not yet specified. As the
ontology grows, strings collapse to domain variants.


## Scopes Are a Tree

Names live in a scope tree, not a flat global registry. Every
syntactic nesting level (module, enum, struct, method, block,
match arm, loop) creates a scope. The same name in different
scopes = different things.

Recursive nesting (`(| |)` for nested enums, `{| |}` for
nested structs) creates arbitrarily deep scope chains. Name
resolution walks up from the current scope toward root. First
match wins (shadowing).

Nested type declarations can shadow outer names. An inner
`State` inside `Engine` is a different type from an outer
`State` — the scope tree distinguishes them. Access the inner
one through the parent: `Engine.State`.

Exports only reference names declared at the module's own
scope level. A name buried inside a nested definition is not
directly exportable — it is reachable through its parent.

In bodies, `@Name` resolves against the scope chain. If the
name exists in an ancestor scope, `@Name` is an instance of
that existing type. If it doesn't exist, `@Name` declares a
new local type. Shadowing via `@` is not possible — use a
different name.


## Domains Come From Data

Writing an enum or struct by hand in Rust instead of defining
it in `.aski` is always wrong. The `.aski` definition IS the
source of truth. The bootstrap compiler derives all types from
the data — they are never hand-maintained.

DialectKind is derived from `.synth` filenames (PascalCase
files = variants). NodeKind variants map to synth rules.
Name classification is defined in `core/name.aski`.


## PascalCase and camelCase

PascalCase = things. Types, enums, structs, modules,
variants, fields, type parameters, instances.

camelCase = actions. Traits, methods.

This is not convention — it is syntax. The parser distinguishes
PascalCase from camelCase tokens and dispatches differently.


## Mutable Is Marked

`~` marks mutability. `~@Counter` is a mutable instance.
`~@Self` is a mutable borrow of self. Immutability is the
default. Mutation is always visible at the declaration site.


## We Compile to Rust

Aski compiles to Rust via sema. Do not design constructs that
Rust cannot express. No higher-kinded types. No dependent types
(yet). The bootstrap engine is Rust. The self-hosted engine
will be written in aski but still compiles to Rust — Rust is
the compilation target, not the implementation language.


## Instances Are Owned

Once `@Name` declares a type instance, that name is owned in
its scope and cannot be re-declared. If you need a new value,
declare a new name. `@Name` is a one-shot commitment.

This aligns with move-by-default semantics. An instance
declaration is not an assignment — it is the creation of a
thing. Things don't get replaced; new things are created.


## Data-Tree IS the Parser State

Synth files define patterns — what tokens to match. Nothing
more. The data-tree built by askicc IS the parsing state
machine. When the parser encounters ambiguity, the answer
comes from the data-tree's context, not from grammar
complexity.


## No Shortcuts in Compiler Work

Never propose raw text passthrough, "skip for now" stubs,
post-processing scripts, or partial grammars. Self-hosting
requires the full grammar — the same grammar that parses also
reconstructs (bidirectional). Shortcuts break round-tripping
from sema.

When hitting a language limitation, stop and discuss the
language construct needed. Don't work around it — extend the
language properly.


## No Hand-Maintained Lists

Every list of names, enum variants, or dispatch tables in
source code is a bug. If a domain changes, hand lists silently
break. Types are derived from .aski data, never hand-written.


## Pure Binary Means Pure Binary

When the project says "binary," it means actual byte values.
Not hex strings. Not JSON arrays of integers. Not text
representations of any kind. The bytes ARE the protocol.


## Module Names Drop the -aski Suffix

Repo name minus `-aski` suffix = module name. `astro-aski` →
module `astro`. The `-aski` suffix says what language the repo
is written in, not what it's about.


## Astrology, Not Astronomy

The astrological types (Sign, Planet, House, Dignity) come
from astrological tradition — Hellenistic, Vedic, medieval.
Never use "astronomical" to describe these. The traditions are
Ptolemy, Valens, Brennan, Lilly — astrologers, not astronomers.


## Validate Terms Against the Ontology

Before introducing a new term or concept, check it against the
current project ontology. Don't port old terminology without
verifying it's still active. When in doubt, use "Criome" as
the universal framing term, not "Sema" or "Sajban."


## .sema Is the Canonical Format

`.sema` binary is the canonical representation. Everything else
is a projection. .aski is a text projection. .rs is a code
projection. .aski-table.sema is a name projection.

The pipeline:
```
corec     — .aski → Rust with rkyv derives (the bootstrap tool)
aski-core — grammar .aski + corec → Rust rkyv types (askicc↔askic contract)
aski — parse tree .aski + corec → Rust rkyv types (askic↔semac contract)
askicc    — uses aski-core types → rkyv dialect-data-tree (embedded in askic)
askic     — uses aski-core (input) + aski (output), embeds askicc's rkyv
semac     — uses aski types only, independent of aski
```

Six repos. Only corec and semac generate Rust.
Only semac produces true sema. Everything between them is
rkyv-serialized domain-data-trees.


## The Two rkyv Contracts

**aski-core** defines every type that appears in the rkyv message
between askicc and askic. corec generates Rust with rkyv derives
from the .aski definitions. Both askicc (serializer) and askic
(deserializer) depend on corec's output from aski-core.

**aski** defines every type that appears in the rkyv message
between askic and semac. corec generates Rust with rkyv derives
from aski's .aski definitions. askic (serializer) and semac
(deserializer) depend on corec's output from aski. semac
does NOT depend on aski-core.


## No Generated Rust Outside corec and semac

Only two places in the pipeline generate Rust source code:
- **corec** — generates Rust with rkyv derives from .aski
- **semac** — the permanent backend, turns sema into Rust

askicc does NOT generate Rust. It produces rkyv data that
gets embedded in the askic binary at build time.


## No Free Functions

All Rust in the sema ecosystem uses methods on types (traits
+ impls). No free functions. `main` is the only exception.

All Rust will eventually be rewritten in aski, which uses
methods (traits, impls). Free functions have no aski equivalent.
