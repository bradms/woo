;;;; evaluator.lisp

(in-package :woo)

(defun node-kind (node)
  (first node))

(defun inspect-object (node)
  (case (node-kind node)
    ((:integer :boolean) (write-to-string (second node)))
    (:null "null")
    (:return-value (inspect-object (second node)))
    (:function (format nil "fn(~{~A~^, ~}) {~%~A~%}"
                       (second node) (fourth node)))))

(defparameter +true-object+ '(:boolean t))
(defparameter +false-object+ '(:boolean nil))
(defparameter +null-object+ '(:null))

(defun evaluate (node env)
  (case (node-kind node)
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
    (:function-literal (evaluate-function-literal node env))))

(defun evaluate-program (node env)
  (loop :for statement :in (second node)
        :for result := (evaluate statement env)
        :when (node-kind= result :return-value)
          :do (return (second result))
        :finally (return result)))

(defun evaluate-block-statement (node env)
  (loop :for statement :in (third node)
        :for result := (evaluate statement env)
        :for kind := (node-kind result)
        :for return-value-p := (eq kind :return-value)
        :for errorp := (eq kind :error)
        :when (or return-value-p errorp)
          :do (loop-finish)
        :finally (return result)))

(defun evaluate-return-statement (node env)
  (when-let (value (evaluate (third node) env))
    (list :return-value value)))

(defun evaluate-let-statement (node env)
  (when-let (value (evaluate (fourth node) env))
    (let ((name (token-literal (second (third node)))))
      (set-in env name value))))

(defun evaluate-prefix-expression (node env)
  (let ((right (evaluate (fourth node) env))
        (operator (third node)))
    (switch (operator :test #'equal)
      ("!" (evaluate-bang-operator-expression right))
      ("-" (evaluate-minus-prefix-operator-expression right))
      (t (error "Unknown operator ~A~A" operator right)))))

(defun evaluate-bang-operator-expression (right)
  (switch (right :test #'equal)
    (+true-object+ +false-object+)
    (+false-object+ +true-object+)
    (+null-object+ +true-object+)
    (t +false-object+)))

(defun evaluate-minus-prefix-operator-expression (right)
  (let ((value (second right)))
    (list :integer (- value))))

(defun %from-native (test)
  (if test +true-object+ +false-object+))

(defun %truthyp (node)
  (case (node-kind node)
    (:boolean (second node))
    (:null nil)
    (t t)))

(defun node-kind= (node kind)
  (eq (node-kind node) kind))

(defun %both-equal-to (left right kind)
  (and (node-kind= left kind)
       (node-kind= right kind)))

(defun evaluate-infix-expression (node env)
  (let ((operator (third node))
        (left (evaluate (fourth node) env))
        (right (evaluate (fifth node) env)))
    (if (%both-equal-to left right :integer)
        (%evaluate-integer-infix-expression operator left right)
        (switch (operator :test #'equal)
          ("==" (%from-native (equal left right)))
          ("!=" (%from-native (not (equal left right))))
          (t (error "Unknown operator ~A ~A ~A"
                    (node-kind left) operator (node-kind right)))))))

(defun %evaluate-integer-infix-expression (operator left right)
  (let ((left-value (second left))
        (right-value (second right)))
    (macrolet ((make-operator (op &optional bool)
                 `(let ((fun (symbol-function ,op)))
                    (if ,bool
                        (%from-native (funcall fun left-value right-value))
                        (list :integer (funcall fun left-value right-value))))))
      (switch (operator :test #'equal)
        ("+" (make-operator '+))
        ("-" (make-operator '-))
        ("*" (make-operator '*))
        ("/" (make-operator '/))
        ("<" (make-operator '< t))
        ("<=" (make-operator '<= t))
        (">" (make-operator '> t))
        ("==" (make-operator '= t))
        ("!=" (make-operator '/= t))
        (t (error "Unknown operator ~A ~A ~A"
                  (first left) operator (first right)))))))

(defun evaluate-if-expression (node env)
  (let ((condition (evaluate (third node) env)))
    (cond ((%truthyp condition)
           (evaluate (fourth node) env))
          ((fifth node)
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

(defun %extend-function-environment (fun arguments)
  (loop :with environment := (make-environment (third fun))
        :with parameters := (second fun)
        :for argument :in arguments
        :for parameter :in parameters
        :do (set-in environment parameter argument)
        :finally (return environment)))

(defun %unwrap-return-value (node)
  (if (node-kind= node :return-value)
      (second node)
      node))

(defun %apply-function (function arguments)
  (let* ((extended-environment (%extend-function-environment function arguments))
         (result (evaluate (fourth function) extended-environment)))
    (%unwrap-return-value result)))
