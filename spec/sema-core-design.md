# sema-core Design — Ideal Domain Tree for Rust Codegen

The goal: represent Rust as a domain tree where every variant
maps to exactly one Rust codegen pattern. No ambiguity, no
information loss. semac walks this tree and emits Rust mechanically.

## Design Principles

1. **One variant = one codegen pattern.** If two Rust constructs
   produce different text, they need different variants.
2. **No secondary dispatch.** semac should never string-match or
   check a sub-field to decide what Rust to emit. The variant IS
   the decision.
3. **Ownership is explicit.** &T, &mut T, T, Box<T> are all
   different types that generate different Rust.
4. **Aski concepts preserved.** Instance (@), Mutation (~@), and
   other aski-specific forms get their own variants — semac knows
   what aski pattern produced them.


## Type Expressions

Every position where a type can appear in Rust.

```aski
(TypeExpr
  ;; simple: U32, String, Element
  (Named TypeName)

  ;; Self — the implementing type
  SelfType

  ;; generic application: Vec<T>, Result<T, E>
  (Application TypeApplication)

  ;; type parameter reference: $Value
  (Param TypeParamName)

  ;; bounded parameter: $Clone&Debug
  {BoundedParam (Bounds [Vec TypeName])}

  ;; references — the core ownership distinction
  {Ref (Inner [Box TypeExpr])}
  {MutRef (Inner [Box TypeExpr])}

  ;; Box<T> — distinct for codegen (omit_bounds, heap semantics)
  (Boxed [Box TypeExpr])

  ;; tuple: (A, B, C), unit: ()
  {Tuple (Elements [Vec TypeExpr])}
  Unit

  ;; array: [T; N], slice: [T]
  {Array (Element [Box TypeExpr]) (Size U64)}
  {Slice (Element [Box TypeExpr])}

  ;; fn(A, B) -> C
  {FnPtr (Params [Vec TypeExpr]) (Return [Box TypeExpr])}

  ;; ! — never/diverging
  Never

  ;; dyn Trait, impl Trait
  {DynTrait (Bounds [Vec TraitBound])}
  {ImplTrait (Bounds [Vec TraitBound])}

  ;; aski instance ref: @[Vec Element]
  (InstanceRef TypeApplication)

  ;; <Type as Trait>::Associated
  {QualifiedPath (Base [Box TypeExpr]) (Segment TypeName)})

{TypeApplication
  (Constructor TypeName)
  (Args [Vec TypeExpr])}

{TraitBound
  (Trait TraitName)
  (Args [Vec TypeExpr])}

{GenericParamDef
  (Name TypeParamName)
  (Bounds [Vec TraitBound])
  (Default [Option TypeExpr])}
```


## Expressions

Every kind of Rust expression, maximally explicit.

```aski
(Expr
  ;; ── Literals ──────────────────────────────────────────
  {IntLit (Value I64) Span}
  {FloatLit (Value F64) Span}
  {StringLit (Value String) Span}
  {BoolLit (Value Bool) Span}
  {CharLit (Value U32) Span}
  UnitLit

  ;; ── Binary — arithmetic ───────────────────────────────
  {BinAdd (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinSub (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinMul (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinDiv (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinMod (Left [Box Expr]) (Right [Box Expr]) Span}

  ;; ── Binary — comparison ───────────────────────────────
  {BinEq (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinNotEq (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinLt (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinGt (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinLtEq (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinGtEq (Left [Box Expr]) (Right [Box Expr]) Span}

  ;; ── Binary — logical ──────────────────────────────────
  {BinAnd (Left [Box Expr]) (Right [Box Expr]) Span}
  {BinOr (Left [Box Expr]) (Right [Box Expr]) Span}

  ;; ── Unary ─────────────────────────────────────────────
  {UnaryNeg (Inner [Box Expr]) Span}
  {UnaryNot (Inner [Box Expr]) Span}
  {UnaryDeref (Inner [Box Expr]) Span}
  {UnaryBorrow (Inner [Box Expr]) Span}
  {UnaryBorrowMut (Inner [Box Expr]) Span}

  ;; ── Access ────────────────────────────────────────────
  {FieldAccess (Object [Box Expr]) (Field FieldName) Span}
  {MethodCall (Object [Box Expr]) (Method MethodName) (Args [Vec Expr]) Span}
  {TryUnwrap (Inner [Box Expr]) Span}

  ;; ── Calls ─────────────────────────────────────────────
  ;; Type::method(args) — associated function
  {PathCall (Type TypeName) (Method MethodName) (Args [Vec Expr]) Span}

  ;; ── Path expressions ──────────────────────────────────
  ;; @Name — aski instance reference
  {InstanceRef (Name TypeName) Span}
  ;; self
  {SelfRef Span}
  ;; Type::Variant — unit enum variant
  {PathVariant (Type TypeName) (Variant VariantName) Span}
  ;; Type::Variant(expr) — data-carrying variant
  {PathVariantData (Type TypeName) (Variant VariantName) (Payload [Box Expr]) Span}

  ;; ── Construction ──────────────────────────────────────
  ;; MyStruct { field: value }
  {StructConstruct (Type TypeName) (Fields [Vec FieldInit]) Span}
  ;; (a, b, c)
  {TupleExpr (Elements [Vec Expr]) Span}
  ;; [a, b, c]
  {ArrayExpr (Elements [Vec Expr]) Span}

  ;; ── Block ─────────────────────────────────────────────
  (InlineEval Block)

  ;; ── Control flow as expressions ───────────────────────
  (Match MatchExpr)
  (Loop LoopExpr)
  (Iteration Iteration)

  ;; ── Return/break ──────────────────────────────────────
  (EarlyReturn [Box Expr])
  ReturnUnit
  (Break [Option [Box Expr]])
  Continue

  ;; ── Cast ──────────────────────────────────────────────
  {CastExpr (Inner [Box Expr]) (Target TypeExpr) Span})

{FieldInit
  (Name FieldName)
  (Value [Box Expr])}
```


## Statements

```aski
(Statement
  ;; let x = expr, let x: T = expr, let mut x = expr
  (Let LetBinding)

  ;; expr;
  (Expr [Box Expr])

  ;; return expr, return
  (EarlyReturn [Box Expr])
  ReturnUnit

  ;; loop { body }
  (Loop LoopExpr)

  ;; while cond { body }
  {While (Condition [Box Expr]) (Body Block) Span}

  ;; for item in source { body }
  (Iteration Iteration)

  ;; (Name Type) — aski local type declaration
  {LocalTypeDecl (Name TypeName) (Type TypeExpr) Span}

  ;; ~@Name.method(args) — aski mutation
  (Mutation Mutation)

  ;; @Name expr — aski instance creation
  (Instance Instance))

{LetBinding
  (Pattern Pattern)
  (Mutable Bool)
  (TypeAnnotation [Option TypeExpr])
  (Value [Box Expr])
  Span}

{Instance
  (Name TypeName)
  (TypeAnnotation [Option TypeExpr])
  (Value [Box Expr])
  Span}

{Mutation
  (Name TypeName)
  (Method MethodName)
  (Args [Vec Expr])
  Span}

{LoopExpr
  (Condition [Option [Box Expr]])
  (Body Block)}

{Iteration
  (Binding Pattern)
  (Source [Box Expr])
  (Body Block)}
```


## Patterns

Every Rust pattern form.

```aski
(Pattern
  ;; _
  Wildcard

  ;; x, mut x — identifier binding
  {IdentBind (Name TypeName) (Mutable Bool) Span}

  ;; literal: 42, "hello", true
  {LitPattern (Value LiteralValue) Span}

  ;; Type::Variant — unit variant
  {VariantPattern (Type [Option TypeName]) (Variant VariantName) Span}

  ;; Type::Variant(inner) — data-carrying variant
  {VariantDataPattern (Type [Option TypeName]) (Variant VariantName)
                      (Inner [Vec Pattern]) Span}

  ;; Type::Variant { fields } — struct variant
  {VariantStructPattern (Type [Option TypeName]) (Variant VariantName)
                        (Fields [Vec PatternField]) Span}

  ;; (a, b, c) — tuple destructure
  {TuplePattern (Elements [Vec Pattern]) Span}

  ;; MyStruct { x, y, .. } — struct destructure
  {StructPattern (Type TypeName) (Fields [Vec PatternField]) Span}

  ;; pattern | pattern — or-pattern
  {OrPattern (Alternatives [Vec Pattern]) Span}

  ;; "(" — string literal pattern
  (StringLitPattern String)

  ;; &pattern
  {RefPattern (Inner [Box Pattern]) Span}

  ;; ..
  Rest)

{PatternField
  (Name FieldName)
  (Pattern [Option Pattern])}

{MatchExpr
  (Target [Option [Box Expr]])
  (Arms [Vec MatchArm])}

{MatchArm
  (Pattern Pattern)
  (Guard [Option [Box Expr]])
  (Result [Box Expr])}
```


## Bodies and Parameters

```aski
{Block
  (Statements [Vec Statement])
  (Tail [Option [Box Expr]])}

(MethodBody
  (Block Block)
  (Match MatchExpr)
  (Loop LoopExpr)
  (Iteration Iteration)
  {StructConstruct (Type TypeName) (Fields [Vec FieldInit]) Span})

(Param
  BorrowSelf
  MutBorrowSelf
  OwnedSelf
  {BorrowNamed (Name TypeName) (Type TypeExpr)}
  {MutBorrowNamed (Name TypeName) (Type TypeExpr)}
  {Named (Name TypeName) (Type TypeExpr)}
  {Bare (Name TypeName)})
```


## Traits and Implementations

```aski
{TraitDeclDef
  (Name TraitName)
  (Visibility Visibility)
  (GenericParams [Vec GenericParamDef])
  (SuperTraits [Vec TraitBound])
  (AssociatedTypes [Vec AssociatedTypeDef])
  (Signatures [Vec MethodSig])
  Span}

{AssociatedTypeDef
  (Name TypeName)
  (Bounds [Vec TraitBound])
  (Default [Option TypeExpr])}

{MethodSig
  (Name MethodName)
  (GenericParams [Vec GenericParamDef])
  (Params [Vec Param])
  (ReturnType [Option TypeExpr])
  Span}

{TraitImplDef
  (Trait TraitName)
  (TraitArgs [Vec TypeExpr])
  (Type TypeExpr)
  (GenericParams [Vec GenericParamDef])
  (Methods [Vec MethodDef])
  (AssociatedTypes [Vec AssociatedTypeImpl])
  Span}

{AssociatedTypeImpl
  (Name TypeName)
  (Type TypeExpr)}

{MethodDef
  (Name MethodName)
  (GenericParams [Vec GenericParamDef])
  (Params [Vec Param])
  (ReturnType [Option TypeExpr])
  (Body MethodBody)
  Span}
```


## Root Level and Module

```aski
(RootChild
  (Module ModuleDef)
  (Enum EnumDef)
  (Struct StructDef)
  (Newtype NewtypeDef)
  (TraitDecl TraitDeclDef)
  (TraitImpl TraitImplDef)
  (Const ConstDef)
  (Ffi FfiDef)
  (Process Block))

{ModuleDef
  (Name TypeName)
  (Visibility Visibility)
  (Exports [Vec ExportItem])
  (Imports [Vec ModuleImport])
  Span}

(Visibility Public Private)

(ExportItem
  (Type TypeName)
  (Trait TraitName))

{ModuleImport
  (Source TypeName)
  (Names [Vec ImportItem])}

(ImportItem
  (Type TypeName)
  (Trait TraitName))

{EnumDef
  (Name TypeName)
  (Visibility Visibility)
  (GenericParams [Vec GenericParamDef])
  (Derives [Vec DeriveAttr])
  (Children [Vec EnumChild])
  Span}

(EnumChild
  {Variant (Name VariantName) Span}
  {DataVariant (Name VariantName) (Payload TypeExpr) Span}
  {StructVariant (Name VariantName) (Fields [Vec StructField]) Span}
  (NestedEnum EnumDef)
  (NestedStruct StructDef))

{StructDef
  (Name TypeName)
  (Visibility Visibility)
  (GenericParams [Vec GenericParamDef])
  (Derives [Vec DeriveAttr])
  (Children [Vec StructChild])
  Span}

(StructChild
  {TypedField (Name FieldName) (Visibility Visibility) (Type TypeExpr) Span}
  {SelfTypedField (Name FieldName) (Visibility Visibility) Span}
  (NestedEnum EnumDef)
  (NestedStruct StructDef))

{StructField
  (Name FieldName)
  (Visibility Visibility)
  (Type TypeExpr)
  Span}

{NewtypeDef
  (Name TypeName)
  (Visibility Visibility)
  (GenericParams [Vec GenericParamDef])
  (Derives [Vec DeriveAttr])
  (Wraps TypeExpr)
  Span}

{ConstDef
  (Name TypeName)
  (Visibility Visibility)
  (Type TypeExpr)
  (Value LiteralValue)
  Span}

(LiteralValue
  (Int I64)
  (Float F64)
  (Str String)
  (Bool Bool)
  (Char U32))

(DeriveAttr
  Debug Clone Copy PartialEq Eq PartialOrd Ord Hash Default
  RkyvArchive RkyvSerialize RkyvDeserialize)

{FfiDef
  (Library TypeName)
  (Functions [Vec FfiFunction])
  Span}

{FfiFunction
  (Name MethodName)
  (Params [Vec Param])
  (ReturnType [Option TypeExpr])
  Span}
```


## Key Changes from Current sema-core

| Area | Current | Proposed | Why |
|------|---------|----------|-----|
| Param | 5 variants | 7 variants | BorrowNamed, MutBorrowNamed for &T/&mut T params |
| TypeExpr | 5 variants | 18 variants | Ref, MutRef, Boxed, Tuple, Array, Slice, etc. |
| Expr | 22 variants | ~45 variants | Unary ops, PathVariantData, BoolLit, CastExpr, etc. |
| Pattern | 4 variants | 12 variants | IdentBind, TuplePattern, StructPattern, OrPattern, etc. |
| Statement | 7 variants | 10 variants | Let (with Pattern), While, ReturnUnit |
| EnumDef | no visibility/generics/derives | all three | semac needs them to emit correct Rust |
| StructDef | no visibility/generics/derives | all three | same |
| TraitDeclDef | no generics/supertraits | both | trait Foo<T>: Bar needs them |
| TraitImplDef | no generics/associated types | both | impl<T> Foo for Bar<T> needs them |
| MethodSig | no generics | has them | fn foo<T>() needs them |
| MethodDef | no generics | has them | same |
| MatchExpr | no guard | has guard | pattern if condition => needs it |
| Loop | condition Option | separate LoopExpr | while vs loop are different Rust |
