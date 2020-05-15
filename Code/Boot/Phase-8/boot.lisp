(cl:in-package #:sicl-boot-phase-8)

(defun boot (boot)
  (format *trace-output* "Start of phase 8~%")
  (with-accessors ((e5 sicl-boot:e5))
      boot
    (load-data-and-control-flow-code e5)
    (load-cons-related-functions e5)))