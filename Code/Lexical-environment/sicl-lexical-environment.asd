(cl:in-package #:asdf-user)

(defsystem #:sicl-lexical-environment
  :depends-on (#:trucler
               #:trucler-reference)
  :serial t
  :components
  ((:file "packages")
   (:file "generic-function-description")))

