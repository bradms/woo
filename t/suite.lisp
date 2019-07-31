;;;; suite.lisp

(in-package :woo-test)

(def-suite woo)

(def-suite woo-environment :in woo)
(def-suite woo-lexer :in woo)
(def-suite woo-parser :in woo)
(def-suite woo-evaluator :in woo)

(defun run-all ()
  (run! 'woo))
