# The Sema Engine

Sema is a universal typed binary format. It is the thing.
Everything else exists to serve sema.

Aski is one text notation for specifying sema — a stepping
stone that leverages existing text-based infrastructure.
askic is the aski frontend. semac is the sema backend. They
are independent.

This document describes the aski frontend — the compiler
pipeline that turns .aski source into .sema binary.


## The Stack

```
sema       — the universal typed binary format (the thing)
aski       — one text notation for specifying sema (a frontend)
criome     — the runtime that hosts sema worlds (the endgoal)
```

Sema is the center. Multiple frontends can produce .sema.
Aski is the first frontend. The criome consumes .sema at
runtime. semac compiles .sema to executable form.


## askic — The Aski Frontend

askic is a single self-contained binary. You give it .aski
source files. It produces .sema binary.

Internally, three layers — each a Rust crate, each built from
the previous:

```
cc      (aski-core crate)  — .aski → Rust types (language anatomy)
askicc  (askicc crate)     — uses cc + .synth → scoped types + dialect structures
askic   (askic crate)      — uses askicc → parser, data-tree builder, .sema output
```

askic depends on askicc depends on cc. One binary contains
all three.


## semac — The Sema Backend

semac reads .sema binary and compiles it. Any tool that
produces valid .sema can feed semac.

semac produces:
- Rust source (the current compilation target)
- Name tables (.aski-table.sema — for tooling and display)
- Future: criome runtime artifacts, other targets


## cc — Core Compiler (aski-core crate)

Reads aski-core's .aski anatomy files, emits Rust types.
The minimal bootstrap: turns .aski into compilable Rust.

Hardcoded Rust parser. Replaced by the engine's own parser
when self-hosted.


## askicc — Bootstrap Compiler (askicc crate)

Uses cc's types. Reads .synth dialect files → structured
grammar data. Reads askic's .aski source → scoped Rust types
(enum-as-index architecture). Both are build-time inputs
compiled into the askic binary.

Makes askic elegant by front-loading type generation and
grammar processing into generated code.


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


## Node Architecture

The data-tree uses typed nodes. Each synth rule that produces
a parse node corresponds to one NodeKind variant. The variant
IS the identity — not a string.

Every syntactic nesting level creates a scope. Name resolution
walks up from the current scope through ancestors. Recursive
nesting via (| |) and {| |} creates arbitrarily deep scope
chains.

Nodes hold:
- Kind — NodeKind enum (derived from synth)
- Name — NameRef (which name classification + resolved scope)
- Children — recursive node tree
- Span — source position (start, end)
- Value — optional literal value

No strings. No i64 IDs. No parent pointers. No global counters.
Direct tree structure.


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
- askic is a frontend. semac is the backend. They are independent.
- Domains come from .aski data. Rust types are derived.
- DialectKind comes from .synth filenames.
- No strings in sema. Domain variants ARE the bytes.
- No newline significance in any aski-family language.
- .aski defines data, Rust implements behavior in the bootstrap.
  Self-hosted: aski defines both, still targets Rust.
- Each repo is its own crate, its own flake, its own stage.
- The sema repo is the Nix authority. `nix flake check` is truth.
