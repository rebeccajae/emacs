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

;; Refresh metadata only when no package archive cache was loaded.
(unless package-archive-contents
  (package-refresh-contents))

;; Built into recent Emacs versions, but bootstrap it when necessary.
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)

;; Install external packages declared with `use-package` when absent.
(setq use-package-always-ensure t)


;;; Generated State

;; Keep Emacs Customize output out of this annotated file.
(setq custom-file
      (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file :no-error))


;;; Personal Commands

(defun my/open-config ()
  "Open my Emacs configuration."
  (interactive)
  (find-file user-init-file))

(defvar my/emacs-notes-file
  (expand-file-name "notes.org" user-emacs-directory)
  "Path to my personal Emacs notes.")

(defun my/open-emacs-notes ()
  "Open my personal Emacs notes."
  (interactive)
  (find-file my/emacs-notes-file))

(defun my/open-scratch ()
  "Open the Emacs scratch buffer."
  (interactive)
  (switch-to-buffer "*scratch*"))

(defun my/find-remote-file ()
  "Prompt for a remote file using TRAMP."
  (interactive)
  (find-file
   (read-file-name "Remote file: " "/ssh:")))

(defun my/refresh-alternate-lines ()
  "Redraw alternating lines in every buffer using their minor mode."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (bound-and-true-p my/alternate-lines-mode)
        (my/apply-alternate-lines)))))

(defun my/reload-config ()
  "Reload this configuration and refresh its visual state."
  (interactive)
  (load-file user-init-file)
  (my/refresh-alternate-lines)
  (message "Configuration reloaded."))

;; Temporary escape hatch while the leader-key setup evolves.
(keymap-global-set "C-c r" #'my/reload-config)


;;; macOS Environment

;; GUI applications on macOS do not necessarily inherit the shell PATH.
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :config
  (exec-path-from-shell-initialize))


;;; Basic Interface

;; The toolbar mostly duplicates actions already available through Evil or
;; the command palette.
(tool-bar-mode -1)

(setq inhibit-startup-screen t)


;;; Frame Geometry

;; Preserve graphical window size and position between Emacs sessions.

(defvar my/frame-geometry-file
  (expand-file-name "frame-geometry.el" user-emacs-directory)
  "Machine-local file containing saved frame geometry.")

(defun my/save-frame-geometry ()
  "Save the selected graphical frame's geometry."
  (when (display-graphic-p)
    (let ((parameters
           (mapcar
            (lambda (name)
              (cons name (frame-parameter nil name)))
            '(left top width height))))
      (with-temp-file my/frame-geometry-file
        (prin1 parameters (current-buffer))))))

(defun my/restore-frame-geometry ()
  "Restore saved geometry for the selected graphical frame."
  (when (and (display-graphic-p)
             (file-readable-p my/frame-geometry-file))
    (condition-case error-data
        (let ((parameters
               (with-temp-buffer
                 (insert-file-contents my/frame-geometry-file)
                 (read (current-buffer)))))
          (modify-frame-parameters nil parameters))
      (error
       (message "Could not restore frame geometry: %s"
                (error-message-string error-data))))))

(add-hook 'emacs-startup-hook #'my/restore-frame-geometry)
(add-hook 'kill-emacs-hook #'my/save-frame-geometry)


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
 :family "MonoLisaCode"
 :height 160)


;;; Visual Scanning

;;;; Line Numbers

;; Show absolute locations and keep the gutter from changing width.
(setq display-line-numbers-type t
      display-line-numbers-width-start t
      display-line-numbers-grow-only t)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)


;;;; Alternating Full-Width Lines

(defface my/alternate-line-face
  '((t (:extend t)))
  "Face used for alternating source lines.")

;; Kept separate so reloading updates an already-defined face.
(set-face-attribute
 'my/alternate-line-face
 nil
 :background "#e6e9ef"
 :extend t)

(defvar-local my/alternate-line-overlays nil
  "Overlays used to draw alternating lines in this buffer.")

(defvar-local my/alternate-lines-timer nil
  "Idle timer used to redraw alternating lines in this buffer.")

(defun my/clear-alternate-lines ()
  "Remove alternating-line overlays from the current buffer."
  (mapc #'delete-overlay my/alternate-line-overlays)
  (setq my/alternate-line-overlays nil))

(defun my/apply-alternate-lines ()
  "Draw full-width backgrounds on alternating lines."
  (my/clear-alternate-lines)

  (save-excursion
    (goto-char (point-min))

    (let ((line-number 1))
      (while (< (point) (point-max))
        (when (cl-evenp line-number)
          (let* ((start (line-beginning-position))
                 ;; Include the newline so `:extend` reaches the window edge.
                 (end (min (1+ (line-end-position))
                           (point-max)))
                 (overlay (make-overlay start end)))
            (overlay-put overlay 'face 'my/alternate-line-face)

            ;; Keep stripes beneath transient UI such as the current line.
            (overlay-put overlay 'priority -50)
            (overlay-put overlay 'evaporate t)

            (push overlay my/alternate-line-overlays)))

        (forward-line 1)
        (setq line-number (1+ line-number))))))

(defun my/schedule-alternate-lines-refresh (&rest _ignored)
  "Redraw stripes shortly after editing pauses."
  (when (timerp my/alternate-lines-timer)
    (cancel-timer my/alternate-lines-timer))

  (setq my/alternate-lines-timer
        (run-with-idle-timer
         0.08
         nil
         (lambda (buffer)
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (when my/alternate-lines-mode
                 (my/apply-alternate-lines)))))
         (current-buffer))))

(define-minor-mode my/alternate-lines-mode
  "Display full-width alternating-line backgrounds."
  :lighter nil

  (if my/alternate-lines-mode
      (progn
        (my/apply-alternate-lines)
        (add-hook 'after-change-functions
                  #'my/schedule-alternate-lines-refresh
                  nil
                  :local))

    (remove-hook 'after-change-functions
                 #'my/schedule-alternate-lines-refresh
                 :local)

    (when (timerp my/alternate-lines-timer)
      (cancel-timer my/alternate-lines-timer)
      (setq my/alternate-lines-timer nil))

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


;;;; Rainbow Delimiters

(use-package rainbow-delimiters
  :hook
  (prog-mode . rainbow-delimiters-mode)
  :config
  ;; Catppuccin Latte palette.
  (set-face-foreground 'rainbow-delimiters-depth-1-face "#1e66f5")
  (set-face-foreground 'rainbow-delimiters-depth-2-face "#40a02b")
  (set-face-foreground 'rainbow-delimiters-depth-3-face "#df8e1d")
  (set-face-foreground 'rainbow-delimiters-depth-4-face "#ea76cb")
  (set-face-foreground 'rainbow-delimiters-depth-5-face "#d20f39")
  (set-face-foreground 'rainbow-delimiters-depth-6-face "#179299")
  (set-face-foreground 'rainbow-delimiters-depth-7-face "#8839ef")
  (set-face-foreground 'rainbow-delimiters-depth-8-face "#fe640b")
  (set-face-foreground 'rainbow-delimiters-depth-9-face "#7287fd"))


;;;; Open File Tabs

;; These are buffer/file tabs for each pane, not workspace tabs.
(global-tab-line-mode 1)


;;; Configuration Navigation

;; Treat `;;;` and `;;;;` headings as foldable document sections.
(add-hook 'emacs-lisp-mode-hook #'outline-minor-mode)


;;; Editing

;;;; Evil

;; Evil supplies composable Vim-style editing without requiring the rest of
;; the interface to follow Vim's editor philosophy.
(use-package evil
  :init
  ;; Evil Collection will own integration bindings for other modes.
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))


;;;; Evil Escape

(use-package evil-escape
  :after evil
  :init
  ;; A quick `jj` in insert mode returns to normal mode.
  (setq evil-escape-key-sequence "jj"
        evil-escape-delay 0.25)
  :config
  (evil-escape-mode 1))


;;; Tree

;; Treemacs owns the persistent left-side project tree.
(use-package treemacs
  :defer t
  :config
  (setq treemacs-width 35)

  ;; Single-click files rather than requiring a double-click.
  (define-key treemacs-mode-map
              [mouse-1]
              #'treemacs-RET-action)

  (treemacs-follow-mode 1)
  (treemacs-filewatch-mode 1))


;;; Window Layout

;;;; Display Policy

;; The primary monitor is very wide, so automatic splits should prefer
;; side-by-side windows.
(setq split-height-threshold nil
      split-width-threshold 100
      even-window-sizes nil)

(defun my/remove-display-buffer-rule (pattern)
  "Remove any display-buffer rule whose pattern equals PATTERN."
  (setq display-buffer-alist
        (cl-remove-if
         (lambda (entry)
           (equal (car entry) pattern))
         display-buffer-alist)))

(defun my/set-display-buffer-rule (pattern actions)
  "Replace the display-buffer rule for PATTERN with ACTIONS."
  (my/remove-display-buffer-rule pattern)
  (add-to-list 'display-buffer-alist
               (cons pattern actions)))


;;;; Wide Layout

(defun my/layout-wide ()
  "Use an ultrawide, side-by-side-oriented layout policy."
  (interactive)

  (setq split-height-threshold nil
        split-width-threshold 100)

  ;; Help is an ordinary rightward window rather than a fixed sidebar.
  (my/set-display-buffer-rule
   "\\*Help\\*"
   '((display-buffer-reuse-window
      display-buffer-pop-up-window)
     (inhibit-same-window . t)))

  ;; Compilation and shells remain at the bottom.
  (my/set-display-buffer-rule
   "\\*compilation\\*"
   '((display-buffer-in-side-window)
     (side . bottom)
     (slot . 0)
     (window-height . 0.28)))

  (my/set-display-buffer-rule
   "\\*terminal:"
   '((display-buffer-in-side-window)
     (side . bottom)
     (slot . 0)
     (window-height . 0.28)
     (window-parameters . ((no-delete-other-windows . t)))))

  (message "Wide layout enabled."))


;;;; Compact Layout

(defun my/layout-compact ()
  "Use a laptop-oriented tree/editor/help layout."
  (interactive)

  (setq split-height-threshold 25
        split-width-threshold 100)

  ;; Help becomes a collapsible right sidebar.
  (my/set-display-buffer-rule
   "\\*Help\\*"
   '((display-buffer-in-side-window)
     (side . right)
     (slot . 0)
     (window-width . 0.36)))

  ;; Compilation and terminal-like output live along the bottom.
  (my/set-display-buffer-rule
   "\\*compilation\\*"
   '((display-buffer-in-side-window)
     (side . bottom)
     (slot . 0)
     (window-height . 0.28)))

  (my/set-display-buffer-rule
   "\\*terminal:"
   '((display-buffer-in-side-window)
     (side . bottom)
     (slot . 0)
     (window-height . 0.28)
     (window-parameters . ((no-delete-other-windows . t)))))

  (message "Compact layout enabled."))

(defun my/layout-automatic ()
  "Choose a layout from the current graphical frame width."
  (interactive)
  (if (> (frame-pixel-width) 2400)
      (my/layout-wide)
    (my/layout-compact)))

;; Choose an initial policy once the graphical frame is ready.
(add-hook 'emacs-startup-hook #'my/layout-automatic)


;;; Language Support

;;;; Eglot

;; Eglot ships with Emacs. Language servers are separate executables.
(use-package eglot
  :ensure nil
  :commands eglot eglot-ensure
  :config
  ;; In a TRAMP Python buffer, this starts remote `pylsp`.
  (add-to-list
   'eglot-server-programs
   '((python-mode python-ts-mode) . ("pylsp"))))

(defun my/eglot-ensure-local ()
  "Start Eglot automatically only for local buffers.

Remote buffers use the explicit `eglot` command so that opening a file does
not unexpectedly initiate another slow gateway connection."
  (unless (file-remote-p default-directory)
    (eglot-ensure)))


;;;; Rust

(use-package rust-mode
  :mode "\\.rs\\'"
  :hook
  (rust-mode . my/eglot-ensure-local)
  :config
  (setq rust-format-on-save nil))


;;;; Go

(use-package go-mode
  :mode "\\.go\\'"
  :hook
  (go-mode . my/eglot-ensure-local))


;;;; Python

;; Python mode ships with Emacs.
;;
;; Local Python buffers start Eglot automatically.
;; In a remote Python buffer, use SPC c l. Eglot will run `pylsp` on the
;; remote machine, where it must be installed and available on PATH.
(use-package python
  :ensure nil
  :hook
  ((python-mode python-ts-mode) . my/eglot-ensure-local))


;;; Discoverability

;;;; Which-Key

;; SPC opens categorized actions.
;; SPC SPC opens the searchable command palette.
;;
;; Descriptions capitalize the mnemonic letter:
;;
;;   coNfiguration -> n
;;   describe Key  -> k

(use-package which-key
  :ensure nil
  :config
  (which-key-mode 1))


;;; Terminal

;; A terminal belongs to the location of the current buffer:
;;
;; - In a local file, it opens locally.
;; - In a TRAMP file, it opens on that remote machine.
;;
;; Terminal windows appear at the bottom and can be collapsed with the
;; same command that opened them.

(use-package vterm
  :commands vterm
  :custom
  (vterm-max-scrollback 10000)

  :config
  ;; Select the shell used for TRAMP-backed terminals.
  ;; `t` supplies the fallback for every TRAMP method.
  (add-to-list 'vterm-tramp-shells '(t "/bin/bash")))


(defun my/terminal-location-name ()
  "Return a short name for the current local or remote location."
  (if-let ((host (file-remote-p default-directory 'host)))
      host
    "local"))


(defun my/terminal-buffer-name ()
  "Return the terminal buffer name for the current location."
  (format "*terminal:%s*" (my/terminal-location-name)))


(defun my/toggle-terminal ()
  "Show or hide the terminal for the current local or remote location."
  (interactive)

  (let* ((origin-directory default-directory)
         (buffer-name (my/terminal-buffer-name))
         (buffer (get-buffer buffer-name))
         (window (and buffer
                      (get-buffer-window buffer))))

    (cond
     ;; The terminal is visible: collapse it.
     (window
      (delete-window window))

     ;; The terminal already exists: show it again.
     (buffer
      (display-buffer buffer))

     ;; Create it in the current local or TRAMP directory.
     (t
      (let ((default-directory origin-directory))
        (vterm buffer-name))))))


;;;; Leader Keys

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

    ;; Actions

    "a"   '(:ignore t :which-key "Actions")
    "a e" '(eval-last-sexp :which-key "Evaluate expression")
    "a b" '(eval-buffer :which-key "evaluate Buffer")
    "a r" '(eval-region :which-key "evaluate Region")
    "a s" '(my/open-scratch :which-key "Scratch buffer")

    ;; Configuration

    "n"   '(:ignore t :which-key "coNfiguration")
    "n e" '(my/open-config :which-key "Edit")
    "n r" '(my/reload-config :which-key "Reload")

    ;; Files

    "f"   '(:ignore t :which-key "Files")
    "f f" '(find-file :which-key "Find")
    "f s" '(save-buffer :which-key "Save")

    ;; Remote

    "r"   '(:ignore t :which-key "Remote")
    "r f" '(my/find-remote-file :which-key "Find remote file")
    "r d" '(tramp-cleanup-all-connections
            :which-key "Disconnect all")

    ;; Help

    "h"   '(:ignore t :which-key "Help")
    "h k" '(describe-key :which-key "describe Key")
    "h f" '(describe-function :which-key "describe Function")
    "h v" '(describe-variable :which-key "describe Variable")
    "h n" '(my/open-emacs-notes :which-key "Notes")
    "h m" '(describe-mode :which-key "describe Mode")

    ;; Code

    "c"   '(:ignore t :which-key "Code")
    "c l" '(eglot :which-key "start LSP")
    "c d" '(xref-find-definitions :which-key "Definition")
    "c r" '(xref-find-references :which-key "References")
    "c b" '(xref-go-back :which-key "go Back")
    "c w" '(xref-go-forward :which-key "go forWard")
    "c a" '(eglot-code-actions :which-key "Actions")
    "c f" '(eglot-format-buffer :which-key "Format")
    "c h" '(eldoc-doc-buffer :which-key "Help at point")

    ;; Windows

    "w"   '(:ignore t :which-key "Window")
    "w t" '(treemacs :which-key "Tree")
    "w v" '(split-window-right :which-key "split Vertical")
    "w s" '(split-window-below :which-key "split horiZontal")
    "w d" '(delete-window :which-key "Delete")
    "w o" '(delete-other-windows :which-key "Only this")

    ;; Terminal
    "t"   '(:ignore t :which-key "Terminal")
    "t t" '(my/toggle-terminal :which-key "Toggle")

    ;; Navigation uses hjkl, but Which-Key provides readable descriptions.
    "w h" '(windmove-left :which-key "move left")
    "w j" '(windmove-down :which-key "move down")
    "w k" '(windmove-up :which-key "move up")
    "w l" '(windmove-right :which-key "move right")

    ;; Layout profiles

    "w w" '(my/layout-wide :which-key "Wide layout")
    "w c" '(my/layout-compact :which-key "Compact layout")
    "w a" '(my/layout-automatic :which-key "Automatic layout")

    ;; Quit

    "q"   '(:ignore t :which-key "Quit")
    "q q" '(save-buffers-kill-terminal :which-key "Quit Emacs")))

;;; init.el ends here
