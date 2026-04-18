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
- PascalCase = things (domains, types, modules), camelCase = actions (traits, methods)
- No strings in sema — enum discriminants ARE the bytes
- No newline significance anywhere in the aski-family

## v0.18 Shape

Four DSLs (surfaces): core, aski, synth, exec. Each is a grammar
family. Dialects within a DSL (Body, Statement, Expr, …) are the
individual `.synth` files that compose it. askicc bundles all
four DSLs into one `dsls.rkyv` — a domain-data-tree: every node
is an enum (one-of) or struct (all-of) of synth-core types.

aski-core follows the same principle — a quasi-pure domain-tree
of the parse. No generic "Node" with untyped children; every
piece has a concrete typed home (Module, Enum, Struct, Method,
Type, Pattern, …). That's what makes askic's output intelligible
to veric/semac: it reads typed domain data, not text.

Lifetime-aware: `'Place` origin sigil, view types via `{| |}`.
See spec/design.md §Origins.

## Key Files

- `spec/design.md` — language design + delimiter allocation
- `spec/synth.md` — synth grammar spec (with v0.18 additions)
- `spec/architecture.md` — pipeline + surfaces
- `spec/syntax-v018.aski` — language reference examples

## Aski Language Family

Synth, nexus, and future DSLs are all part of the aski family.
Same principles: no newlines, delimiter-driven, position-derived.

## VCS

Jujutsu (`jj`) is mandatory. Always pass `-m`.
