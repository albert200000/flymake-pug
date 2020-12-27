;;; flymake-pug.el --- Flymake backend for Pug using pug-lint  -*- lexical-binding: t; -*-

(require 'flymake)

(defgroup flymake-pug nil
  "Flymake backend for pug using pug-lint."
  :group 'flymake)

(defvar-local flymake-pug--proc nil)

(defun flymake-pug (report-fn &rest _args)
  "Make pug-lint process."
  (unless (executable-find
           "pug-lint") (error "Cannot find a suitable pug-lint"))
  (when (process-live-p flymake-pug--proc)
    (kill-process flymake-pug--proc))
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      (setq flymake-pug--proc
            (make-process
             :name "pug-flymake" :noquery t :connection-type 'pipe
             :buffer (generate-new-buffer " *Flymake-Pug*")
             :command (list "pug-lint" (buffer-file-name source))
             :sentinel
             (lambda (proc _event)
                (when (eq 'exit (process-status proc))
                  (unwind-protect
                      (if (with-current-buffer source (eq proc flymake-pug--proc))
                          (with-current-buffer (process-buffer proc)
                            (goto-char (point-min))
                            (cl-loop
                             while (search-forward-regexp
                                    "\\(.*.pug\\):\\([0-9]+\\):[0-9]+\\(.*\n\\)+\n\\(.*\\)"
                                    nil t)
                             for msg = (match-string 4)
                             for (beg . end) = (flymake-diag-region
                                                source
                                                (string-to-number (match-string 2)))
                             for type = :warning
                             collect (flymake-make-diagnostic source beg end type msg)
                             into diags
                             finally (funcall report-fn diags)))
                        (flymake-log :warning "Canceling obsolete check %s" proc))
                    (kill-buffer (process-buffer proc))))))))))

;;;###autoload
(defun flymake-pug-turn-on ()
  "Enable `flymake-pug' as buffer-local Flymake backend."
  (interactive)
  (flymake-mode 1)
  (add-hook 'flymake-diagnostic-functions 'flymake-pug nil t))

(provide 'flymake-pug)
;;; flymake-pug.el ends here
