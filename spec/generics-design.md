# Generics in Aski — Design

## Core Principles

1. **Names are meaningful.** No pointer names like T, X, A, B. The
   name describes what the thing IS.

2. **Two different things have different names.** `$Left` and `$Right`
   are different even if they share qualities. Name IS identity.

3. **Bounds ARE names.** `$Clone&Debug` — the constraints identify
   the parameter. No separate name + bounds.

4. **Everything is structured.** No opaque strings, no engine escapes.
   Types are synth-driven, producing structured nodes.

5. **Delimiter-first.** Type application is `[Constructor Arg]`, not
   `Constructor<Arg>`. `<>` is not an aski delimiter.

6. **We compile to Rust.** No higher-kinded types. Kinds are implicit
   (count $ slots in a definition).

7. **Everything synth-driven.** Types have their own dialect (Type.synth).


## What Type Parameters ARE

A type parameter is a **type-level function argument**. A type
constructor (Vec, Option, Result) is a function from types to types.
Application yields a concrete type.

In aski, the parameter's name describes its semantic role. There are
no meaningless placeholder variables.


## Type Syntax

### Simple type

```aski
Element                      ;; a bare type name
U32                          ;; a primitive
```

### Type application — [] delimiter

```aski
[Vec Element]                ;; Vec applied to Element
[Option Element]             ;; Option applied to Element
[Result Element String]      ;; two parameters
[Vec [Option Element]]       ;; nested
[Map String [Vec Element]]   ;; composed
```

### Instance of applied type — @[]

```aski
@[Vec Element]               ;; instance of Vec of Element
@[Vec $Clone&Debug]          ;; instance of Vec of generic param
```

### Type parameter — $ sigil

```aski
$Value                       ;; bare named slot
$Clone&Debug                 ;; bounded — bounds ARE the name
$Clone&Debug&Display         ;; multiple bounds
```

### Reference to type parameter — @

```aski
@Clone&Debug                 ;; reference to the $Clone&Debug param
```


## Enum Definitions with Parameters

### One parameter

```rust
enum Option<T> { Some(T), None }
```

```aski
(Option (Some $Value) None)
```

### Two parameters (different roles)

```rust
enum Result<T, E> { Ok(T), Err(E) }
```

```aski
(Result (Ok $Output) (Err $Failure))
```

### Two parameters (same quality, different identity)

```rust
struct Pair<A, B> { left: A, right: B }
```

```aski
{Pair (LeftValue $LeftValue) (RightValue $RightValue)}
```


## Struct Fields

### Typed field — () delimiter

```aski
{Container (Items [Vec Item]) (Count U32)}
```

### Self-typed field — bare name (encouraged)

```aski
{Drawing (Shapes [Vec Shape]) Name}
```

`Name` is self-typed: field name IS the type.


## Recursive Nesting

### Nested enum inside domain or struct — (| |)

```aski
(Shape
  (Circle F64)
  (Compound [Vec Shape])
  (| Status Active Inactive Done |))
```

### Nested struct inside domain or struct — {| |}

```aski
{Drawing
  (Shapes [Vec Shape])
  Name
  {| Config (Timeout U32) (Retries U32) |}}
```


## Synth Dialects

### Type.synth (NEW)

```synth
;; instance of applied type: @[Vec Element], @[Vec $Clone&Debug]
// _@_[<TypeApplication>]

;; applied type: [Vec Element], [Option $Value]
// [<TypeApplication>]

;; type parameter: $Value, $Clone&Debug
// _$_<GenericParam>

;; simple type reference: Element, U32
// @Type
```

### TypeApplication.synth (NEW)

```synth
@Constructor +<Type>
```

### GenericParam.synth (NEW)

```synth
;; bounded: $Clone&Debug
// @Bound +(_&_ @Bound)

;; bare: $Value
// @Param
```


## aski-core Updates

### node.aski — new node kinds

```
TypeApplication      ;; [Vec Item] — constructor applied to args
TypeParam            ;; $Value — a named type slot
BoundedParam         ;; $Clone&Debug — slot where bounds are name
TypeParamRef         ;; @Clone&Debug — reference to declared param
SimpleType           ;; Element, U32 — a bare type name
NestedDomain         ;; (| ... |) — domain inside domain/struct
NestedStruct         ;; {| ... |} — struct inside domain/struct
```

### name.aski — new name domain

```
TypeParamName        ;; identity of a type parameter
```


## Kinds (Implicit)

Kind is inferred from the enum definition:

```aski
(Option (Some $Value) None)            ;; 1 slot: Type -> Type
(Result (Ok $Output) (Err $Failure))   ;; 2 slots: Type -> Type -> Type
(Element Fire Earth Air Water)          ;; 0 slots: Type (concrete)
```

No explicit kind annotations needed.
