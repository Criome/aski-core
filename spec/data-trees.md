# The Three Data-Trees

Each compiler stage produces a data-tree for the next. All
three are quasi-pure domain-trees — composed almost entirely
of enums (one-of) and structs (all-of). No generic "Node"
type with untyped children.

All intermediate data is rkyv-serialized. **Only semac
produces true sema** — no strings, no unsized data, domain
variants as bytes. Everything upstream has strings and is
therefore rkyv, not sema.


## The Insight

Synth rules define domains. Each synth dialect IS a domain
definition:

- `//` alternatives → enum (which construct?)
- Sequential items → struct (what does it contain?)
- `+` repeated items → Vec of domain
- `?` optional items → Option of domain

The synth grammar IS the domain-tree schema.

```synth
;; Enum.synth defines this domain:
// *@Variant                    → Variant (leaf)
// *(@Variant <Type>)           → DataVariant (struct: name + type)
// *{@Variant <Struct>}         → StructVariant (struct: name + fields)
// *(|@Enum <Enum>|)            → NestedEnum (recursive)
// *{|@Struct <Struct>|}        → NestedStruct (recursive)
```

This IS an enum definition:

```rust
enum EnumChild {
    Variant { Name: VariantName },
    DataVariant { Name: VariantName, Payload: TypeExpr },
    StructVariant { Name: VariantName, Fields: Vec<StructField> },
    NestedEnum(EnumDef),
    NestedStruct(StructDef),
}
```

The synth rule → the Rust enum. One-to-one. The grammar IS
the type system of the data-tree.


## Stage 1: corec + aski-core — The askicc/askic rkyv Contract

aski-core defines every type that appears in the rkyv message
between askicc and askic. corec generates Rust with rkyv derives
from the .aski definitions. Both askicc (serializer) and
askic (deserializer) depend on corec's output.

Source of truth (currently incomplete — see aski-core CLAUDE.md):
- `aski-core/core/name.aski` — NameDomain, Operator
- `aski-core/core/scope.aski` — ScopeKind, Visibility
- `aski-core/core/span.aski` — Span
- (missing) — Dialect, Rule, Item, ItemContent, DelimKind,
  Cardinality, DialectKind, Sigil

corec is one of only two tools that generate Rust (the other
is semac). corec is used by both aski-core and sema-core.


## Stage 2: askicc's Output — rkyv Domain-Data-Tree

askicc reads .synth dialect files, populates a domain-data-
tree using aski-core's corec-generated types, and serializes
it as rkyv. This rkyv data gets embedded in the askic binary
at build time, giving askic the ability to read that version
of aski's grammar. askic deserializes using the same
corec-generated types.

**askicc does NOT generate Rust.** Only corec and semac generate
Rust. askicc produces rkyv data.

The domain-data-tree IS the state machine that drives askic's
parser. It captures what tokens to match, in what order, with
what adjacency, using what delimiters, with what cardinality.

### Parse tree domains (from synth rules)

The synth rules define the typed domain-tree that askic's
engine populates at runtime. These domain types are defined
in .aski files:

- `askicc/aski/root.aski` — RootChild, ModuleDef, EnumDef, StructDef, NewtypeDef, ConstDef, FfiDef
- `askicc/aski/type.aski` — TypeExpr, TypeApplication, GenericParam
- `askicc/aski/expr.aski` — Expr, FieldInit
- `askicc/aski/statement.aski` — Statement, Instance, Mutation, Loop, Iteration
- `askicc/aski/body.aski` — Block, MethodBody, Param
- `askicc/aski/trait.aski` — TraitDeclDef, TraitImplDef, MethodSig, MethodDef
- `askicc/aski/pattern.aski` — MatchExpr, MatchArm, Pattern
- `askicc/aski/dialect.aski` — Dialect, Rule, Item, ItemContent, Cardinality, Casing, DelimKind

The .aski files ARE the source of truth. Every type is a
domain (enum or struct). No generic Node. No untyped children.
The tree IS domains all the way down.


## Stage 3: askic's Output — rkyv Parse Tree

askic reads user .aski source and produces an rkyv-serialized
parse tree. askic is a generic dialect engine — it contains
no language-specific parsing logic. askicc's rkyv domain-data-
tree (aski-core types) is embedded in askic at build time,
and the engine executes it as a dialect-based state machine.
askic serializes its parse tree output using sema-core types —
the contract that semac reads.

askic's output is rkyv, NOT sema — it has strings (user
names, literals). It becomes sema only when semac processes it.

The parse tree records the engine's path through the dialect
state machine. Each node captures which dialect was entered,
which alternative matched, what names were declared, and
what values were found. Pure domains all the way down.


## What semac Receives

semac receives askic's rkyv parse tree (sema-core types).
semac depends only on sema-core, NOT on aski-core. This is
NOT sema yet — it has strings (user names, literals). semac
resolves strings to domain variants and produces:

1. **True sema** — the domain-tree with no strings. Each
   enum variant is a discriminant byte. Each struct is a
   record. Fixed-size. No unsized data.

2. **Rust source** — the domain-tree translated to Rust.

3. **.aski-table.sema** — name projection. Maps domain
   variants back to their aski source names.

This is where rkyv becomes sema.


## Why This Works

**Synth rules = domain definitions.** Each dialect IS a
domain. The grammar defines the tree's type system. No
separate "AST definition" — the grammar IS the AST.

**Grammar is data, not code.** askicc produces a rkyv
domain-data-tree that gets embedded in askic. askic is a
generic dialect engine with no language knowledge compiled in.

**Parsing = walking a state machine.** askic executes the
embedded dialect data as a state machine against the token
stream. The engine records its path through the state machine
— that path IS the parse tree.

**Only semac produces sema.** Everything upstream is rkyv.
semac is where strings become domain variants, where unsized
data becomes fixed-size, where rkyv becomes sema.

**The pipeline forms a clear chain:**
- corec: generates Rust rkyv types from .aski definitions
- aski-core: grammar types (askicc↔askic contract) → corec → Rust
- sema-core: parse tree types (askic↔semac contract) → corec → Rust
- askicc: the grammar data (what SHAPE each thing has) → rkyv
- askic: the populated data (what VALUES each thing holds) → rkyv
- semac: the canonical form (domain variants as bytes) → sema + Rust
