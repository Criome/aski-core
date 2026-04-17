# askid — Aski Deparser

## What It Does

askid reads .sema and reconstructs canonical aski text. It is
the reverse of askic — the sema→aski direction. It proves that
sema is lossless: anything that went in can come back out.

```
.sema + .aski-table.sema + domain crate → .aski text (canonical)
```

askid is a PROJECTION from sema, parallel to rsc:
- rsc: .sema + domain crate → .rs (Rust projection)
- askid: .sema + domain crate + name table → .aski (aski projection)


## Why It Matters

From design.md: "Self-hosting requires the full grammar — the
same grammar that parses also reconstructs (bidirectional).
Shortcuts break round-tripping from sema."

The round-trip: `.aski → askic → semac → .sema → askid → .aski`

The output .aski is CANONICAL — same formatting for equivalent
programs. Running it twice is idempotent.


## Inputs

**Build-time (embedded):**
- aski-core types (dialect grammar structure)
- askicc's rkyv dialect data (the synth grammar as data)

**Runtime (files):**
- `.sema` — the program content (pure binary, no strings)
- `.aski-table.sema` — the name table (index → string)

**Cargo dependency:**
- `<program>-domains` crate — domainc's output, for .sema deserialization


## The Grammar Is Bidirectional

Each synth rule works in both directions:

**Sequential rules** — parse reads items left-to-right,
deparse emits items left-to-right.

**Ordered choice** — parse tries alternatives until match,
deparse uses the variant to select the alternative.

**Delimiters** — parse matches open/close, deparse emits
open/close.

**Cardinality** — parse collects Vec/Option, deparse
iterates and emits.


## Expression Precedence

The expression chain (ExprOr→ExprAnd→...→ExprAtom) is a
parsing mechanism only — it doesn't survive into the parse
tree or .sema. The tree structure encodes precedence:
`BinAdd(a, BinMul(b, c))` = `a + b * c`.

For deparse, askid maintains a 6-level precedence table
(matching the dialect chain) and emits `[expr]` grouping
only when a lower-precedence expression is a child of a
higher-precedence one.


## Output Format

Canonical. One .aski file per module. Module name determines
filename. Consistent formatting:

```aski
(Elements Element Quality describe)

(Element Fire Earth Air Water)
(Quality Passionate Grounded Intellectual Intuitive)

{Point (Horizontal F64) (Vertical F64)}

Counter U32
```

Whitespace is always canonical (newlines are not significant
in aski). Comments are not preserved (not in .sema).


## Dependencies

```
askid depends on:
  - <program>-domains crate (domainc output)
  - aski-core (for dialect grammar types)
  - askicc rkyv (embedded — the synth grammar as data)
  - rkyv (for deserialization)
```


## Pipeline Position

```
corec       .aski → Rust with rkyv derives
aski-core   grammar .aski + corec → rkyv types
aski        parse tree .aski + corec → rkyv types
askicc      .synth → rkyv dialect-data-tree
askic       .aski source → rkyv parse tree
domainc     rkyv parse tree → domain crate
semac       rkyv parse tree + domain crate → .sema + .aski-table.sema
rsc         .sema + domain crate → .rs
askid       .sema + domain crate + name table → .aski
```

rsc and askid are sibling projectors from .sema. Neither
depends on the other.
