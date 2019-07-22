;;;; evaluator.lisp

(in-package :woo)

(defun inspect-object (node)
  (case (first node)
    ((:integer :boolean) (write-to-string (second node)))
    (:null "null")
    (:return-value (inspect-object (second node)))
    (:function (%inspect-function node))))

(defun %inspect-function (fun)
  (format t "fn(~{~A~^, ~}) {~%~A~%}"
          (second fun) (fourth fun)))

(defparameter +true-object+ '(:boolean t))
(defparameter +false-object+ '(:boolean nil))
(defparameter +null-object+ '(:null))

(defun evaluate (node env)
  (case (first node)
    (:program (evaluate-program node env))
    (:block-statement (evaluate-block-statement node env))
    (:expression-statement (evaluate (third node) env))
    (:return-statement (evaluate-return-statement node env))
    (:let-statement (evaluate-let-statement node env))
    (:integer-literal (list :integer (third node)))
    (:boolean-literal (list :boolean (third node)))
    (:prefix-expression (evaluate-prefix-expression node env))
    (:infix-expression (evaluate-infix-expression node env))
    (:if-expression (evaluate-if-expression node env))
    (:identifier (evaluate-identifier node env))
    (:function-literal (evaluate-function-literal node env))
    (t (error "Unknown ~A" (first node)))))

(defun evaluate-program (node env)
  (loop :for statement :in (second node)
        :for result := (evaluate statement env)
        :when (eq (first result) :return-value)
          :do (return (second result))
        :finally (return result)))

(defun evaluate-block-statement (node env)
  (loop :for statement :in (third node)
        :for result := (evaluate statement env)
        :when result
          :do (progn
                (let ((kind (first result)))
                  (when (or (eq kind :return-value)
                            (eq kind :error))
                    (return result))))
        :finally (return result)))

(defun evaluate-return-statement (node env)
  (let ((value (evaluate (third node) env)))
    (when value
      (list :return-value value))))

(defun evaluate-let-statement (node env)
  (let ((value (evaluate (fourth node) env)))
    (when value
      (set-in env (third (fourth node)) value))))

(defun evaluate-prefix-expression (node env)
  (let ((right (evaluate (fourth node) env))
        (operator (third node)))
    (alexandria:switch (operator :test #'equal)
      ("!" (evaluate-bang-operator-expression right))
      ("-" (evaluate-minus-prefix-operator-expression right))
      (t (error "Unknown operator ~A~A" operator right)))))

(defun evaluate-bang-operator-expression (right)
  (cond ((eq right +true-object+) +false-object+)
        ((eq right +false-object+) +true-object+)
        ((eq right +null-object+) +true-object+)
        (t +false-object+)))

(defun evaluate-minus-prefix-operator-expression (right)
  (let ((value (second right)))
    (list :integer (- value))))

(defun %from-native (b)
  (if b +true-object+ +false-object+))

(defun %truthyp (o)
  (case (first o)
    (:boolean (second o))
    (:null nil)
    (t t)))

(defun evaluate-infix-expression (node env)
  (let ((operator (third node))
        (left (evaluate (fourth node) env))
        (right (evaluate (fifth node) env)))
    (if (and (eq (first left) :integer)
             (eq (first right) :integer))
        (%evaluate-integer-infix-expression operator left right)
        (alexandria:switch (operator :test #'equal)
          ("==" (%from-native (equal left right)))
          ("!=" (%from-native (not (equal left right))))
          (t (error "Unknown operator ~A ~A ~A"
                    (first left) operator (first right)))))))

(defun %evaluate-integer-infix-expression (operator left right)
  (let ((left-value (second left))
        (right-value (second right)))
    ;; TODO: MACRO MAGIC
    (alexandria:switch (operator :test #'equal)
      ("+" (list :integer (+ left-value right-value)))
      ("-" (list :integer (- left-value right-value)))
      ("*" (list :integer (* left-value right-value)))
      ("/" (list :integer (/ left-value right-value)))
      ("<" (%from-native (< left-value right-value)))
      ("<=" (%from-native (<= left-value right-value)))
      (">=" (%from-native (>= left-value right-value)))
      (">" (%from-native (> left-value right-value)))
      ("==" (%from-native (= left-value right-value)))
      ("!=" (%from-native (/= left-value right-value)))
      (t (error "Unknown operator ~A ~A ~A"
                (first left) operator (first right))))))

(defun evaluate-if-expression (node env)
  (let ((condition (evaluate (third node) env)))
    (cond ((%truthyp condition)
           (evaluate (fourth node) env))
          ((not (null (fifth node)))
           (evaluate (fifth node) env))
          (t +null-object+))))

(defun evaluate-identifier (node env)
  (get-from env (third node)))

(defun evaluate-function-literal (node env)
  (let ((parameters (evaluate (third node) env)))
    (list :function parameters env (fourth node))))

(defun evaluate-call-expression (node env))

(defun %evaluate-expressions (expressions env)
  (loop :for expression :in expressions
        :for evaluated := (evaluate expression env)
        :collect evaluated :into result
        :finally (return result)))

(defun %extend-function-environment (function arguments)
  (loop :with environment := (make-symbol-table (third function))
        :for argument :in arguments
        :for parameter :in (second function)
        :do (set-symbol environment parameter argument)
        :finally (return environment)))

(defun %unwrap-return-value (o)
  (if (eq (first o) :return-value)
      (second o)
      o))

(defun %apply-function (function arguments)
  (let* ((extended-environment (%extend-function-environment function arguments))
         (result (evaluate (fourth function) extended-environment)))
    (%unwrap-return-value result)))
