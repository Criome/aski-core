# Delimiter Budget — Per Dialect

## The Six Delimiter Pairs

```
()      Paren           Solar     — identity, objects
[]      Bracket         Lunar     — reflection, cycling
{}      Brace           Saturnian — structure, boundary

(| |)   ParenPipe       Solar     — match (pattern on identity)
[| |]   BracketPipe     Lunar     — loop (cyclical)
{| |}   BracePipe       Saturnian — iteration (structured traversal)
```

## Root.synth — Top Level

```
()      Module (first), Enum, TraitDecl
[]      TraitImpl
{}      Struct
{| |}   Const
(| |)   FFI
[| |]   Process (entry point)
(bare)  Newtype — PascalCase Type (undelimited)
```

ALL SIX USED.


## Enum.synth — Inside (Enum ...)

```
()      data-carrying variant
{}      struct-form variant
[]      type application in variant payload
(| |)   nested enum
{| |}   nested struct
[| |]   free
```


## Struct.synth — Inside {Struct ...}

```
()      typed field
{}      (enclosing)
[]      type application in field type (via Type.synth)
(| |)   nested enum
{| |}   nested struct
[| |]   free
```


## Type.synth — Type expressions

```
[]      type application: [Vec Element]
$       dispatches to GenericParam.synth
@[]     instance of applied type
(bare)  simple type reference
```


## TraitDecl.synth — Inside (trait ...)

```
()      signature
[]      signature block
{}      free
{| |}   free
(| |)   free
[| |]   free
```


## TraitImpl.synth — Inside [trait ...]

```
[]      type impl block
()      free
{}      free
{| |}   free
(| |)   free
[| |]   free
```


## Signature.synth / Param.synth

```
(all)   free — params are sigil-driven
```


## Method.synth — Inside (method ...)

```
[]      body (block)
(| |)   match body
[| |]   tail block
()      free
{}      free
{| |}   free
```


## Statement.synth — Inside body

```
()      local type declaration: (Counter U32), (Names [Vec String])
[| |]   loop
{| |}   iteration
^       early return (sigil)
~@      mutation (sigil)
@       instance (sigil)
```

Via Expr fallthrough:
```
[]      inline eval (ExprAtom)
{}      struct construction (ExprAtom)
(| |)   match (ExprAtom)
[| |]   loop expression (ExprAtom)
{| |}   iteration expression (ExprAtom)
```


## ExprAtom.synth — Leaf expressions

```
[]      inline eval
{}      struct construction
[| |]   loop expression
{| |}   iteration expression
(| |)   match expression
()      free
```


## Instance.synth

```
()      optional type annotation: @Name (Type) Expr
```
