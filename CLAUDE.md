# aski-core — Parse Tree rkyv Contract (askic↔veric↔semac)

aski-core defines the typed parse tree that askic produces,
veric consumes and verifies, and semac consumes. corec generates
Rust with rkyv derives from the `.core` definitions.

## Role in the Pipeline

```
corec       — .core → Rust with rkyv derives (bootstrap tool)
synth-core  — grammar contract (askicc↔askic)
aski-core   — parse tree contract (askic↔veric↔semac) — THIS REPO + spec docs
veri-core   — veric-output contract (veric↔semac)
askicc      — source/<surface>/*.synth → dsls.rkyv (domain-data-tree)
askic       — reads source + dsls.rkyv → rkyv parse tree (domain-data-tree of aski-core types)
veric       — per-module rkyv → program.rkyv
semac       — program.rkyv + domain types → .sema
```

## What Aski Is

Sema is the universal typed binary format — domain variants as
bytes. Only semac produces true sema.

Aski is how you visualize sema — a text projection readable by
humans and writable by hand. The pipeline reads aski and
eventually produces sema (via semac) + Rust + `.aski-table.sema`
(name projection).

## Design Principles

- Sema is the source of truth — aski is a projection
- Grammar rules ARE the compiler — synth dialect files define parsing
- No keywords — every symbol carries meaning
- Six delimiters, context-dependent per dialect
- PascalCase = compile-time structural (types, traits, variants, fields, type params, modules, consts); camelCase = actual instances of a type (locals, methods, self, match-arm bindings). `F64` is the type; `f64` is an instance of it.
- No strings in sema — enum discriminants ARE the bytes
- No newline significance anywhere in the aski-family

## v0.20 Shape

12 .core files. v0.20 changes layered on v0.19:
- **Visibility**: Module.Exports retired (declaration-local via `@` sigil in grammar).
- **Module.Rfis retired** — RFI moved to its own `.rfi` surface.
- **Associated types**: TraitDecl.AssociatedTypes + TraitImpl.AssociatedTypeBindings + new AssociatedTypeBinding type.
- **Type.SelfAssoc** variant added for `self:Item` paths.
- **Expr.SelfRef** variant added for bare `self` as expression atom.
- **AssociatedName** newtype added (16 Name newtypes total).

v0.19 changes carried over:
- LocalDecl unified (5 nested variants).
- Loop struct with required Condition (InfiniteLoop retired).
- Type enum — 6 variants in v0.20 (InstanceType retired in v0.19; SelfAssoc added in v0.20).
- Pattern — v0.20 has 5 variants: Wildcard (added 2026-04-19), VariantBind, VariantAlt, VariantMatch, StringMatch.
- program.core (exec surface output).
- Method.Body is `[Option [Box Body]]` — default trait methods.

## ⚠️ .core files use LEGACY fake-enum-TOC (forward-facing grammar supports module header but files haven't migrated)

The 12 .core files in `core/` all start with a first-line fake-enum
that doubles as a TOC:

```aski
(Trait TraitDecl TraitImpl Method Signature NamedMethod AssociatedTypeBinding)
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

Five DSLs (surfaces, v0.20): core, aski, synth, exec, **rfi** (new).
Each is a grammar family. Dialects within a DSL (Body, Statement,
Expr, …) are the individual `.synth` files that compose it.
askicc bundles all five DSLs into one `dsls.rkyv` — a domain-data-tree:
every node is an enum (one-of) or struct (all-of) of synth-core types.

aski-core follows the same principle — a quasi-pure domain-tree
of the parse. No generic "Node" with untyped children; every
piece has a concrete typed home (Module, Enum, Struct, Method,
Type, Pattern, …). That's what makes askic's output intelligible
to veric/semac: it reads typed domain data, not text.

Lifetime-aware: `'Place` origin sigil, view types via `{| |}`.
See spec/design.md §Origins.

## Key Files

- `spec/design.md` — language design + delimiter allocation
- `spec/synth.md` — synth grammar spec (with v0.19 additions)
- `spec/architecture.md` — pipeline + surfaces
- `spec/syntax-v020.aski` — current language reference examples (v0.20)
  (syntax-v019.aski / syntax-v018.aski retained for historical reference)

## Aski Language Family

Synth, nexus, and future DSLs are all part of the aski family.
Same principles: no newlines, delimiter-driven, position-derived.

## Known Tensions

### Primitive::all() is a hand-maintained Rust list

`aski-core/src/lib.rs` exposes a hardcoded list of primitive types
(U8–U64, I8–I64, F32, F64, Bool, String, Char, Vec, Option, Box,
Result) directly in Rust source. design.md §No Hand-Maintained Lists
says "every list of names, enum variants, or dispatch tables in
source code is a bug" — the Primitive struct is generated from
`.core`, but the actual *data* (which names are primitive, what
arity each has) is hand-written in Rust.

Proper fix: keep the data in a .core file (something like
`core/primitive-data.core`) and load it at build time, the way
askicc embeds dialect data. Deferred; blocks on a mechanism for
build-time data loading across the aski-core / corec boundary.

(Extracted from Mentci/AUDIT-REPORT.md before that file was
deleted 2026-04-20.)

## VCS

Jujutsu (`jj`) is mandatory. Always pass `-m`.
