(cl:in-package #:sicl-boot-phase-5)

(defun enable-defmethod (e5)
  (load-source-file "CLOS/add-remove-direct-method-defgenerics.lisp" e5)
  (load-source-file "CLOS/add-remove-direct-method-support.lisp" e5)
  (load-source-file "CLOS/add-remove-direct-method-defmethods.lisp" e5)
  (load-source-file "CLOS/dependent-maintenance-defgenerics.lisp" e5)
  (load-source-file "CLOS/dependent-maintenance-support.lisp" e5)
  (load-source-file "CLOS/dependent-maintenance-defmethods.lisp" e5)
  (load-source-file "CLOS/add-remove-method-defgenerics.lisp" e5)
  (load-source-file "CLOS/add-remove-method-support.lisp" e5)
  (load-source-file "CLOS/add-remove-method-defmethods.lisp" e5))
