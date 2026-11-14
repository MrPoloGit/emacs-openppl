;;; openppl-ts-mode-tests.el --- ERT tests for openppl-ts-mode -*- lexical-binding: t; -*-

;; Run with:
;;   emacs -Q --batch -L .. -l openppl-ts-mode-tests.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'openppl-ts-mode)

(defconst openppl-ts-mode-tests--dir
  (file-name-directory (or load-file-name buffer-file-name)))
(defconst openppl-ts-mode-tests--corpus-file
  (expand-file-name "../../openppl/corpus/valid/operators.ohf" openppl-ts-mode-tests--dir))

(defun openppl-ts-mode-tests--face-at (needle)
  "Visit the corpus fixture, fontify it, and return the face at NEEDLE's
first character, found via `match-beginning', not hand-counted
`backward-char' arithmetic, which is exactly the kind of off-by-a-few
mistake this helper exists to rule out (one earlier draft of this test
file hit precisely that and reported a false negative)."
  (let ((buf (find-file-noselect openppl-ts-mode-tests--corpus-file)))
    (with-current-buffer buf
      (openppl-ts-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (search-forward needle)
      (get-text-property (match-beginning 0) 'face))))

(ert-deftest openppl-ts-mode-tests-mode-active ()
  (let ((buf (find-file-noselect openppl-ts-mode-tests--corpus-file)))
    (with-current-buffer buf
      (openppl-ts-mode)
      (should (eq major-mode 'openppl-ts-mode))
      (should (treesit-parser-list)))))

(ert-deftest openppl-ts-mode-tests-when-kw-gets-keyword-face ()
  (should (eq (openppl-ts-mode-tests--face-at "WHEN betround") 'font-lock-keyword-face)))

(ert-deftest openppl-ts-mode-tests-return-kw-gets-keyword-face ()
  (should (eq (openppl-ts-mode-tests--face-at "RETURN 47") 'font-lock-keyword-face)))

(ert-deftest openppl-ts-mode-tests-generic-identifier-gets-variable-face ()
  "A lowercase native-engine symbol (`betround') is still just an
`identifier' node to the grammar, no registry involved at the L0
layer, same split as tree-sitter-openppl/queries/highlights.scm."
  (should (eq (openppl-ts-mode-tests--face-at "betround = 2") 'font-lock-variable-name-face)))

(ert-deftest openppl-ts-mode-tests-action-field-gets-function-face ()
  "An `action_statement''s own `action' field (here, `Call') is
distinguished from a generic identifier structurally, with no registry
lookup needed for this distinction."
  (should (eq (openppl-ts-mode-tests--face-at "Call FORCE") 'font-lock-function-name-face)))

(ert-deftest openppl-ts-mode-tests-comparison-operator-gets-operator-face ()
  (should (eq (openppl-ts-mode-tests--face-at ">= 2") 'font-lock-operator-face)))

(ert-deftest openppl-ts-mode-tests-hand-expression-gets-string-face ()
  (should (eq (openppl-ts-mode-tests--face-at "hand$AA") 'font-lock-string-face)))

(ert-deftest openppl-ts-mode-tests-comment-gets-comment-face ()
  (should (eq (openppl-ts-mode-tests--face-at "// Calling") 'font-lock-comment-face)))

(ert-deftest openppl-ts-mode-tests-section-header-name-gets-constant-face ()
  (should (eq (openppl-ts-mode-tests--face-at "f$CardsLeft##") 'font-lock-constant-face)))

(ert-deftest openppl-ts-mode-tests-imenu-lists-every-section ()
  (let ((buf (find-file-noselect openppl-ts-mode-tests--corpus-file)))
    (with-current-buffer buf
      (openppl-ts-mode)
      (font-lock-ensure)
      (should (equal (mapcar #'car (cdr (assoc "Section" (funcall imenu-create-index-function))))
                      '("f$CardsLeft" "f$Outs" "f$preflop"))))))

(provide 'openppl-ts-mode-tests)
;;; openppl-ts-mode-tests.el ends here
