;;; Clang Code-Completion minor mode, for use with C/Objective-C/C++.

;;; Commentary:

;; This minor mode uses Clang's command line interface for code
;; completion to provide code completion results for C, Objective-C,
;; and C++ source files. When enabled, Clang will provide
;; code-completion results in a secondary buffer based on the code
;; being typed. For example, after typing "struct " (triggered via the
;; space), Clang will provide the names of all structs visible from
;; the current scope. After typing "p->" (triggered via the ">"),
;; Clang will provide the names of all of the members of whatever
;; class/struct/union "p" points to. Note that this minor mode isn't
;; meant for serious use: it is meant to help experiment with code
;; completion based on Clang. It needs your help to make it better!
;;
;; To use the Clang code completion mode, first make sure that the
;; "clang" variable below refers to the "clang" executable,
;; which is typically installed in libexec/. Then, place
;; clang-completion-mode.el somewhere in your Emacs load path. You can
;; add a new load path to Emacs by adding some like the following to
;; your .emacs:
;;
;;   (setq load-path (cons "~/.emacs.d" load-path))
;;
;; Then, use
;;
;;   M-x load-library
;;
;; to load the library in your Emacs session or add the following to
;; your .emacs to always load this mode (not recommended):
;;
;;   (load-library "clang-completion-mode")
;;
;; Finally, to try Clang-based code completion in a particular buffer,
;; use M-x clang-completion-mode. When "Clang-CC" shows up in the mode
;; line, Clang's code-completion is enabled.
;;
;; Clang's code completion is based on parsing the complete source
;; file up to the point where the cursor is located. Therefore, Clang
;; needs all of the various compilation flags (include paths, dialect
;; options, etc.) to provide code-completion results. Currently, these
;; need to be placed into the clang-flags variable in a format
;; acceptable to clang. This is a hack: patches are welcome to
;; improve the interface between this Emacs mode and Clang!
;;

;; Enki: I change the way we complete. I use anything.
(require 'anything)

;;; Code:
;;; The clang executable
(defcustom clang "clang"
  "The location of the Clang compiler executable"
  :type 'file
  :group 'clang-completion-mode)

;;; Extra compilation flags to pass to clang.
(defcustom clang-flags nil
  "Extra flags to pass to the Clang executable.
This variable will typically contain include paths, e.g., -I~/MyProject."
  :type '(repeat (string :tag "Argument" ""))
  :group 'clang-completion-mode
  :safe  'stringp)

;;; The prefix header to use with Clang code completion.
(setq clang-completion-prefix-header "")

;;; The substring we will use to filter completion results
(setq clang-completion-substring "")

;;; The current completion buffer
(setq clang-completion-buffer nil)

(setq clang-result-string "")

;;; Compute the current line in the buffer
(defun current-line ()
  "Return the vertical position of point..."
  (+ (count-lines (point-min) (point))
     (if (= (current-column) 0) 1 0)
     -1))

;;; Set the Clang prefix header
(defun clang-prefix-header ()
  (interactive)
  (setq clang-completion-prefix-header
        (read-string "Clang prefix header> " "" clang-completion-prefix-header
                     "")))

;; Process "filter" that keeps track of the code-completion results
;; produced. We store all of the results in a string, then the
;; sentinel processes the entire string at once.
(defun clang-completion-stash-filter (proc string)
  (setq clang-result-string (concat clang-result-string string)))

;; Filter the given list based on a predicate.
(defun filter (condp lst)
    (delq nil
          (mapcar (lambda (x) (and (funcall condp x) x)) lst)))

;; Determine whether
(defun is-completion-line (line)
  (or (string-match "OVERLOAD:" line)
      (string-match (concat "COMPLETION: " clang-completion-substring) line)))

;; Determine whether
(defun is-error-line (line)
  (or (string-match "[^:]+:[^:]+: error:" line)
      (string-match "[^:]+:[^:]+: fatal error:" line)))


;; Support for anything
;; Completion
(defun anything-print-info ()
  (interactive)
  (anything-other-buffer '(my-error-lines
			   my-completion-lines)
			 "*Clang Complete*"))

(defun anything-print-info-with-init ()
  (interactive)
  (anything-at-point '(my-error-lines
		       my-completion-lines)
		     (thing-at-point 'symbol)))

(defun compute-snippet (selection)
  (let ((n 0)
	(result selection))
    (progn
      ;; The replace-regexp-in-string function can take as second argument
      ;; a function which is called for every replacement. We want to have
      ;; each `<#' replaced by a "`${' `number in the string' `:'. With this
      ;; non-pure lambda we can do this.
      (setq result (replace-regexp-in-string "<#"
					     '(lambda (selection)
						(progn
						  (setq n (1+ n))
						  (concat "${"
							  (number-to-string n)
							  ":")))
					     result))
      (setq result (replace-regexp-in-string "#>" "}" result)))
    (yas/expand-snippet (replace-regexp-in-string "$" "$0" result))))


(defun snippet-select (selection)
  (let* ((first (replace-regexp-in-string "^[^:]\+: " "" selection))
	 (second (replace-regexp-in-string "\\[#[^#]+#\\]" "" first)))
    (compute-snippet (substring second (length (thing-at-point 'symbol))))))



;; Take a line of clang, format it, and insert into the developper's buffer
(defun format-and-insert(selection)
  (let ((my-line selection))
    (string-match "^\\([^:]\+\\) :" my-line)
    (let ((name (substring my-line (match-beginning 1) (match-end 1))))
      (if (string-match "Pattern" name)
	  (progn
	    (string-match "^Pattern : \\([^<]+\\)" my-line)
	    (insert (substring (substring my-line (match-beginning 1) (match-end 1))
			       (length (thing-at-point 'symbol)))))
	(progn
	  (insert (substring name (length (thing-at-point 'symbol))))
	  (if (string-match " : [^(]\*(" my-line)
	      (insert "("))
	  (if (string-match "()" my-line)
	      (insert ")")))))))


;; Allow the user to go to the error.
(defun my-goto-error(selection)
  (string-match "^\\([^:]+\\):\\([^:]+\\):\\([^:]+\\): " selection)
  ;;              ^-filename-^^---line--^^--column--^
  (let ((file (substring selection (match-beginning 1) (match-end 1)))
        (line (substring selection (match-beginning 2) (match-end 2)))
        (column (substring selection (match-beginning 3) (match-end 3))))
    (find-file file)
    (goto-line (string-to-number line))
    (move-to-column (string-to-number column))))

;; Process "sentinal" that, on successful code completion, replaces the
;; contents of the code-completion buffer with the new code-completion results
;; and ensures that the buffer is visible.
(defun clang-completion-sentinel (proc event)
  (let* ((all-lines (split-string clang-result-string "\n"))
         (error-lines (filter 'is-error-line all-lines))
         (completion-lines (filter 'is-completion-line all-lines))
	 (beautiful-completion-lines (mapcar '(lambda (line)
						(substring line 12)) completion-lines)))

    (setf my-completion-lines
	  '((name . "Completion clang")
	    (candidates . beautiful-completion-lines)
	    (action . (("Action name" .
;;			(format-and-insert))))))
			(snippet-select))))))

    (setf my-error-lines
	  '((name . "Error Clang")
	    (candidates . error-lines)
	    (action . (("Action name" .
			(my-goto-error))))))
    (if (consp error-lines)
	(anything-print-info)
      (anything-print-info-with-init))))

(defun x-clang-complete ()
  (interactive)
  (let* ((cc-point (concat (buffer-file-name)
                           ":"
                           (number-to-string (+ 1 (current-line)))
                           ":"
                           (number-to-string (- (+ 1 (current-column))
						(length (thing-at-point 'symbol))))))
         (cc-pch (if (equal clang-completion-prefix-header "") nil
                   (list "-include-pch"
                         (concat clang-completion-prefix-header ".pch"))))
         (cc-flags (filter 'stringp clang-flags))
         (cc-command (append `(,clang "-cc1" "-fsyntax-only", @cc-flags)
                             cc-pch
                             `("-code-completion-at" ,cc-point)
                             (list (buffer-file-name))))
         (cc-buffer-name (concat "*Clang Completion for " (buffer-name) "*")))

    ;; Start the code-completion process
    (if (buffer-file-name)
        (progn
          ;; If there is already a code-completion process, kill it first.
          (let ((cc-proc (get-process "Clang Code-Completion")))
            (if cc-proc
                (delete-process cc-proc)))

          (setq clang-completion-substring "")
          (setq clang-result-string "")
          (setq clang-completion-buffer cc-buffer-name)

          (let ((cc-proc (apply 'start-process
                                (filter 'stringp
                                        (append (list "Clang Code-Completion" cc-buffer-name)
                                                cc-command)))))
            (set-process-filter cc-proc 'clang-completion-stash-filter)
            (set-process-sentinel cc-proc 'clang-completion-sentinel)
            )))))

;; Code-completion when one of the trigger characters is typed into
;; the buffer, e.g., '(', ',' or '.'.
(defun clang-complete-self-insert (arg)
  (interactive "p")
  (save-window-excursion
   (self-insert-command arg)
   (save-buffer)
   (x-clang-complete)))

(defun clang-complete ()
  (interactive)
  (save-window-excursion
    (save-buffer)
    (x-clang-complete)))

;; Set up the keymap for the Clang minor mode.
(defvar clang-completion-mode-map nil
  "Keymap for Clang Completion Mode.")

(if (null clang-completion-mode-map)
    (fset 'clang-completion-mode-map
          (setq clang-completion-mode-map (make-sparse-keymap))))

(if (not (assq 'clang-completion-mode minor-mode-map-alist))
    (setq minor-mode-map-alist
          (cons (cons 'clang-completion-mode clang-completion-mode-map)
                minor-mode-map-alist)))

;; Punctuation characters trigger code completion.
(dolist (char '("." ">" ":"))
  (define-key clang-completion-mode-map char 'clang-complete-self-insert))

;; Set up the Clang minor mode.
(define-minor-mode clang-completion-mode
  "Clang code-completion mode"
  nil
  " Clang"
  clang-completion-mode-map)
