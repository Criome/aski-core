# Sema Pipeline — Backend Architecture

## The Problem

askic produces rkyv-serialized sema-core types. These contain
Strings (TypeName("Element"), FieldName("Horizontal"), etc.).
True sema has NO strings — every value is a fixed-size domain
variant. The backend must:

1. Resolve strings to domain indices (lowering)
2. Generate Rust source from the resolved tree (codegen)
3. Reconstruct aski text from sema (deparse)

Each transformation has ONE input and ONE output. This
constrains agents to implement correctly — no shortcuts.


## What askic Outputs (NOT sema)

~56 String-bearing field positions across sema-core types:
- TypeName(String) — ~30 occurrences (types, instances, modules, params, etc.)
- VariantName(String) — ~8 occurrences
- FieldName(String) — ~5 occurrences
- MethodName(String) — ~6 occurrences
- TraitName(String) — ~5 occurrences
- TypeParamName(String) — ~2 occurrences
- Bare String — 3 (string literals)

A typical module produces 200-400 String instances.
All unsized. All heap-allocated. NOT sema.


## What Pure Sema Looks Like

Every String becomes a u32 index into a domain-specific
name table:

```
// Current (rkyv, not sema):
EnumDef { name: TypeName("Element"), ... }
EnumChild::Variant { name: VariantName("Fire"), ... }

// Pure sema:
EnumDef { name: TypeName(0), ... }
EnumChild::Variant { name: VariantName(0), ... }
```

The string "Element" lives ONLY in the .aski-table.sema
name projection file — a separate artifact for tooling.
The .sema binary itself has zero strings.


## The Lowering Is NOT Mechanical

Resolving strings to indices requires semantic analysis:

**Scope resolution** — "State" in `Engine.State` and
`Parser.State` are different types. A flat intern would
give them the same index.

**TypeName is overloaded** — TypeName(String) is used for
type names, instance names, module paths, parameter names,
constant names, FFI library names. Each belongs to a
different domain.

**Import resolution** — `[Core ParseState Token]` means
knowing what `Core` exports and mapping those names.

**Bare variant resolution** — `Fire` without a type path
requires inferring which enum it belongs to from context.

This is real compiler work — scope trees, type checking,
import graphs. Not a string-replace pass.


## Proposed Pipeline: Two New Binaries

```
askic    → rkyv parse tree (sema-core::tree types, has strings)
              ↓
semac    → .sema (pure binary, no strings) + .aski-table.sema (name projection)
              ↓
rsc      → .rs (Rust source)
```

### semac — The Lowerer

Input: rkyv parse tree (sema-core types)
Output: .sema binary + .aski-table.sema

This is the core transformation. semac:
1. Builds scope tree from the parse tree
2. Resolves all names against scopes
3. Assigns domain-specific indices
4. Serializes the string-free domain tree as .sema
5. Serializes the name table as .aski-table.sema

semac IS the sema producer. It's the permanent backend.

### rsc — The Rust Projector

Input: .sema + .aski-table.sema
Output: .rs file

A pure projection. Reads resolved sema types and emits
Rust text mechanically. No semantic analysis — semac
already did that. Each sema domain variant maps to exactly
one Rust codegen pattern.


## Deferred: askid — The Aski Deparser

Input: .sema + .aski-table.sema + dialect data (from askicc)
Output: .aski text files

Reconstructs canonical aski text from sema. The synth
grammar is bidirectional by design constraint:

> Self-hosting requires the full grammar — the same grammar
> that parses also reconstructs. (design.md)

Each synth rule defines both parse direction (tokens → tree)
and emit direction (tree → tokens). Sequential rules emit
fields in order. Ordered choice rules use the variant to
select which alternative to emit.

askid depends on aski-core (for dialect data) because it IS
an aski tool — it emits aski text. This is justified.

Deferred because:
- The deparse-from-sema problem is harder than deparse-from-parse-tree
- The v015 deparse operated on parse trees, not sema
- We can deparse from askic's rkyv output directly as a simpler first step


## Contract Types

sema-core grows to contain TWO modules:

### sema-core::tree (existing)
The parse tree types. Has strings. Used by:
- askic (serializer)
- semac (deserializer)

### sema-core::sema (new)
The pure sema types. No strings — u32 indices only. Used by:
- semac (serializer)
- rsc (deserializer)
- askid (deserializer, future)

Plus a name table type:
- AskiNameTable — maps domain indices back to display strings
- Produced by semac, consumed by rsc and askid


## Why Not One Binary

The v015 archive had one binary with 14 files and ~4100 lines.
Lowering (648 lines) and codegen (606 lines) were tangled —
codegen directly accessed the name interner and sema types
simultaneously. Impossible to verify codegen independently.

Separate binaries enforce the contract. semac's output is
the ONLY thing rsc reads. No leaking internal state. No
shortcuts. The nix pipeline verifies each stage in isolation.


## Why Not Three+ Binaries Now

- askid (deparse) is deferred — the problem is unsolved
- .aski-table.sema emission is trivially small (just serialization)
- Two new binaries (semac + rsc) is the right granularity

The path to three binaries (adding askid) is straightforward
when needed — just add a repo that reads .sema + .aski-table.sema.


## Full Pipeline (with new stages)

```
corec        .aski → Rust with rkyv derives (the bootstrap tool)
aski-core    grammar .aski + corec → Rust rkyv types (askicc↔askic contract)
sema-core    parse tree .aski + corec → Rust rkyv types (askic↔semac + semac↔rsc contracts)
askicc       .synth → rkyv dialect-data-tree (32 dialects)
askic        reads dialect data → dialect state machine → rkyv parse tree
semac        rkyv parse tree → .sema + .aski-table.sema (lowering + name resolution)
rsc          .sema + .aski-table.sema → .rs (Rust projection)
```

Seven pipeline stages. Seven nix derivations. Each with one
defined input and one defined output.


## Implementation Order

1. Define sema-core::sema types (pure sema, u32 indices)
2. Define AskiNameTable type
3. Implement semac (the lowerer)
4. Implement rsc (the Rust projector)
5. (Future) Implement askid (the deparser)
