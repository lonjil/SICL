(cl:in-package #:sicl-boot-phase-2)

(defun define-generic-function-class-names (e3)
  (setf (env:fdefinition
         (env:client e3) e3 'sicl-clos::generic-function-class-names)
        (lambda (name environment)
          (declare (ignore environment))
          (let ((client (env:client e3)))
            (if (and (env:fboundp client e3 name)
                     (or (consp name)
                         (and (null (env:macro-function client e3 name))
                              (not (env:special-operator client e3 name)))))
                (let ((function (env:fdefinition (env:client e3) e3 name)))
                  (if (typep function 'generic-function)
                      (values
                       (class-name (class-of function))
                       (class-name
                        (closer-mop:generic-function-method-class function)))
                      (values 'standard-generic-function 'standard-method)))
                (values 'standard-generic-function 'standard-method))))))

(defun enable-defmethod (e2 e3)
  (define-generic-function-class-names e3)
  (let ((client (env:client e2)))
    (setf (env:find-class client e2 't)
          (find-class t))
    (setf (env:fdefinition client e2 'sicl-clos:method-function)
          (lambda (method)
            (declare (ignore method))
            (error "this should not happen")))
    (setf (env:special-operator client e3 'cleavir-primop:multiple-value-call) t))
  (import-functions-from-host
   '(sicl-clos:parse-defmethod sicl-clos:canonicalize-specializers
     (setf env:macro-function))
   e3)
  (load-source-file "CLOS/make-method-lambda-support.lisp" e3)
  (setf (env:macro-function (env:client e3) e3 'sicl-clos:make-method-lambda)
        (lambda (form environment)
          (declare (ignore environment))
          `(sicl-clos::make-method-lambda-default
            nil nil ,(fourth form) nil)))
  (load-source-file "CLOS/defmethod-defmacro.lisp" e3))