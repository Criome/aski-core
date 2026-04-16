# aski

The human-readable notation for sema. Six delimiters, no keywords,
synth-driven grammar. Aski is the stepping stone — it makes sema
visible so the system can be built. Sema is the core. The criome
is the endgoal.

## What Aski Is

Sema is the universal typed binary format — no strings, no unsized
data, domain variants as bytes. Only semac produces true sema.

Aski is how you visualize sema. It projects sema's structure into
readable, writable text. The pipeline reads aski and eventually
produces sema (via semac) + Rust + .aski-table.sema (name projection).

## Design Principles

- Sema is the source of truth — aski is a projection
- Grammar rules ARE the compiler — 31 synth dialect files define parsing
- No keywords — every symbol carries meaning
- Six delimiters, context-dependent per dialect
- PascalCase = things (domains, types, modules), camelCase = actions (traits, methods)
- No strings in sema — enum discriminants ARE the bytes
- No newline significance in any aski-family language

## The Pipeline

```
cc       — .aski → Rust types (bootstrap seed)
askicc   — .synth → rkyv domain-data-tree (embedded in askic)
askic    — reads rkyv data-tree → dialect state machine → rkyv parse tree
semac    — reads rkyv → produces sema + Rust
```

Only cc and semac generate Rust. Only semac produces true sema.
Everything between them is rkyv-serialized domain-data-trees.

## Key Files

- `spec/design.md` — established constraints
- `spec/engine.md` — sema engine architecture
- `spec/synth.md` — synth grammar language
- `spec/compiler-outputs.md` — pipeline architecture
- `spec/data-trees.md` — quasi-pure domain trees
- `spec/syntax-v017.aski` — current language spec
- `spec/delimiter-budget.md` — per-dialect allocation

## Aski Language Family

Synth, nexus, and future dialects are all part of the aski family.
Same principles: no newlines, delimiter-driven, position-derived.

## VCS

Jujutsu (`jj`) is mandatory. Always pass `-m`.
