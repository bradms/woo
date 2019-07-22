;;;; woo-test.asd

(defsystem woo-test
  :author "Brad Svercl <bradsvercl@gmail.com>"
  :license "MIT"
  :serial t
  :depends-on (:woo :fiveam)
  :pathname "t/"
  :components ((:file "package")
               (:file "environment")
               (:file "lexer")
               (:file "parser")))
