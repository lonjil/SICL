(cl:in-package #:sicl-boot-phase-4)

(defun define-class-of (e4)
  (setf (sicl-genv:fdefinition 'class-of e4)
        (lambda (object)
          (let ((result (cond ((typep object 'sicl-boot-phase-3::header)
                               (slot-value object 'sicl-boot-phase-3::%class))
                              ((consp object)
                               (sicl-genv:find-class 'cons e4))
                              ((null object)
                               (sicl-genv:find-class 'null e4))
                              ((symbolp object)
                               (sicl-genv:find-class 'symbol e4))
                              ((integerp object)
                               (sicl-genv:find-class 'fixnum e4))
                              ((streamp object)
                               (sicl-genv:find-class 't e4))
                              (t
                               (class-of object)))))
            result))))