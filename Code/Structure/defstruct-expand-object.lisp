;;;; Expand structure-object-based defstructs.

(cl:in-package #:sicl-structure)

(defun check-included-structure-object (description environment)
  (when (defstruct-included-structure-name description)
    (let ((included-structure (find-class (defstruct-included-structure-name description)
                                          environment
                                          nil)))
      (unless (and included-structure
                   (typep included-structure 'structure-class))
        (error "included structure named ~S is either not defined or is not a structure-class"
               (defstruct-included-structure-name description)))
      ;; All included slots must be present in the included structure.
      (dolist (slot (defstruct-included-slots description))
        (let ((existing (find (slot-name slot)
                              (closer-mop:class-slots included-structure)
                              :key #'closer-mop:slot-definition-name
                              :test #'string=)))
          (unless existing
            (error "included slot ~S does not exist in ~S"
                   (slot-name slot) included-structure))
          ;; For the sake of sanity, lets require them to be the same symbol too.
          ;; If it is legal for them to be different, then they need to be
          ;; canonicalized to the existing slot so that slot inheritance works
          ;; correctly.
          (unless (eql (slot-name slot) (closer-mop:slot-definition-name existing))
            (error "included slot ~S name does not match existing slot name ~S"
                   (slot-name slot) (closer-mop:slot-definition-name existing)))))
      ;; Direct slots must not be present (string=)
      (dolist (slot (defstruct-direct-slots description))
        (when (find (slot-name slot)
                    (closer-mop:class-slots included-structure)
                    :key #'closer-mop:slot-definition-name
                    :test #'string=)
          (error "slot ~S conflicts with slot in included structure ~S"
                 (slot-name slot) included-structure))))))

(defun compute-included-structure-object-slots (description environment)
  ;; All effective slots, not just explicitly included slots, need to be
  ;; included so that the correct accessor methods are generated.
  (when (defstruct-included-structure-name description)
    (loop with included-structure = (find-class (defstruct-included-structure-name description)
                                                environment)
          for slot in (closer-mop:class-slots included-structure)
          for inclusion = (find (closer-mop:slot-definition-name slot)
                                (defstruct-included-slots description)
                                :key #'slot-name)
          collect (if inclusion
                      ;; Explicitly included slot.
                      `(,(closer-mop:slot-definition-name slot)
                        ,@(when (slot-initform-p slot)
                            (list :initform (slot-initform inclusion)))
                        :type ,(slot-type inclusion)
                        :read-only ,(slot-read-only inclusion)
                        ,(if (slot-read-only inclusion) :reader :accessor)
                        ,(slot-accessor-name inclusion))
                      ;; Implicitly included slot, only include the accessor option.
                      (list (closer-mop:slot-definition-name slot)
                            (if (structure-slot-definition-read-only slot) :reader :accessor)
                            ;; An ugly wart, we have to generate the name here.
                            (if (defstruct-conc-name description)
                                (symbolicate (defstruct-conc-name description)
                                             (closer-mop:slot-definition-name slot))
                                (closer-mop:slot-definition-name slot)))))))

(defun compute-direct-structure-object-slots (description)
  (loop for slot in (defstruct-direct-slots description)
        collect `(,(slot-name slot)
                  :initarg ,(keywordify (slot-name slot))
                  ,@(when (slot-initform-p slot)
                      (list :initform (slot-initform slot)))
                  :type ,(slot-type slot)
                  :read-only ,(slot-read-only slot)
                  ,(if (slot-read-only slot) :reader :accessor)
                  ,(slot-accessor-name slot))))

(defun all-object-slot-names (description environment)
  ;; All of them, including implicitly included slots.
  (append
   (when (defstruct-included-structure-name description)
     (loop with included-structure = (find-class (defstruct-included-structure-name description)
                                                 environment)
           for slot in (closer-mop:class-slots included-structure)
           collect (closer-mop:slot-definition-name slot)))
   (loop for slot in (defstruct-direct-slots description)
         collect (slot-name slot))))

;;; Ordinary non-BOA constructors are simple, go through the normal
;;; MAKE-INSTANCE path, letting INITIALIZE-INSTANCE take care of slot
;;; initialization.
(defun generate-object-ordinary-constructor (description environment name)
  (let ((slots (all-object-slot-names description environment)))
    ;; Provide keywords in the lambda-list to improve the development
    ;; experience.
    `(defun ,name (&rest initargs &key ,@slots)
       (declare (ignore ,@slots))
       (apply #'make-instance ',(defstruct-name description) initargs))))

;;; BOA constructors are a more complicated as they have the ability
;;; to completely override any specified slot initforms. So, in some
;;; cases, they need to bypass INITIALIZE-INSTANCE and call
;;; ALLOCATE-INSTANCE/SHARED-INITIALIZE directly.
;;;
;;; If an initform for an &OPTIONAL or &KEY parameter is not provided,
;;; it must default to the slot's initform.
;;; If an initform for an &AUX parameter is not provided, then the
;;; slot associated with that parameter will be left uninitialized,
;;; ignoring any initform specified by the slot.
;;;
;;; 3.4.6 Boa Lambda Lists:
;;; "If no default value is supplied for an aux variable variable, the
;;; consequences are undefined if an attempt is later made to read
;;; the corresponding slot's value before a value is explicitly assigned."
;;;
;;; TODO: Implement the above properly. BOA constructors don't currently
;;; follow the spec but should be good enough for most use cases.
(defun generate-object-boa-constructor (description environment name lambda-list)
  (multiple-value-bind (requireds optionals rest keys aok auxs has-keys)
      (alexandria:parse-ordinary-lambda-list lambda-list)
    (declare (ignore aok has-keys))
    (let ((all-slots (all-object-slot-names description environment))
          ;; Pick out the slot names and compute the slots without a lambda variable
          (assigned-slots (append requireds
                                  (mapcar #'first optionals)
                                  (if rest
                                      (list rest)
                                      '())
                                  (mapcar #'cadar keys) ; (second (first k))
                                  (mapcar #'first auxs)))
          ;; Suppliedp variables aren't used for binding
          (other-vars (append (remove nil (mapcar #'third optionals))
                              (remove 'nil (mapcar #'third keys)))))
      `(defun ,name ,lambda-list
         (declare (ignorable ,@(set-difference (union other-vars assigned-slots)
                                               all-slots)))
         (make-instance
          ',(defstruct-name description)
          ,@(loop for slot in assigned-slots
                  when (member slot all-slots)
                  collect (keywordify slot)
                  and collect slot))))))

(defun expand-object-defstruct (description environment)
  (check-included-structure-object description environment)
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       (defclass ,(defstruct-name description)
           (,(or (defstruct-included-structure-name description)
                 'structure-object))
         (,@(compute-included-structure-object-slots description environment)
          ,@(compute-direct-structure-object-slots description))
         (:metaclass structure-class)))
     ,@(loop for constructor in (defstruct-constructors description)
             collect (if (cdr constructor)
                         (generate-object-boa-constructor description environment (first constructor) (second constructor))
                         (generate-object-ordinary-constructor description environment (first constructor))))
     ,@(loop for predicate-name in (defstruct-predicates description)
             collect `(defun ,predicate-name (object)
                        (typep object ',(defstruct-name description))))
     ,@(loop for copier-name in (defstruct-copiers description)
             collect `(defun ,copier-name (object)
                        (check-type object ,(defstruct-name description))
                        (copy-structure object)))
     ,@(when (defstruct-print-object description)
         (list `(defmethod print-object ((object ,(defstruct-name description)) stream)
                  (funcall #',(defstruct-print-object description) object stream))))
     ',(defstruct-name description)))
