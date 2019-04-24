(cl:in-package #:cleavir-ast-to-hir)

;;; The generic function called on various AST types.  It compiles AST
;;; in the compilation context CONTEXT and returns the first
;;; instruction resulting from the compilation.
(defgeneric compile-ast (ast context))

;;; This :AROUND method serves as an adapter for the compilation of
;;; ASTs that generate a single value.  If such an AST is compiled in
;;; a unfit context (i.e, a context other than one that has a single
;;; successor and a single required value), this method either creates
;;; a perfect context for compiling that AST together with
;;; instructions for satisfying the unfit context, or it signals an
;;; error if appropriate.
(defmethod compile-ast :around ((ast cleavir-ast:one-value-ast-mixin) context)
  (with-accessors ((results results)
                   (successors successors)
                   (invocation invocation))
      context
    (assert-context ast context nil 1)
    ;; We have a context with one successor, so RESULTS can be a
    ;; list of any length, or it can be a values location,
    ;; indicating that all results are needed.
    (cond ((typep results 'cleavir-ir:values-location)
           ;; The context is such that all multiple values are
           ;; required.
           (let ((temp (make-temp)))
             (call-next-method
              ast
              (context (list temp)
                       (list (make-instance 'cleavir-ir:fixed-to-multiple-instruction
                              :inputs (list temp)
                              :output results
                              :successor (first successors)))
                       invocation))))
          ((null results)
           ;; We don't need the result.  This situation typically
           ;; happens when we compile a form other than the last of
           ;; a PROGN-AST.
           (if (cleavir-ast:side-effect-free-p ast)
               (progn
                 ;; For now, we do not emit this warning.  It is a bit
                 ;; too annoying because there is some automatically
                 ;; generated code that is getting warned about.
                 ;; (warn "Form compiled in a context requiring no value.")
                 (first successors))
               ;; We allocate a temporary variable to receive the
               ;; result, and that variable will not be used.
               (call-next-method ast
                                 (context (list (make-temp))
                                          successors
                                          invocation))))
          (t
           ;; We have at least one result.  In case there is more
           ;; than one, we generate a successor where all but the
           ;; first one are filled with NIL.
           (let ((successor (nil-fill (rest results) (first successors))))
             (call-next-method ast
                               (context (list (first results))
                                        (list successor)
                                        invocation)))))))

;;; If these checks fail, it's an internal bug, since the
;;; :around method should fix the results and successors.
(defmethod compile-ast :before
    ((ast cleavir-ast:one-value-ast-mixin) context)
  (assert-context ast context 1 1))

(defmethod compile-ast :before
    ((ast cleavir-ast:no-value-ast-mixin) context)
  (assert-context ast context 0 1))