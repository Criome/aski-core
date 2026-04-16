# The Sema Engine

Sema is a universal typed binary format. It is the thing.
No strings. No unsized data. Domain variants as bytes.
Everything else exists to serve sema.

**Only semac produces sema.** Everything upstream produces
rkyv-serialized data. If it has unsized data, it is not sema.

Aski is one text notation for specifying sema — a stepping
stone that leverages existing text-based infrastructure.


## The Stack

```
sema       — the universal typed binary format (the thing)
aski       — one text notation for specifying sema (a frontend)
criome     — the runtime that hosts sema worlds (the endgoal)
```


## The Pipeline

```
corec     — .aski → Rust with rkyv derives (the bootstrap tool)
aski-core — grammar .aski + corec → Rust rkyv types (askicc↔askic contract)
sema-core — parse tree .aski + corec → Rust rkyv types (askic↔semac contract)
askicc    — uses aski-core types → rkyv dialect-data-tree (embedded in askic)
askic     — uses aski-core (input) + sema-core (output), embeds askicc's rkyv
semac     — uses sema-core types only, independent of aski
```

Six repos. They communicate through files.
Only corec and semac generate Rust. Only semac produces true
sema. Everything between them is rkyv domain-data-trees.


## The Two rkyv Contracts

**aski-core** defines every type that appears in the rkyv
message between askicc and askic. corec generates Rust with
rkyv derives from the .aski definitions. Both askicc
(serializer) and askic (deserializer) depend on corec's output.

This includes classification types (NameDomain, ScopeKind),
structure types (Span), and grammar types (Dialect, Rule,
Item, DelimKind, Cardinality, DialectKind).

**sema-core** defines every type that appears in the rkyv
message between askic and semac. corec generates Rust with
rkyv derives from the .aski definitions. askic (serializer)
and semac (deserializer) depend on corec's output. semac does
NOT depend on aski-core.

This includes parse tree types — the structured output that
askic produces from user .aski source.


## corec — The Bootstrap Tool

A binary that reads .aski files and generates Rust types with
rkyv derives. The bootstrap seed — one of only two tools that
generate Rust. Used by both aski-core and sema-core.

Hardcoded Rust parser. Replaced by the engine's own parser
when self-hosted.


## askicc — Bootstrap Compiler

A binary that reads .synth dialect files, populates a
domain-data-tree using aski-core's corec-generated types, and
serializes it as rkyv. This rkyv data gets embedded in the
askic binary at build time, giving askic the ability to read
that version of aski's grammar.

**askicc does NOT generate Rust.** It produces rkyv data.
The domain-data-tree IS the state machine that drives
askic's parser.


## askic — The Aski Frontend

A binary that reads .aski source and produces an rkyv parse
tree. askic contains NO language-specific parsing logic.
It is a generic dialect engine.

askicc's rkyv domain-data-tree is embedded in askic at build
time. askic deserializes it using the same corec-generated
aski-core types that askicc used to serialize it — aski-core
is the input contract. askic serializes its parse tree output
using sema-core types — the contract that semac reads. The
engine executes the embedded grammar as a dialect-based state
machine against the token stream.

Adding new syntax = adding .aski definitions in aski-core +
.synth files in askicc, then rebuilding. No askic code changes.

askic's output is rkyv — it has strings (user names,
literals). It is NOT sema.


## semac — The Sema Backend

A binary that reads rkyv parse trees using sema-core types
and produces true sema + Rust source. Independent of askic
and aski-core — depends only on sema-core.

semac produces:
- True sema binary (no strings, fixed-size)
- Rust source (the current compilation target)
- Name tables (.aski-table.sema — for tooling and display)

This is where strings become domain variants. This is where
unsized data becomes fixed-size. This is where rkyv becomes
sema.


## The Dialect Tree

Synth dialects nest hierarchically. Each dialect defines what
constructs appear inside it.

```
Root
├── (Module)        → Module
├── (Enum)          → Enum → variants (bare, data, struct)
│                              → (| |) nested enum
│                              → {| |} nested struct
│                              → [] type application
├── (traitDecl)     → TraitDecl → [signatures] → Signature → Param, Type
├── [traitImpl]     → TraitImpl → Type [TypeImpl] → Method
│                                                    ├── Param, Type
│                                                    ├── Body → Statement
│                                                    │          ├── Loop → Statement
│                                                    │          ├── Instance (@)
│                                                    │          ├── Mutation (~@)
│                                                    │          └── Expr (engine)
│                                                    ├── Match → Pattern
│                                                    └── Expr (engine)
├── {Struct}        → Struct → (Field Type), bare self-typed
│                              → (| |) nested enum
│                              → {| |} nested struct
├── {| Const |}     → inline: Type @Value
├── (| Ffi |)       → Ffi → Signature → Param, Type
├── [| Process |]   → Body → Statement
└── Newtype         → (bare) PascalCase followed by Type
```


## Synth IS the Grammar

PascalCase .synth dialect files define aski's entire syntax.
Each file's name is its DialectKind variant. The root dialect
(Root.synth) is order-derived: the first () is always the module.

Synth is part of the aski language family. No newline significance.
Whitespace is only a token separator. `//` is the "or" operator
within synth. Space in synth rules is significant — see synth.md.


## Delimiters Are Context-Dependent

At root level:
- `()`     — Module (first, required), Enum, TraitDecl
- `[]`     — TraitImpl
- `{}`     — Struct
- `{| |}`  — Const
- `(| |)`  — FFI
- `[| |]`  — Process

In body context:
- `()`     — Local type declaration
- `[]`     — Block, InlineEval
- `{}`     — StructConstruct
- `[| |]`  — Loop
- `{| |}`  — Iteration
- `(| |)`  — Match

In definitions (recursive nesting):
- `()`     — Typed field (inside struct)
- `[]`     — Type application (everywhere)
- `(| |)`  — Nested enum (inside domain/struct)
- `{| |}`  — Nested struct (inside domain/struct)

See delimiter-budget.md for the complete per-dialect allocation.


## Research Foundations

**Green/red trees (Roslyn):** Immutable green nodes, bottom-up,
content-addressable. On-demand red facades for traversal.

**Tree-sitter:** Grammar defines node types. Auto-generates
schemas. This is what synth does.

**Nanopass:** Each compiler stage is a formally specified
language. Each synth dialect IS a language.

**Content-addressed trees (Unison):** Node identity from
hash of kind + children. Connects to arbor.

**Datalog (CodeQL):** AST as relations. Flat vectors indexed
by variants. This is what sema does.


## Principles

- Sema is the thing. Aski is one way to specify it.
- Only semac produces sema. Everything else is rkyv.
- Six repos. Only corec and semac generate Rust.
- askicc produces rkyv domain-data-trees, not Rust code.
- askic is a generic dialect engine with no language knowledge.
- askicc's rkyv data is embedded in askic at build time.
- aski-core is the rkyv contract for askicc ↔ askic.
- sema-core is the rkyv contract for askic ↔ semac.
- semac depends only on sema-core, not aski-core.
- Domains come from .aski data. Rust types are derived by corec.
- DialectKind comes from .synth filenames.
- No strings in sema. Domain variants ARE the bytes.
- No free functions — methods on types. main is the exception.
- No newline significance in any aski-family language.
- Each repo is its own flake, its own stage.
- The sema repo is the Nix authority. `nix flake check` is truth.
