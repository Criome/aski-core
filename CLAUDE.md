# aski

The human-readable notation for sema. Six delimiters, no keywords,
synth-driven grammar. Aski is the stepping stone — it makes sema
visible so the system can be built. Sema is the core. The criome
is the endgoal.

## What Aski Is

Sema is a fully-specified binary code — pure typed structure, no strings.
At first it uses portable rkyv encoding. Sema IS the artifact.

Aski is how you visualize sema. It projects sema's binary structure into
readable, writable text. The sema engine reads aski and produces .sema
(pure binary) + .aski-table.sema (name projection). Codegen and deparse
are further projections from .sema into Rust or back to aski text.

## Design Principles

- Sema is the source of truth — aski is a projection
- Grammar rules ARE the compiler — 28 synth dialect files define parsing
- No keywords — every symbol carries meaning
- Six delimiters, context-dependent per dialect:
  Root: () Module(first)/Domain/Trait [] TraitImpl {} Struct {||} Const (||) FFI [||] Process
  Body: () Group [] Block {} StructConstruct {||} Loop (||) Match [||] EarlyReturn
- PascalCase = things (domains, types, modules), camelCase = actions (traits, methods)
- No strings in sema — enum discriminants ARE the bytes
- No newline significance in any aski-family language

## Aski Language Family

Synth, nexus, and future dialects are all part of the aski family.
Same principles: no newlines, delimiter-driven, position-derived.

## Key Files

- `spec/engine.md` — sema engine intent document
- `spec/syntax.aski` — v0.16 language spec
- `spec/dialect-tree.md` — 28 dialect hierarchy

## VCS

Jujutsu (`jj`) is mandatory. Always pass `-m`.
