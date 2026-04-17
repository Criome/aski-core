# Sema Engine — Architecture

## Sema Is the Thing

Sema is a universal typed binary format. No strings. No unsized
data. Domain variants ARE the bytes. Everything else exists to
serve sema.

Only semac produces true sema. Everything upstream is rkyv. If
it has unsized data, it is not sema.


## The Pipeline

```
corec       — .aski → Rust with rkyv derives (the bootstrap tool, lives in its own repo)
aski-core   — grammar .aski + corec → Rust rkyv types (askicc↔askic contract)
aski        — parse tree .aski + corec → Rust rkyv types (askic↔semac contract)
askicc      — uses aski-core types → rkyv dialect-data-tree (embedded in askic)
askic       — uses aski-core (input) + aski (output), embeds askicc's rkyv
semac       — reads rkyv parse tree (aski types) → .sema + .aski-table.sema + Rust
```

Each stage is a nix derivation depending on the previous.
Each binary has one defined input and one defined output.


## The Naming IS the Architecture

```
aski-core   = the core of aski's grammar
askicc      = aski-core compiler (produces aski-core rkyv)

aski        = the full aski representation  
askic       = aski compiler (produces aski rkyv)
```

askicc compiles aski-core. askic compiles aski. The names
are the architecture.


## Two rkyv Contracts

```
aski-core (.aski) ──corec──→ Rust types with rkyv derives
                                   │
                       ┌───────────┴───────────┐
                       ▼                       ▼
                    askicc                   askic
                 (serializes)           (deserializes)

aski (.aski) ──corec──→ Rust types with rkyv derives
                              │
                  ┌───────────┴───────────┐
                  ▼                       ▼
               askic                   semac
            (serializes)           (deserializes)
```

aski-core defines grammar types: Dialect, Rule, Item, Label,
DialectKind, DeclareLabel, LiteralToken, DelimKind, etc.

aski defines parse tree types: Expr, Statement, Block, Pattern,
EnumDef, StructDef, TraitDeclDef, MethodDef, TypeExpr, etc.


## corec — The Bootstrap Tool

Reads .aski domain definitions, emits Rust with rkyv derives.
Zero dependencies. Used by both aski-core and aski to generate
their contract types. Also used to generate per-program domain
types (the enum-as-index architecture).


## askicc — The Grammar Compiler

Reads .synth dialect files. Populates aski-core domain types.
Serializes as rkyv. The rkyv output is embedded in askic at
build time, giving askic the ability to parse that version of
aski's grammar.


## askic — The Aski Compiler

A generic dialect engine with NO language-specific parsing
logic. The embedded rkyv dialect data IS the state machine.
Reads .aski source, produces rkyv parse tree using aski types.

Three layers:
- Lexer — tokenizes .aski source
- Engine — walks dialect data, matches tokens, produces ParseValues
- Builders — per-dialect constructors, converts ParseValues to aski types


## semac — The Sema Backend

Reads rkyv parse tree (aski types). Performs semantic analysis:
- Builds scope tree from domain definitions
- Resolves all names against scopes
- Generates per-program domain types as .aski core definitions
- Uses corec to compile those into Rust types
- Compiles expressions/bodies using the resolved types
- Produces .sema (pure binary) + .aski-table.sema (name projection) + Rust source


## Per-Program Domain Generation

The parse tree contains domain definitions with strings:
`EnumDef { name: "Element", children: [Variant("Fire"), ...] }`

semac extracts these and writes .aski core definitions:
`(Element Fire Earth Air Water)`

corec compiles them into Rust enums with rkyv derives:
`pub enum Element { Fire, Earth, Air, Water }`

These ARE the sema domains. The enum discriminant IS the byte.
No indices, no lookup tables. Real Rust enums.


## The Data Trees

Each stage produces a data tree for the next:

**Stage 1: corec** — classification domains (what KINDS of
things exist). Defined in .aski files.

**Stage 2: askicc** — grammar data (what SHAPE each construct
has). Populated from .synth files using aski-core types.

**Stage 3: askic** — populated parse tree (what VALUES each
construct holds). Populated from .aski source using aski types.

**Stage 4: semac** — resolved sema (domain variants as bytes).
Generated from the parse tree with all names resolved.


## Synth IS the Grammar

PascalCase .synth dialect files define aski's entire syntax.
32 dialects. Each file's name is a DialectKind variant.

Synth items:
- `@Label` — declare a name (Binding::Declare)
- `:Label` — reference an existing name (Binding::Reference)
- `<Dialect>` — enter another dialect
- `()[]{}(||){||}[||]` — match delimiters
- `_X_` — literal token escape
- `*+?` — cardinality
- `//` — ordered choice

The Label struct carries: Binding (Declare/Reference) +
LabelKind (what it is) + Casing (Pascal/Camel). Three bytes.

Keywords: Self, Main. Matched exactly, not declared or referenced.


## Delimiters Are Context-Dependent

At root level:
- `()` — Module (first), Enum, TraitDecl
- `[]` — TraitImpl
- `{}` — Struct
- `{||}` — Const
- `(||)` — FFI
- `[||]` — Process

In body context:
- `()` — Local type declaration
- `[]` — Block, InlineEval
- `{}` — StructConstruct
- `[||]` — Loop
- `{||}` — Iteration
- `(||)` — Match


## Rust Style

**No free functions — methods on types always.** All Rust will
eventually be rewritten in aski, which uses methods (traits +
impls). `main` is the only exception.


## Repos

```
corec        .aski → Rust with rkyv derives (bootstrap tool)
aski-core    grammar .aski + corec → rkyv types (askicc↔askic)
aski         parse tree .aski + corec → rkyv types (askic↔semac)
askicc       .synth → rkyv dialect-data-tree (32 dialects)
askic        dialect engine → rkyv parse tree (29 tests, nix verified)
semac        rkyv parse tree → sema + Rust (implementation pending)
sema         Nix aggregator
```
