# The Three Data-Trees

Each compiler stage produces a data-tree for the next. All
three are quasi-pure domain-trees — composed almost entirely
of enums (one-of) and structs (all-of). No generic "Node"
type with untyped children.


## The Insight

Synth rules define domains. Each synth dialect IS a domain
definition:

- `//` alternatives → enum (which construct?)
- Sequential items → struct (what does it contain?)
- `+` repeated items → Vec of domain
- `?` optional items → Option of domain

The synth grammar IS the domain-tree schema. Generated Rust
types mirror it exactly.

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


## Stage 1: cc's Output — Language Anatomy Types

cc reads aski-core's .aski files and generates Rust types for
the language anatomy. These are the BASE domains — they
describe what aski constructs exist.

```rust
// Classification domains (from name.aski)
enum NameDomain { Type, Variant, Field, Trait, Method, Module, Literal, TypeParam }
enum Operator { Add, Sub, Mul, Mod, Eq, NotEq, Lt, Gt, LtEq, GtEq, And, Or }

// Scope domains (from scope.aski)
enum ScopeKind { Root, Module, Enum, Struct, Newtype, Trait, TraitImpl, Method, Block, MatchArm, Loop, Iteration }
enum Visibility { Exported, Local }

// Structure (from scope.aski, node.aski)
struct Span { Start: u32, End: u32 }
```

These are FIXED. They describe the language itself. Used by
both askicc and askic.


## Stage 2: askicc's Output — Typed Domain-Trees

askicc produces TWO kinds of types:

### 2a. Scoped declaration types (enum-as-index)

From askic's .aski source — the per-module, per-scope type
hierarchy:

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

These are the compile-time type system for askic's own source.
Zero strings. O(1) lookup.

### 2b. Parse tree domains (from synth rules)

From the .synth dialect files — the typed domain-tree that
askic populates at runtime:

```rust
// Root level — what can appear at top level?
enum RootChild {
    Module(ModuleDef),
    Enum(EnumDef),
    Struct(StructDef),
    Newtype(NewtypeDef),
    TraitDecl(TraitDeclDef),
    TraitImpl(TraitImplDef),
    Const(ConstDef),
    Ffi(FfiDef),
    Process(Block),
}

// Enum domain — from Enum.synth
struct EnumDef {
    Name: TypeName,
    Span: Span,
    Children: Vec<EnumChild>,
}

enum EnumChild {
    Variant { Name: VariantName, Span: Span },
    DataVariant { Name: VariantName, Payload: TypeExpr, Span: Span },
    StructVariant { Name: VariantName, Fields: Vec<StructField>, Span: Span },
    NestedEnum(EnumDef),
    NestedStruct(StructDef),
}

// Struct domain — from Struct.synth
struct StructDef {
    Name: TypeName,
    Span: Span,
    Children: Vec<StructChild>,
}

enum StructChild {
    TypedField { Name: FieldName, Type: TypeExpr, Span: Span },
    SelfTypedField { Name: FieldName, Span: Span },
    NestedEnum(EnumDef),
    NestedStruct(StructDef),
}

// Type expressions — from Type.synth
enum TypeExpr {
    Simple(TypeName),
    Application { Constructor: TypeName, Args: Vec<TypeExpr> },
    Param(TypeParamName),
    BoundedParam { Bounds: Vec<TypeName> },
    InstanceRef { Constructor: TypeName, Args: Vec<TypeExpr> },
}

// Newtype — from Root.synth
struct NewtypeDef {
    Name: TypeName,
    Wraps: TypeExpr,
    Span: Span,
}

// Expressions — from Expr*.synth
enum Expr {
    BinAdd { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinSub { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinMul { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinMod { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinEq { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinNotEq { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinLt { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinGt { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinLtEq { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinGtEq { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinAnd { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    BinOr { Left: Box<Expr>, Right: Box<Expr>, Span: Span },
    FieldAccess { Object: Box<Expr>, Field: FieldName, Span: Span },
    MethodCall { Object: Box<Expr>, Method: MethodName, Args: Vec<Expr>, Span: Span },
    TryUnwrap { Inner: Box<Expr>, Span: Span },
    InstanceRef { Name: TypeName, Span: Span },
    PathVariant { Type: TypeName, Variant: VariantName, Span: Span },
    PathMethod { Type: TypeName, Method: MethodName, Args: Vec<Expr>, Span: Span },
    IntLit { Value: i64, Span: Span },
    FloatLit { Value: f64, Span: Span },
    StringLit { Value: String, Span: Span },
    InlineEval(Block),
    MatchExpr(MatchExpr),
    LoopExpr(Loop),
    IterationExpr(Iteration),
    StructConstruct { Type: TypeName, Fields: Vec<FieldInit>, Span: Span },
}

struct FieldInit {
    Name: FieldName,
    Value: Box<Expr>,
}

// Statements — from Statement.synth
enum Statement {
    EarlyReturn(Box<Expr>),
    Loop(Loop),
    Iteration(Iteration),
    LocalTypeDecl { Name: TypeName, Type: TypeExpr, Span: Span },
    Mutation(Mutation),
    Instance(Instance),
    ExprStatement(Box<Expr>),
}

struct Loop {
    Condition: Option<Box<Expr>>,
    Body: Vec<Statement>,
}

struct Iteration {
    Source: Box<Expr>,
    Body: Block,
}

struct Instance {
    Name: TypeName,
    TypeAnnotation: Option<TypeExpr>,
    Value: Box<Expr>,
    Span: Span,
}

struct Mutation {
    Name: TypeName,
    Method: MethodName,
    Args: Vec<Expr>,
    Span: Span,
}

// Bodies — from Method.synth
enum MethodBody {
    Block(Block),
    Match(MatchExpr),
    Loop(Loop),
    Iteration(Iteration),
    StructConstruct { Type: TypeName, Fields: Vec<FieldInit>, Span: Span },
}

struct Block {
    Statements: Vec<Statement>,
    Tail: Option<Box<Expr>>,
}

struct MatchExpr {
    Target: Option<Box<Expr>>,
    Arms: Vec<MatchArm>,
}

struct MatchArm {
    Patterns: Vec<Pattern>,
    Result: Box<Expr>,
}

enum Pattern {
    Variant(VariantName),
    VariantBind { Variant: VariantName, Binding: TypeName },
    OrPattern(Vec<VariantName>),
    StringLit(String),
}

// Traits — from TraitDecl.synth, TraitImpl.synth
struct TraitDeclDef {
    Name: TraitName,
    Signatures: Vec<MethodSig>,
    Span: Span,
}

struct MethodSig {
    Name: MethodName,
    Params: Vec<Param>,
    ReturnType: Option<TypeExpr>,
    Span: Span,
}

struct TraitImplDef {
    Trait: TraitName,
    Type: TypeName,
    Methods: Vec<MethodDef>,
    Span: Span,
}

struct MethodDef {
    Name: MethodName,
    Params: Vec<Param>,
    ReturnType: Option<TypeExpr>,
    Body: MethodBody,
    Span: Span,
}

enum Param {
    BorrowSelf,
    MutBorrowSelf,
    OwnedSelf,
    Named { Name: TypeName, Type: TypeExpr },
    Bare { Name: TypeName },
}
```

Every type here is a domain (enum or struct). No generic
Node. No untyped children. The tree IS domains all the way
down.


## Stage 3: askic's Output — Populated Domain-Tree

askic reads user .aski source and produces a populated
instance of the parse tree domains. The TYPES come from
askicc (stage 2b). The VALUES come from parsing.

For `(Element Fire Earth Air Water)`, askic produces:

```rust
EnumDef {
    Name: TypeName::Element,
    Span: Span { Start: 0, End: 35 },
    Children: vec![
        EnumChild::Variant { Name: VariantName::Fire, Span: ... },
        EnumChild::Variant { Name: VariantName::Earth, Span: ... },
        EnumChild::Variant { Name: VariantName::Air, Span: ... },
        EnumChild::Variant { Name: VariantName::Water, Span: ... },
    ],
}
```

For a method body: `[@Self.Left + @Self.Right]`:

```rust
MethodBody::Block(Block {
    Statements: vec![],
    Tail: Some(Box::new(Expr::BinAdd {
        Left: Box::new(Expr::FieldAccess {
            Object: Box::new(Expr::InstanceRef {
                Name: TypeName::Self_,
                Span: ...,
            }),
            Field: FieldName::Left,
            Span: ...,
        }),
        Right: Box::new(Expr::FieldAccess {
            Object: Box::new(Expr::InstanceRef {
                Name: TypeName::Self_,
                Span: ...,
            }),
            Field: FieldName::Right,
            Span: ...,
        }),
        Span: ...,
    })),
})
```

Pure domains. Every value is typed. No generic nodes. The
tree structure IS the domain hierarchy.


## What semac Receives

semac receives this populated domain-tree and walks it to
produce:

1. **.sema binary** — the domain-tree serialized. Each enum
   variant becomes a discriminant byte. Each struct becomes
   a record. rkyv zero-copy.

2. **Rust source** — the domain-tree translated to Rust code.
   Each EnumDef → `enum Name { ... }`. Each StructDef →
   `struct Name { ... }`. Each Expr → Rust expression.

3. **.aski-table.sema** — name projection. Maps domain
   variants back to their aski source names.

The domain-tree IS the interface between askic and semac.
Fully typed. No strings (except in literals and the name
table). Domains all the way down.


## Why This Works

**Synth rules = domain definitions.** Each dialect IS a
domain. The grammar defines the tree's type system. No
separate "AST definition" — the grammar IS the AST.

**Generated types = generated domains.** askicc reads the
synth rules and generates Rust enums and structs. The
generated code IS the domain-tree schema.

**Parsing = populating domains.** askic doesn't build
generic nodes. It constructs typed domain values. The
parser knows exactly what type each construct produces
because the types are compiled in.

**Serialization = domain flattening.** semac walks the
domain-tree and serializes it. Each enum → discriminant.
Each struct → record fields. The .sema binary IS the
domain-tree in binary form.

**The three stages share the SAME domain structure.**
They just add layers:
- cc: the classification domains (what KINDS of things exist)
- askicc: the structural domains (what SHAPE each thing has)
- askic: the populated domains (what VALUES each thing holds)
