# Delimiter Budget — Per Dialect

## The Six Delimiter Pairs

```
()      Paren
[]      Bracket
{}      Brace
(| |)   ParenPipe
{| |}   BracePipe
[| |]   BracketPipe
```

## Root.synth — Top Level

```
()      Module (first), Enum, TraitDecl
[]      TraitImpl
{}      Struct
{| |}   Const
(| |)   FFI
[| |]   Process
(bare)  Newtype — PascalCase Type (undelimited)
```

ALL SIX USED. Newtype is the only undelimited root construct.


## Enum.synth — Inside (Enum ...)

```
()      data-carrying variant
{}      struct variant
[]      type application in variant payload
(| |)   nested enum definition
{| |}   nested struct definition
[| |]   free
```


## Struct.synth — Inside {Struct ...}

```
()      typed field
{}      (enclosing)
[]      type application in field type (via Type.synth)
(| |)   nested enum definition
{| |}   nested struct definition
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
{}      loop
{| |}   iteration
()      arguments (via Expr → ExprPostfix)
[]      inline eval (via Expr → ExprAtom)
(| |)   match (via Expr → ExprAtom)
[| |]   free
```


## ExprAtom.synth — Leaf expressions

```
[]      inline eval
{}      loop expression
{| |}   iteration expression
(| |)   match expression
()      free
[| |]   free
```


## Instance.synth / Mutation.synth

```
()      expression
[]      free
{}      free
{| |}   free
(| |)   free
[| |]   free
```
