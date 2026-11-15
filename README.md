# emacs-openppl

Emacs support for OpenPPL (`.ohf`), uses
`tree-sitter-openppl`'s compiled grammar and `openppl-ls` over `eglot`.

## Install

```elisp
(add-to-list 'load-path "/path/to/emacs-openppl")
(require 'openppl-ts-mode)
(setq openppl-ts-mode-registry-path "/path/to/openppl-data/registry") ; required
```

**Not published to MELPA (or any other package archive).** This repo
is pushed to `github.com/MrPoloGit/emacs-openppl`, usable today via
`straight.el`/`use-package :vc`/`package-vc-install` pointing at that
URL, or the manual `load-path` above, but it hasn't been submitted to
MELPA, nothing has an MELPA recipe yet.
