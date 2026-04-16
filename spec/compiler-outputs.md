# Sema Engine — Architecture

## Sema Is the Thing

Sema is a universal typed binary format — the canonical
representation. No strings. No unsized data. Domain variants
as bytes. Everything else is a projection.

**Only semac produces sema.** Everything upstream (askicc,
askic) produces rkyv-serialized data that still has strings.
It becomes sema when semac resolves all strings to domain
variants. If it has unsized data, it is not sema.

Aski is one text notation for specifying sema. It leverages
existing text-based programming infrastructure (editors,
compilers, terminals) as a pragmatic bootstrap path.

Eventually aski will be replaced by better ways to represent
sema for human consumption.


## The Pipeline

```
corec     — .aski → Rust with rkyv derives (the bootstrap tool)
aski-core — grammar .aski + corec → Rust rkyv types (askicc↔askic contract)
sema-core — parse tree .aski + corec → Rust rkyv types (askic↔semac contract)
askicc    — uses aski-core types → rkyv dialect-data-tree (embedded in askic)
askic     — uses aski-core (input) + sema-core (output), embeds askicc's rkyv
semac     — uses sema-core types only, independent of aski
```

Six repos. They communicate through files.
Only corec and semac generate Rust. Only semac produces true
sema.


## corec — The Bootstrap Tool

A binary that reads .aski files and generates Rust types with
rkyv derives. The bootstrap seed — one of only two tools that
generate Rust (the other is semac). Used by both aski-core and
sema-core.


## aski-core — The askicc/askic rkyv Contract

aski-core defines every type that appears in the rkyv message
between askicc and askic. The .aski files are the source of
truth. corec generates Rust with rkyv derives from them. Both
askicc (serializer) and askic (deserializer) depend on corec's
output.

```
aski-core (.aski)  ──corec──→  Rust rkyv types
                                     │
                         ┌───────────┴───────────┐
                         ▼                       ▼
                      askicc                   askic
                   (serializes)            (deserializes)
```

This includes:
- Classification types: NameDomain, Operator, ScopeKind, Visibility
- Structure types: Span
- Grammar types: Dialect, Rule, Alternative, Item, ItemContent,
  Cardinality, DelimKind, DialectKind, Sigil

All defined in .aski. All generated to Rust with rkyv derives
by corec.


## sema-core — The askic/semac rkyv Contract

sema-core defines every type that appears in the rkyv message
between askic and semac. The .aski files are the source of
truth. corec generates Rust with rkyv derives from them. askic
(serializer) and semac (deserializer) depend on corec's output.

```
sema-core (.aski)  ──corec──→  Rust rkyv types
                                     │
                         ┌───────────┴───────────┐
                         ▼                       ▼
                       askic                   semac
                   (serializes)            (deserializes)
```

This includes parse tree types — the structured output that
askic produces and semac consumes. semac depends only on
sema-core, NOT on aski-core.


## askicc — Bootstrap Compiler

A binary that reads .synth dialect files, populates a
domain-data-tree of aski-core types, and serializes it as
rkyv using corec's generated types. This rkyv data gets embedded
in the askic binary at build time, giving askic the ability
to read that version of aski's grammar.

**askicc does NOT generate Rust.** It produces rkyv data.

The populated tree captures all grammar knowledge that askic
needs: what tokens to match, in what order, with what
adjacency, using what delimiters, with what cardinality.
The domain-data-tree IS the state machine.


## askic — The Aski Frontend

A binary that reads .aski source and produces an rkyv parse
tree. askic contains NO language-specific parsing logic.
It is a generic dialect engine.

askicc's rkyv domain-data-tree is embedded in askic at build
time. The engine executes the embedded grammar as a
dialect-based state machine against the token stream.

askic depends on corec's generated types from aski-core to
deserialize the embedded rkyv — the same types askicc used to
serialize it. aski-core is the input contract. askic serializes
its parse tree output using sema-core types — the contract
that semac reads.

Adding new syntax = adding .synth files + .aski domain
definitions in aski-core, then rebuilding corec, askicc, and
askic. No askic code changes.

askic's output is rkyv — it has strings (user names,
literals). It is NOT sema.


## semac — The Sema Backend

A binary that reads rkyv parse trees using sema-core types
and produces true sema + Rust source. Independent of askic
and aski-core. Any tool that produces valid rkyv parse trees
(using sema-core types) can feed semac.

Produces:
1. **.sema** — true sema binary (no strings, fixed-size)
2. **module.rs** — Rust codegen (the compilation target)
3. **module.aski-table.sema** — name projection for tooling

semac is permanent. askic is one frontend that may be replaced.

This is where strings become domain variants. This is where
unsized data becomes fixed-size. This is where rkyv becomes
sema.


## .sema — The Interface

The .sema file is the canonical artifact.

- semac produces it (from rkyv parse trees)
- The criome runtime consumes it directly
- Future tools consume it for analysis, display, etc.

.sema is pure binary. Domain variants as bytes. rkyv
zero-copy, mmap-ready, deterministic. No strings.

The .aski-table.sema is a name projection — maps domain
variants back to human-readable names. It is NOT part of
.sema itself. It's a separate file for tooling.


## Repo Structure

```
corec        — .aski → Rust with rkyv derives (bootstrap tool, lives in aski-core)
aski-core    — grammar .aski files (askicc↔askic contract)
sema-core    — parse tree .aski files (askic↔semac contract)
askicc       — .synth dialect files + binary (produces rkyv using aski-core types)
askic        — dialect state machine (aski-core input, sema-core output)
semac        — sema backend (uses sema-core types, produces sema + Rust)
sema         — Nix aggregator
aski         — language spec
```

### Nix Build

```
aski-core/flake.nix  — builds corec, runs corec on .aski → Rust types
sema-core/flake.nix  — inputs corec, runs corec on .aski → Rust types
askicc/flake.nix     — inputs aski-core, builds askicc, runs askicc on .synth → rkyv
askic/flake.nix      — inputs aski-core + sema-core + askicc rkyv, builds askic
semac/flake.nix      — inputs sema-core only (no aski-core dependency)
sema/flake.nix       — aggregator, nix flake check runs all
```


## Advantages

**Sema survives aski.** When better notations exist, they
feed semac through rkyv parse trees. semac doesn't change.

**Frontend independence.** askic and semac communicate through
sema-core's rkyv types only. semac has no aski-core dependency.
Replace the frontend without touching the backend.

**Grammar is data.** askic has no compiled-in language knowledge.
The grammar lives in askicc's rkyv data-tree, not in code.
Adding syntax means adding .synth files, not editing a parser.

**Only two Rust generators.** corec (bootstrap) and semac (target).
Everything between them is pure data flow.

**Each stage makes the next elegant.** corec makes aski-core and
sema-core possible. aski-core makes askicc possible.
askicc's data-tree makes askic generic. askic's parse tree
makes semac straightforward.
