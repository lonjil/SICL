(cl:in-package #:sicl-boot-phase-8)

(defun find-max-class-unique-number (e5)
  (let ((max 0)
        (table (make-hash-table :test #'eq))
        (fun (sicl-genv:fdefinition 'sicl-clos::unique-number e5)))
    (do-all-symbols (symbol) 
      (unless (gethash symbol table)
        (setf (gethash symbol table) t)
        (let ((class (sicl-genv:find-class symbol e5)))
          (unless (null class)
            (setf max (max max (funcall fun class)))))))
    max))

(defun set-class-unique-number-counter (e5)
  (setf (sicl-genv:special-variable 'sicl-clos::*class-unique-number* e5 t)
        (1+ (find-max-class-unique-number e5))))
