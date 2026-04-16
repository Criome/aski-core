# Sema Engine — Architecture

## Sema Is the Thing

Sema is a universal typed binary format — the canonical
representation. Everything else is a projection.

Aski is one text notation for specifying sema. It leverages
existing text-based programming infrastructure (editors,
compilers, terminals) as a pragmatic bootstrap path. The
world has half a century of tooling for text-formatted
pseudocode — aski rides that infrastructure to get to sema.

Eventually aski will be replaced by better ways to represent
sema for human consumption. askic (the aski compiler) is a
frontend. semac (the sema compiler) is the permanent backend.

```
.aski → askic → .sema → semac → .rs
       frontend        backend
```

Multiple frontends can produce .sema. semac doesn't know
about aski. The boundary between notation and execution is
the .sema file.


## askic — The Aski Frontend

A single self-contained binary. You give it .aski source
files. It produces .sema binary.

Internally, three layers — each a Rust crate:

```
cc      (aski-core crate)  — .aski → Rust types (language anatomy)
askicc  (askicc crate)     — uses cc + .synth → scoped types + dialect structures
askic   (askic crate)      — uses askicc → parser, data-tree builder
```

askic depends on askicc depends on cc. One binary.


### cc — Core Compiler (aski-core crate)

Reads aski-core's .aski anatomy files, emits Rust types.
The minimal bootstrap. Hardcoded Rust parser — replaced by
the engine's own parser when self-hosted.

Produces:
```rust
enum NodeKind { Root, Module, Enum, Struct, Newtype, ... }
enum NameDomain { Type, Variant, Field, Trait, Method, ... }
enum ScopeKind { Root, Module, Enum, Struct, ... }
enum Operator { Add, Sub, Mul, ... }
struct Node { ... }
```

Fixed language types — they describe what aski IS.
Used by both askicc and askic.


### askicc — Bootstrap Compiler (askicc crate)

Does two things at build time:

1. Reads .synth dialect files → structured grammar data
2. Reads askic's .aski source → scoped Rust types

Both compiled into the askic binary. At runtime askic has
no files to read except user programs.

Scoped types use the **enum-as-index** architecture:

**Enums are lookups** — which specific domain?
**Structs are composites** — what does this scope contain?

```rust
enum Modules { Elements(Elements) }

struct Elements {
    Enums: ElementsEnums,
    Structs: ElementsStructs,
    Traits: ElementsTraits,
}

enum ElementsEnums { Element(Element), Quality(Quality) }
enum Element { Fire, Earth, Air, Water }
struct Point { Horizontal: F64, Vertical: F64 }
```

Pattern matching = O(1) jump table. Exhaustive. Zero strings.
The enum IS a static hashmap.


### askic — Compiler (askic crate)

Uses everything above. At runtime reads only user .aski source.

- Its OWN types: compiled enum variants (zero strings)
- USER types: read as strings, generates scoped Rust types
- Produces: .sema binary (the canonical artifact)

Two kinds of knowledge:
- **Schema** (compile-time) — scoped enums from askicc
- **Content** (runtime) — populated data-tree from parsing


## semac — The Sema Backend

Independent of askic. Reads .sema binary, compiles it.

Any tool that produces valid .sema can feed semac.

Produces:
1. **module.rs** — Rust codegen (the compilation target)
2. **module.aski-table.sema** — name projection for tooling

semac is permanent. askic is one frontend that may be replaced.


## .sema — The Interface

The .sema file is the boundary between notation and execution.

- askic produces it (from .aski text)
- semac consumes it (produces executable form)
- Future frontends produce it (from visual editors, protocols, etc.)
- The criome runtime consumes it directly

.sema is pure binary. Domain variants as bytes. rkyv zero-copy,
mmap-ready, deterministic. No strings.

The .aski-table.sema is a name projection — maps domain variants
back to human-readable names. It is NOT part of .sema itself.
It's a separate file for tooling. The .sema file is self-contained.


## Repo Structure

```
aski-core    — .aski anatomy files + cc crate
askicc       — askicc crate + .synth dialect files
askic        — askic crate (the frontend binary)
semac        — semac crate (the backend binary)
sema         — Nix aggregator
aski         — language spec
```

### Nix Build

```
aski-core/flake.nix  — builds cc, runs cc on .aski → Rust types
askicc/flake.nix     — inputs aski-core, builds askicc
askic/flake.nix      — inputs askicc, builds askic
semac/flake.nix      — independent (reads .sema, no askic dependency)
sema/flake.nix       — aggregator, nix flake check runs all
```

Note: semac does NOT depend on askic in the Nix build. It
depends on the .sema format specification, not on the frontend
that produces .sema files.


## Advantages

**Sema survives aski.** When better notations exist, they
produce .sema directly. semac doesn't change. The backend is
permanent.

**Frontend independence.** askic and semac communicate through
.sema binary only. No shared types, no shared libraries, no
coupling. Replace the frontend without touching the backend.

**Self-contained binary.** askic has no runtime dependencies.
One binary, one input format, one output format.

**Zero-cost type system.** Scoped enums are jump tables. The
Rust compiler enforces completeness. No strings in askic's
own types.

**Shape IS meaning.** Generated Rust mirrors aski exactly.
Enum = one-of. Struct = all-of. Newtype = wrapper.

**Each layer makes the next elegant.** cc makes askicc elegant.
askicc makes askic elegant. The complexity is front-loaded.
