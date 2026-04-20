# aski-core — Parse Tree rkyv Contract (askic↔veric↔semac)

aski-core defines the typed parse tree that askic produces, veric
consumes and verifies, and semac consumes. corec generates Rust with
rkyv derives from the `.core` definitions.

**Scope**: this repo is the Rust rkyv types-contract crate only.
The aski language spec, grammar (tree-sitter), and editor modes live
in the `aski` repo.

## Role in the Pipeline

```
corec       — .core → Rust with rkyv derives (bootstrap tool)
synth-core  — grammar contract (askicc↔askic)
aski-core   — parse tree contract (askic↔veric↔semac) — THIS REPO
veri-core   — veric-output contract (veric↔semac)
askicc      — source/<surface>/*.synth → dsls.rkyv
askic       — reads source + dsls.rkyv → per-module aski-core rkyv
veric       — per-module rkyv → program.rkyv
semac       — program.rkyv + domain types → .sema
```

## Where Language Docs Live

See the `aski` repo for the language spec:
- `aski/spec/design.md` — language design + delimiter allocation
- `aski/spec/synth.md` — synth grammar spec
- `aski/spec/architecture.md` — pipeline + surfaces
- `aski/spec/syntax-v020.aski` — current language by example (v0.20)
- `aski/spec/gap-analysis.md` — Rust-feature gaps
- `aski/spec/bridge/paradigm.md` — spec-status framework
- `aski/spec/bridge/{clear,small-decisions,big-decisions}.md`
  — landing proposals

## Design Principles (summary)

See `aski/spec/design.md` for the full set. Load-bearing ones:

- Sema is the source of truth — aski is a projection
- Grammar rules ARE the compiler — synth dialect files define parsing
- No keywords — every symbol carries meaning
- Six delimiters, context-dependent per dialect
- PascalCase = compile-time structural things (types, traits, variants,
  fields, type params, modules, consts); camelCase = actual instances
  of a type (locals, methods, `self`, match-arm bindings). `F64` is
  the type; `f64` is an instance of it.
- No strings in sema — enum discriminants ARE the bytes
- No newline significance anywhere in the aski-family

## v0.20 Shape (this crate)

12 `.core` files defining the parse-tree types. 16 Name newtypes.
Type enum with 6 variants. Pattern enum with 5 variants (Wildcard
added 2026-04-19). Expr includes SelfRef. TraitDecl + TraitImpl
carry AssociatedTypes / AssociatedTypeBindings. LocalDecl unified
with 5 variants. Method.Body is `[Option [Box Body]]` for default
trait methods.

## ⚠️ `.core` files use LEGACY fake-enum-TOC

The 12 .core files in `core/` all start with a first-line fake-enum
that doubles as a TOC:

```aski
(Trait TraitDecl TraitImpl AssociatedTypeBinding NamedMethod Method Signature)
```

This parses as an Enum declaration named "Trait" whose variants are
the names of types defined later. Works with corec's current parser.

**Why stale:** v0.20 grammar (in askicc's `source/core/Root.synth`)
supports an OPTIONAL `?#Module#(...)` header allowing real module
name + imports declarations. `.core` files don't use it yet, and
corec's parser doesn't understand it yet.

**How to fix:** paired change —
1. Extend corec's parser to accept the v0.20 module header form.
2. Rewrite every .core file's first line from the fake-enum TOC
   to a proper module header with explicit imports.

Scheduled for a future session; not blocking current work.

## `.core` files (12)

```
primitive.core — Primitive (built-in types)
module.core    — Module, Import, Visibility
domain.core    — Enum, Struct, Newtype, Const, Rfi
trait.core     — TraitDecl, TraitImpl, AssociatedTypeBinding,
                 NamedMethod, Method, Signature
type.core      — Type (incl. SelfAssoc v0.20), TypeApplication,
                 GenericParam, TraitBound
origin.core    — Origin (lifetime annotations)
param.core     — Param (7 nested variants)
expr.core      — Expr (incl. SelfRef v0.20), FieldInit
statement.core — Statement, LocalDecl, Mutation
pattern.core   — Pattern (incl. Wildcard v0.20), MatchArm, MatchExpr
body.core      — Body, Block, Loop, Iteration, StructConstruct
program.core   — Program (exec surface output)
```

## Known Tensions

### Primitive::all() is a hand-maintained Rust list

`src/lib.rs` exposes a hardcoded list of primitive types (U8–U64,
I8–I64, F32, F64, Bool, String, Char, Vec, Option, Box, Result)
directly in Rust source. `aski/spec/design.md §No Hand-Maintained
Lists` says "every list of names, enum variants, or dispatch tables
in source code is a bug" — the Primitive struct is generated from
`.core`, but the actual *data* (which names are primitive, what
arity each has) is hand-written in Rust.

Proper fix: keep the data in a .core file and load it at build time.
Deferred; blocks on a mechanism for build-time data loading.

## VCS

Jujutsu (`jj`) mandatory. Always pass `-m`.
