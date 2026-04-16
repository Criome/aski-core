# Aski — Integration into Criome NixOS

## What this repo provides

Three Nix packages via flake:

- `aski` — Rust library: parser (logos+chumsky), CozoDB storage, Rust codegen
- `tree-sitter-aski` — Tree-sitter grammar: parser.so, highlights.scm, indents.scm, locals.scm
- `aski-mode` — Emacs major mode for .aski files

## Flake input

```nix
inputs.aski = {
  url = "github:Criome/aski";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## Tree-sitter grammar

The grammar needs to be registered with tree-sitter in the NixOS/home-manager config.

### For Emacs with tree-sitter support:

```nix
{ inputs, pkgs, ... }:
let
  ts-aski = inputs.aski.packages.${pkgs.system}.tree-sitter-aski;
in {
  # The parser.so goes where Emacs can find it
  # Exact path depends on your Emacs tree-sitter configuration
  home.file.".local/share/tree-sitter/aski/parser.so".source = "${ts-aski}/lib/parser.so";
  home.file.".local/share/tree-sitter/aski/highlights.scm".source = "${ts-aski}/queries/highlights.scm";
  home.file.".local/share/tree-sitter/aski/indents.scm".source = "${ts-aski}/queries/indents.scm";
  home.file.".local/share/tree-sitter/aski/locals.scm".source = "${ts-aski}/queries/locals.scm";
}
```

### For Neovim:

```nix
programs.neovim.plugins = [{
  plugin = pkgs.vimPlugins.nvim-treesitter;
  config = ''
    -- Register aski parser
    local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
    parser_config.aski = {
      install_info = {
        url = "${inputs.aski.packages.${pkgs.system}.tree-sitter-aski}/grammar",
        files = {"parser.c"},
      },
      filetype = "aski",
    }
    vim.filetype.add({ extension = { aski = "aski" } })
  '';
}];
```

### For Helix:

```nix
# In languages.toml or via home-manager
xdg.configFile."helix/languages.toml".text = ''
  [[language]]
  name = "aski"
  scope = "source.aski"
  file-types = ["aski"]
  comment-token = ";;"
  indent = { tab-width = 2, unit = "  " }

  [language.grammar]
  path = "${inputs.aski.packages.${pkgs.system}.tree-sitter-aski}/grammar"
'';

# Copy queries
xdg.configFile."helix/runtime/queries/aski".source = "${inputs.aski.packages.${pkgs.system}.tree-sitter-aski}/queries";
```

## Emacs major mode (regex-based, no tree-sitter needed)

```nix
programs.emacs.extraPackages = epkgs: [
  inputs.aski.packages.${pkgs.system}.aski-mode
];
```

This gives you `aski-mode` auto-activated on `.aski` files with:
- Comment handling (`;;`)
- String highlighting
- PascalCase types, camelCase functions
- `@instance` refs, `:borrow`, `~mut`, `!const`, `^return`, `#contract`
- Paren matching
- `___` stub warnings

## Dev shell

For working on aski itself:

```bash
nix develop github:Criome/aski
# Provides: rust toolchain, tree-sitter, nodejs, rust-analyzer
```

## File associations

Register `.aski` files across the system:

```nix
# MIME type
xdg.mimeApps.defaultApplications."text/x-aski" = "emacs.desktop";

# Or in shared-mime-info
environment.etc."shared-mime-info/packages/aski.xml".text = ''
  <?xml version="1.0" encoding="UTF-8"?>
  <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="text/x-aski">
      <comment>Aski source</comment>
      <glob pattern="*.aski"/>
    </mime-type>
  </mime-info>
'';
```

## What .aski files look like

```aski
;; Domains — solar ()
Element (Fire Earth Air Water)

;; Structs — saturnian {}
Point { X F64 Y F64 }

;; Functions — lunar body []
add(@Addition) U32 [
  ^(@Addition.Left + @Addition.Right)
]

;; Pattern matching — (| |)
^(| @Element
  (Fire)  "passionate"
  (Earth) "grounded"
  (_)     "other"
|)

;; Entry point
Main [
  StdOut "hello aski"
]
```
