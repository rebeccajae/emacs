;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;;; Design Principles

;; - Discoverability over memorization.
;; - Visible information over hidden state.
;; - Evil provides Vim's editing language, not Vim's editor philosophy.
;; - Which-Key descriptions capitalize the letter used to invoke them.
;; - Configuration remains in this annotated file unless something becomes
;;   substantial enough to be a plugin of its own.


;;; Package Management

(require 'package)
(require 'cl-lib)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

(package-initialize)

;; Refresh package metadata only when no cached archive contents were loaded.
(unless package-archive-contents
  (package-refresh-contents))

;; `use-package` is built into recent Emacs versions, but this keeps the
;; configuration portable to installations where it is not bundled.
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)

;; A use-package declaration also installs its package when necessary.
(setq use-package-always-ensure t)


;;; Generated Custom State

;; Keep changes made by Emacs' Customize system out of this file.
(setq custom-file
      (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file :no-error))


;;; Personal Commands

(defun my/open-config ()
  "Open my Emacs configuration."
  (interactive)
  (find-file user-init-file))

(defun my/refresh-alternate-lines ()
  "Redraw alternating lines in every buffer using their minor mode."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (bound-and-true-p my/alternate-lines-mode)
        (my/apply-alternate-lines)))))

(defun my/reload-config ()
  "Reload my Emacs configuration and refresh its visual state."
  (interactive)
  (load-file user-init-file)
  (my/refresh-alternate-lines)
  (message "Configuration reloaded."))

(defvar my/emacs-notes-file
  (expand-file-name "notes.org" user-emacs-directory)
  "Path to my personal Emacs notes.")

(defun my/open-emacs-notes ()
  "Open my personal Emacs notes."
  (interactive)
  (find-file my/emacs-notes-file))

;; Temporary escape hatch while the leader-key setup is evolving.
(keymap-global-set "C-c r" #'my/reload-config)


;;; Basic Interface

;; The toolbar mostly duplicates actions already available through Evil or
;; the command palette.
(tool-bar-mode -1)

(setq inhibit-startup-screen t)


;;; Theme

(use-package catppuccin-theme
  :init
  (setq catppuccin-flavor 'latte)
  :config
  (load-theme 'catppuccin :no-confirm))


;;; Font

(set-face-attribute
 'default
 nil
 :family "Berkeley Mono"
 :height 180)


;;; Visual Scanning

;;;; Line Numbers

;; Always show absolute source locations. Reserve the required gutter width
;; immediately and do not shrink it afterward.
(setq display-line-numbers-type t
      display-line-numbers-width-start t
      display-line-numbers-grow-only t)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)


;;;; Alternating Full-Width Lines

(defface my/alternate-line-face
  '((t (:extend t)))
  "Face used for alternating source lines.")

;; Set this separately from `defface` so changing it and reloading the config
;; updates an already-defined face.
(set-face-attribute
 'my/alternate-line-face
 nil
 :background "#e6e9ef"
 :extend t)

(defvar-local my/alternate-line-overlays nil
  "Overlays used to draw alternating lines in the current buffer.")

(defun my/clear-alternate-lines ()
  "Remove alternating-line overlays from the current buffer."
  (mapc #'delete-overlay my/alternate-line-overlays)
  (setq my/alternate-line-overlays nil))

(defun my/apply-alternate-lines (&rest _ignored)
  "Draw full-width backgrounds on alternating lines."
  (my/clear-alternate-lines)

  (save-excursion
    (goto-char (point-min))

    (let ((line-number 1))
      (while (< (point) (point-max))
        (when (cl-evenp line-number)
          (let* ((start (line-beginning-position))
                 ;; Include the newline so the face extends across the window.
                 (end (min (1+ (line-end-position))
                           (point-max)))
                 (overlay (make-overlay start end)))
            (overlay-put overlay 'face 'my/alternate-line-face)

            ;; Keep stripes beneath transient overlays such as `hl-line`.
            (overlay-put overlay 'priority -50)
            (overlay-put overlay 'evaporate t)

            (push overlay my/alternate-line-overlays)))

        (forward-line 1)
        (setq line-number (1+ line-number))))))

(define-minor-mode my/alternate-lines-mode
  "Display full-width alternating-line backgrounds."
  :lighter nil

  (if my/alternate-lines-mode
      (progn
        (my/apply-alternate-lines)
        (add-hook 'after-change-functions
                  #'my/apply-alternate-lines
                  nil
                  :local))
    (remove-hook 'after-change-functions
                 #'my/apply-alternate-lines
                 :local)
    (my/clear-alternate-lines)))

(add-hook 'prog-mode-hook #'my/alternate-lines-mode)


;;;; Current Line

(use-package hl-line
  :ensure nil
  :config
  (set-face-attribute
   'hl-line
   nil
   :background "#ccd0da"
   :extend t)

  (global-hl-line-mode 1))

;;;; Rainbow parens

(use-package rainbow-delimiters
  :hook
  (prog-mode . rainbow-delimiters-mode))


;;;; Tab Bar

(global-tab-line-mode 1)
; (tab-bar-mode 1)


;;; Configuration Navigation

;; Treat `;;;` headings as foldable sections in Emacs Lisp buffers.
(add-hook 'emacs-lisp-mode-hook #'outline-minor-mode)


;;; Evil

;; Evil supplies composable Vim-style text editing. It does not define the
;; overall interface or require the rest of Emacs to imitate Vim.

(use-package evil
  :init
  ;; Evil Collection will provide integration bindings for other modes.
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))


;;; Discoverability

;; SPC opens categorized actions.
;; SPC SPC opens the searchable command palette.
;;
;; Which-Key descriptions capitalize the mnemonic letter:
;;
;;   coNfiguration -> n
;;   describe Key  -> k

(use-package which-key
  :config
  (which-key-mode 1))

(use-package general
  :after evil
  :config
  (general-create-definer my/leader
    :states '(normal visual motion)
    :keymaps 'override
    :prefix "SPC")

  (my/leader
    ""    '(:ignore t :which-key "leader")
    "SPC" '(execute-extended-command :which-key "command palette")

    "a"   '(:ignore t :which-key "Actions")
    "a e" '(eval-last-sexp :which-key "Evaluate expression")
    
    "n"   '(:ignore t :which-key "coNfiguration")
    "n e" '(my/open-config :which-key "Edit")
    "n r" '(my/reload-config :which-key "Reload")

    "f"   '(:ignore t :which-key "Files")
    "f f" '(find-file :which-key "Find")
    "f s" '(save-buffer :which-key "Save")

    "h"   '(:ignore t :which-key "Help")
    "h k" '(describe-key :which-key "describe Key")
    "h f" '(describe-function :which-key "describe Function")
    "h v" '(describe-variable :which-key "describe Variable")
    "h n" '(my/open-emacs-notes :which-key "Notes")

    "q"   '(:ignore t :which-key "Quit")
    "q q" '(save-buffers-kill-terminal :which-key "Quit Emacs")))

;;; init.el ends here
