# emacs-openppl

Emacs support for OpenPPL (`.ohf`), built after VS Code, Neovim, Vim and
Zed already existed for this language, the same editor-parity goal
`emacs-phh/README.md` describes. Reuses
`tree-sitter-openppl`'s compiled grammar and `openppl-ls` over `eglot`.

## Install

```elisp
(add-to-list 'load-path "/path/to/emacs-openppl")
(require 'openppl-ts-mode)
(setq openppl-ts-mode-registry-path "/path/to/openppl/registry") ; required
```

## What's implemented (L0, highlighting)

- `.ohf` → `openppl-ts-mode` via `auto-mode-alist`.
- Highlighting ported from `tree-sitter-openppl/queries/highlights.scm`
  (same capture-rewrite discipline as `emacs-phh`/`emacs-ohh`). One
  thing carried over verbatim because it cost real debugging time once
  already and would cost it again here, left as a comment in
  `openppl-ts-mode.el`: OpenPPL's keywords (`WHEN`, `FORCE`, ...) are
  matched by **rule name** (`when_kw`, `force_kw`, ...), never by
  literal string text, the grammar's `caseInsensitive` helper means a
  pattern written as `"WHEN" @font-lock-keyword-face` would compile
  without error and silently match nothing at all.
- Deliberately **no symbol-registry-specific highlighting**, every
  plain identifier gets one generic `font-lock-variable-name-face`,
  same split as `tree-sitter-openppl/queries/highlights.scm` itself
  draws: the one *structural* exception (not a registry lookup) is an
  `action_statement`'s own `action` field, which gets
  `font-lock-function-name-face` because the grammar can identify
  *that one position* as an action slot regardless of whether the name
  turns out to be a real registered action, real "is this actually a
  known action/symbol" checking is `openppl-ls`'s job (hover,
  diagnostics), not the grammar's.
- **Imenu** lists one entry per `##name##` section header, the
  natural jump target in a profile, labeled by the section's own name
  text (`f$preflop`, `list007`, ...).

**Grammar binary is bundled**, macOS arm64 only, same provenance and
caveat as `emacs-phh`/`emacs-ohh`: `parser/libtree-sitter-openppl.dylib`
is `nvim-openppl/parser/openppl.so`, renamed and re-confirmed to load.

## What's implemented (L1, diagnostics, hover, completion)

Same function-contact `eglot-server-programs` pattern as the other two
packages. `openppl-ls` needs a registry directory as its first CLI
argument (it has no built-in default, same "never approximate
silently" rule as PHH/OHH). **Not independently confirmed**: a live
interactive `eglot` handshake.

## How this was verified

`test/openppl-ts-mode-tests.el` (ERT) checks real faces at real
corpus positions in `openppl/corpus/valid/operators.ohf`, `WHEN`/
`RETURN` keywords, a generic lowercase identifier (`betround`, a native
OpenHoldem engine symbol this registry deliberately doesn't cover, see `openppl/registry/README.md`), an action-field identifier (`Call`),
a comparison operator, a `hand$AA` expression, a comment, and a section
header's name, plus the Imenu section list. **All 10 checks pass.**
Byte-compiles with zero warnings.

Found the hard way, worth repeating here too: positions were located
via `search-forward` + `(match-beginning 0)`. A first draft of this
test file used hand-counted `backward-char` offsets for a couple of
checks, miscounted one, and got a false failure on `WHEN` that had
nothing to do with the mode, fixed by switching every check in this
file to the `match-beginning` helper instead of trusting arithmetic.
