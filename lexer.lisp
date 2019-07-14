;;;; lexer.lisp

(in-package :woo)

(defparameter *builtins*
  (dict "fn" :fn
        "elif" :elif
        "else" :else
        "t" :t
        "nil" :nil
        "let" :let
        "return" :return))

;; TODO: Multi characater tokens like == /= && ||
(defparameter *simple-tokens*
  (dict #\+ :plus
        #\- :minus
        #\* :star
        #\/ :slash
        #\= :assign
        #\! :bang
        #\< :less-than
        #\> :greater-than
        #\( :left-paren
        #\) :right-paren
        #\{ :left-brace
        #\} :right-brace
        #\[ :left-bracket
        #\] :right-bracket
        #\% :percent
        #\^ :caret
        #\~ :tilde
        #\: :colon
        #\' :quote
        #\; :semicolon
        #\& :ampersand
        #\# :hash
        #\Nul :eof)
  "single character tokens")

(defclass lexer ()
  ((text :initarg :text :reader text)
   (pos :initform 0 :reader pos)
   (rpos :initform 0 :reader rpos)
   (ch :initform nil :reader ch)))

(defmethod print-object ((lexer lexer) stream)
  (print-unreadable-object (lexer stream)
    (format stream "~A~%(~A,~A)"
            (text lexer)
            (pos lexer)
            (ch lexer))))

(defun make-lexer (text)
  (make-instance 'lexer :text text))

(defmethod next ((lexer lexer))
  "Get the next token"
  (labels ((char-at (where)
             "Return the character at WHERE otherwise the null character."
             (handler-case
                 (char (text lexer) where)
               (error (c)
                 (declare (ignore c))
                 #\Nul)))
           (advance ()
             (with-slots (pos rpos ch) lexer
               (setf ch (char-at rpos)
                     pos rpos)
               (incf rpos)))
           (peek ()
             "Return the character at RPOS without advancing."
             (char-at (rpos lexer)))
           (read-while (pred)
             "Advance and collect the current character while PRED holds."
             (loop for current = (ch lexer)
                   while (funcall pred current)
                   do (advance)
                   collect current into chars
                   finally (return (concatenate 'string chars))))
           (read-identifier ()
             (read-while #'alphanumericp))
           ;; TODO: This doesn't handle hex or anything else.
           (read-number ()
             (read-while #'digit-char-p))
           ;; TODO: This should have a better name.
           (lookup-identifier (ident)
             (gethash ident *builtins* :identifier))
           (token (kind lit &optional (eat t))
             "Return a token of KIND and LIT, and maybe EAT (advance)."
             (prog1 (make-token kind lit)
               (when eat
                 (advance)))))
    ;; skip over whitespace
    (loop for current = (ch lexer)
          while (or (null current) ; only initially
                    (whitespacep current))
          do (advance))
    (let ((current (ch lexer)))
      ;; simple tokens first
      (when-let (kind (gethash current *simple-tokens*))
        ;; get me outta here!
        (return-from next
          (token kind (string current))))
      (cond ((digit-char-p current)
             (token :number (read-number) nil))
            ((alpha-char-p current)
             (let ((ident (read-identifier)))
               (token (lookup-identifier ident) ident nil)))
            ;; end-of-file or end-of-input, whatever
            (t (token :illegal "illegal"))))))
