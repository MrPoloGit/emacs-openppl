;;; openppl-ts-mode.el --- Tree-sitter major mode for OpenPPL -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; Emacs support for OpenPPL (.ohf), built with the same editor-parity
;; discipline as emacs-phh/phh-ts-mode.el and
;; emacs-ohh/ohh-ts-mode.el: the tree-sitter-openppl grammar (copied
;; verbatim from nvim-openppl/parser/openppl.so, renamed to Emacs's own
;; `libtree-sitter-LANG.<ext>' convention) for highlighting, plus
;; `eglot' + openppl-ls (which now needs a REGISTRY-DIR argument, see
;; `openppl-ts-mode-registry-path') for diagnostics/hover/completion.
;;
;; Node patterns are ported from tree-sitter-openppl/queries/highlights.scm,
;; capture names rewritten to Emacs's own `font-lock-*-face' names (same
;; non-mechanical sync discipline as the other two emacs-* packages). One
;; thing carried over verbatim from that file's own warning, because it
;; cost real debugging time there and would cost it again here: OpenPPL's
;; keywords (WHEN, FORCE, SET, ...) are matched by RULE NAME
;; (`when_kw' etc.), never by literal string text, the grammar's
;; `caseInsensitive' helper means a literal `"WHEN"' pattern silently
;; matches nothing at all.

;;; Code:

(require 'treesit)
(require 'eglot)

(defgroup openppl nil
  "Major mode for OpenPPL bot profiles."
  :group 'languages)

(defcustom openppl-ts-mode-server-program "openppl-ls"
  "Path to the openppl-ls executable."
  :type 'string
  :group 'openppl)

(defcustom openppl-ts-mode-registry-path nil
  "Path to the openppl/registry directory.

openppl-ls requires this as its first CLI argument (it has no built-in
default, same \"never approximate silently\" reasoning as
`phh-ts-mode-registry-path'/`ohh-ts-mode-registry-path'). You must set
this before `openppl-ts-mode' will start the language server."
  :type '(choice (const nil) string)
  :group 'openppl)

;; See emacs-phh/phh-ts-mode.el's `phh-ts-mode--source-directory' comment.
(defconst openppl-ts-mode--source-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory this file was loaded from.")

;;;###autoload
(defun openppl-ts-mode-register-grammar ()
  "Add this package's bundled grammar to `treesit-extra-load-path'.

Only a macOS arm64 binary is bundled (same single-platform caveat as
nvim-openppl/README.md's parser/openppl.so). On another platform,
rebuild tree-sitter-openppl and point `treesit-extra-load-path' at the
result."
  (add-to-list 'treesit-extra-load-path
               (expand-file-name "parser" openppl-ts-mode--source-directory)))

(defvar openppl-ts-mode--font-lock-rules
  (treesit-font-lock-rules
   :language 'openppl
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'openppl
   :feature 'section
   '("##" @font-lock-misc-punctuation-face
     (section_header name: (identifier) @font-lock-constant-face))

   :language 'openppl
   :feature 'keyword
   '([(when_kw) (force_kw) (set_kw) (return_kw)] @font-lock-keyword-face
     [(and_kw) (or_kw) (xor_kw) (not_kw) (mod_kw)] @font-lock-keyword-face
     (board_expression (suited_kw) @font-lock-keyword-face))

   :language 'openppl
   :feature 'constant
   '((number) @font-lock-number-face
     (percentage) @font-lock-number-face
     (hand_expression) @font-lock-string-face
     (board_expression) @font-lock-string-face
     (hand_range) @font-lock-constant-face)

   :language 'openppl
   :feature 'punctuation
   '(["=" "!=" "<=" ">=" "<" ">" "~~" "+" "-" "*" "/"] @font-lock-operator-face
     ["(" ")"] @font-lock-bracket-face)

   ;; The registry-backed distinction between a real action name and an
   ;; ordinary symbol reference lives in openppl-ls (hover/completion),
   ;; not here, a query has no registry to check against, same split
   ;; tree-sitter-openppl/queries/highlights.scm's own header note
   ;; explains (it calls every identifier `@variable' uniformly except
   ;; the one syntactic case below, which needs no registry at all: an
   ;; `action_statement''s own `action' field is structurally
   ;; identifiable regardless of whether the name turns out to be a
   ;; known action).
   :language 'openppl
   :feature 'identifier
   '((action_statement action: (identifier) @font-lock-function-name-face)
     (identifier) @font-lock-variable-name-face))
  "Font-lock rules for `openppl-ts-mode'.")

(defun openppl-ts-mode--imenu-section-name (node)
  "Return a `section_header' NODE's own name text, for Imenu's label."
  (treesit-node-text (treesit-node-child-by-field-name node "name") t))

(defvar openppl-ts-mode--imenu-settings
  `(("Section" ,(rx bos "section_header" eos) nil openppl-ts-mode--imenu-section-name))
  "Imenu entries: one per `##name##' section header, the most useful
jump target in a profile, mirroring every other editor's `outline'
query purpose in this project.")

;;;###autoload
(define-derived-mode openppl-ts-mode prog-mode "OpenPPL"
  "Major mode for OpenPPL (.ohf) bot profiles."
  :group 'openppl
  (openppl-ts-mode-register-grammar)
  (when (treesit-ready-p 'openppl)
    (setq-local treesit-primary-parser (treesit-parser-create 'openppl))
    (setq-local treesit-font-lock-settings openppl-ts-mode--font-lock-rules)
    (setq-local treesit-font-lock-feature-list
                '((comment section keyword)
                  (constant identifier)
                  (punctuation)
                  ()))
    (setq-local treesit-simple-imenu-settings openppl-ts-mode--imenu-settings)
    (setq-local comment-start "// ")
    (setq-local comment-end "")
    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ohf\\'" . openppl-ts-mode))

(defun openppl-ts-mode--eglot-contact (_interactive _project)
  "Build openppl-ls's eglot CONTACT; see `phh-ts-mode--eglot-contact'."
  (unless openppl-ts-mode-registry-path
    (user-error "openppl-ts-mode: set `openppl-ts-mode-registry-path' before starting eglot"))
  (list openppl-ts-mode-server-program openppl-ts-mode-registry-path))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(openppl-ts-mode . openppl-ts-mode--eglot-contact)))

(provide 'openppl-ts-mode)
;;; openppl-ts-mode.el ends here
