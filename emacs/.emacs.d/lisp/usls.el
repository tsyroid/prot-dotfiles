;;; usls.el --- Unassuming Sidenotes of Little Significance -*- lexical-binding: t -*-

;; Copyright (C) 2020  Protesilaos Stavrou

;; Author: Protesilaos Stavrou <info@protesilaos.com>
;; URL: https://protesilaos.com/dotemacs
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Read about my rationale and workflow with this tool:
;; <https://protesilaos.com/codelog/2020-10-08-intro-usls-emacs-notes/>
;;
;; `usls', aka the "Unassuming Sidenotes of Little Significance" (USLS),
;; is a personal system of storing notes of arbitrary length in a flat
;; directory listing.
;;
;; `usls' leverages built-in Emacs functions to help streamline the
;; process of making and linking together plain text notes.  It does not
;; rely on `org-mode' or any other major library.
;;
;; The totally unintentional constraint of this library is that both its
;; name (`usls') and its expanded description are unwieldly.  The author
;; is not aware of an elegant solution.  Users may instead opt to call
;; it a common word that denotes its utility to the wider public and
;; contains the characters "u" "s" "l" "s".
;;
;;; Code:

(require 'cl-lib)
(require 'crm)
(require 'ffap)
(require 'thingatpt)

;;; User-facing options

(defgroup usls ()
  "Simple tool for plain text notes."
  :group 'files
  :prefix "usls-")

(defcustom usls-directory "~/Documents/notes/"
  "Directory for storing personal notes."
  :group 'usls
  :type 'directory)

(defcustom usls-known-categories '(economics philosophy politics)
  "List of predefined categories for `usls-new-note'.

The implicit assumption is that a category is a single word.  If
you need a category to be multiple words long, use underscores to
separate them.  Do not use hyphens, as those are assumed to
demarcate distinct categories, per `usls--inferred-categories'.

Also see `usls-categories' for a dynamically generated list that
gets combined with this one in relevant prompts."
  :group 'usls
  :type 'list)

(defcustom usls-directory-files-function #'directory-files
  "Function for retrieving `usls-directory' files.

The default workflow of USLS is to maintain a flat directory
where all the notes are stored in.  This allows us to omit the
common filesystem path and only show file names.  As such, the
default option is the function `directory-files'.

Users who prefer a notes' directory with subdirectories must use
`directory-files-recursively'.  It can handle that workflow at
the expense of making all file names more verbose, as it needs to
include the complete path."
  :group 'usls
  :type 'function
  :options '(directory-files directory-files-recursively))

;;; Main variables

(defconst usls-id "%Y%m%d_%H%M%S"
  "Function to produce a unique ID prefix for note filenames.")

(defconst usls-id-regexp "\\([0-9_]+\\{15\\}\\)"
  "Regular expression to match `usls-id'.")

(defconst usls-category-regexp "--\\([0-9A-Za-z_-]*\\)--"
  "Regular expression to match `usls-categories'.")

(defconst usls-file-regexp (concat usls-id-regexp usls-category-regexp ".*.txt")
  "Regular expression to match file names from `usls-new-note'.")

;;; Basic utilities

;;;; File name helpers
(defun usls-extract (regexp str)
  "Extract REGEXP from STR."
  (with-temp-buffer
    (insert str)
    (when (re-search-forward regexp nil t -1)
      (match-string 1))))

;; REVIEW: any character class that captures those?  It seems to work
;; though...
(defun usls--slug-no-punct (str)
  "Convert STR to a file name slug."
  (replace-regexp-in-string "[][{}!@#$%^&*()_=+'\"?,.\|;:~`]*" "" str))

;; REVIEW: this looks inelegant.  We want to remove spaces or multiple
;; hyphens, as well as a final hyphen.
(defun usls--slug-hyphenate (str)
  "Replace spaces with hyphens in STR."
  (replace-regexp-in-string "-$" "" (replace-regexp-in-string "--+\\|\s+" "-" str)))

(defun usls-sluggify (str)
  "Make STR an appropriate file name slug."
  (downcase (usls--slug-hyphenate (usls--slug-no-punct str))))

;;;; Files in directory

(defun usls--directory-files ()
  "List directory files."
  (let ((path usls-directory)
        (dotless directory-files-no-dot-files-regexp))
    (unless (file-directory-p path)
      (make-directory path t))
    (pcase usls-directory-files-function
      ('directory-files-recursively     ; TODO: avoid duplication
        (directory-files-recursively path ".*" nil t))
      (_
       (directory-files path nil dotless t)))))

;;;; Categories

(defun usls--inferred-categories ()
  "Extract categories from `usls--directory-files'."
  (let ((sequence (mapcar (lambda (x)
                    (usls-extract usls-category-regexp x))
                  (usls--directory-files))))
    (mapcan (lambda (s)
              (split-string s "-" t))
            sequence)))

(defun usls-categories ()
  "Combine `usls--inferred-categories' with `usls-known-categories'."
  (append (usls--inferred-categories) usls-known-categories))

;;;; Input history lists

(defvar usls--title-history nil
  "Used internally by `usls-new-note' to record titles.")

(defvar usls--category-history nil
  "Used internally by `usls-new-note' to record categories.")

(defvar usls--link-history nil
  "Used internally by `usls-id-insert' to record links.")

;;; Interactive functions

;;;###autoload
(defun usls-new-note ()
  "Create new note with the appropriate metadata.
If the region is active, append it to the newly created file."
  (interactive)
  (let* ((titlehist '(usls--title-history . 0))
         (cathist '(usls--category-history . 0))
         (title (read-string "File title: " nil titlehist))
         (categories (usls-categories))
         (crm-separator "[, ]") ; Insert multiple categories with comma/space between them
         (category (completing-read-multiple "File category: " categories nil nil nil cathist))
         (slug (usls-sluggify title))
         (path (file-name-as-directory usls-directory))
         (id (format-time-string usls-id))
         (filename
          (format "%s%s--%s--%s.txt"
                  path
                  id
                  (mapconcat #'downcase category "-")
                  slug))
         (date (format-time-string "%F"))
         (region (with-current-buffer (current-buffer)
                   (if (region-active-p)
                       (concat "\n\n* * *\n\n"
                               (buffer-substring-no-properties
                                (region-beginning)
                                (region-end)))
                     ""))))
    (with-current-buffer (find-file filename)
      (usls-mode 1)
      (insert (concat "title: " title "\n"
                      "date: " date "\n"
                      "category: " (mapconcat #'capitalize category ", ") "\n"
                      "orig_name: " filename "\n"
                      "orig_id: " id "\n"))
      (insert-char ?- 24 nil)
      (insert "\n\n")
      (save-excursion (insert region)))
    (add-to-history 'usls--title-history title)
    (add-to-history 'usls--category-history category)))

(defun usls--directory-files-not-current ()
  "Return list of files minus the current one."
  (cl-remove-if
   (lambda (x)
     (string= (file-name-nondirectory (buffer-file-name)) x))
   (usls--directory-files)))

(defun usls--insert-file-reference (file delimiter)
  "Insert formatted reference to FILE with DELIMITER."
  (save-excursion
    (goto-char (point-max))
    (newline 1)
    (insert
     (format "%s %s\n" delimiter file))))

(defun usls--delete-duplicate-links ()
  "Remove duplicate references to files."
  (delete-duplicate-lines
   (save-excursion
     (goto-char (point-min))
     (search-forward-regexp "\\(@@\\|\\^\\^\\) " nil t nil))
   (point-max)))

;;;###autoload
(defun usls-id-insert ()
  "Insert at point the identity of a file using completion."
  (interactive)
  (let* ((file (completing-read "Link to: "
                                (usls--directory-files-not-current)
                                nil t nil 'usls--link-history))
         (this-file (file-name-nondirectory (buffer-file-name)))
         (id (usls-extract usls-id-regexp file)))
    (insert (concat "^" id))
    (usls--insert-file-reference (format "%s" file) "^^")
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (usls--insert-file-reference this-file "@@")
        (usls--delete-duplicate-links))
      (save-buffer)
      (kill-buffer))
    (usls--delete-duplicate-links)
    (add-to-history 'usls--link-history file)))

(defvar usls--file-link-regexp "\\(^\\^\\^ \\)\\(.*\\.txt\\)"
  "Regexp for file links at the end of the buffer.")

(defun usls--links ()
  "Gather links to files in the current buffer."
  (let ((links))
    (save-excursion
      (goto-char (point-min))
      (while (search-forward-regexp usls--file-link-regexp nil t)
        (push (match-string-no-properties 2) links)))
    (cl-remove-duplicates links)))

;;;###autoload
(defun usls-follow-link ()
  "Visit link referenced in the note using completion."
  (interactive)
  (let ((links (usls--links)))
    (if links
        (find-file
         (completing-read "Follow link: " links nil t))
      (usls-find-file))))

(defun usls--file-name (file)
  "Return properly formatted name of FILE."
  (pcase usls-directory-files-function
    ('directory-files-recursively
     (file-truename file))
    (_
     (concat (file-truename (concat usls-directory file))))))

;;;###autoload
(defun usls-find-file ()
  "Visit a file in `usls-directory' using completion."
  (interactive)
  (let* ((files (usls--directory-files))
         (file (completing-read "Visit file: " files nil t nil 'usls--link-history))
         (item (usls--file-name file)))
    (find-file item)
    (add-to-history 'usls--link-history item)))

;;;###autoload
(defun usls-dired ()
  "Switch to `usls-directory'."
  (interactive)
  (let ((path usls-directory))
    (if (file-directory-p path)
        (dired path)
      (error "`usls-directory' not found"))))

;;; User-facing setup

;; TODO: how to define a prefix key?
;;
;; NOTE: Users are expected to bind this to something more useful.  Did
;; not want to violate key binding conventions.
(global-set-key (kbd "C-c _ d") 'usls-dired)
(global-set-key (kbd "C-c _ f") 'usls-find-file)
(global-set-key (kbd "C-c _ n") 'usls-new-note)

(defvar usls-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c _ i") 'usls-id-insert)
    (define-key map (kbd "C-c _ l") 'usls-follow-link)
    map)
  "Key map for use when variable `usls-mode' is non-nil.")

(defvar usls-mode-hook nil
  "Hook called when variable `usls-mode' is non-nil.")

(define-minor-mode usls-mode
  "Extras for working with `usls' notes.

\\{usls-mode-map}"
  :init-value nil
  :global nil
  :lighter " usls"
  :keymap usls-mode-map
  (run-hooks 'usls-mode-hook))

(defun usls-mode-activate ()
  "Activate mode when inside `usls-directory'."
  (when (or (string-match-p (expand-file-name usls-directory) default-directory)
            (string-match-p usls-directory default-directory))
    (usls-mode 1)))

(add-hook 'find-file-hook #'usls-mode-activate)
(add-hook 'dired-mode-hook #'usls-mode-activate)

(defgroup usls-faces ()
  "Faces for `usls-mode'."
  :group 'faces)

(defface usls-header-data-date
  '((default :inherit bold)
    (((class color) (min-colors 88) (background light))
     :foreground "#0031a9")
    (((class color) (min-colors 88) (background dark))
     :foreground "#2fafff")
    (t :foreground "blue"))
  "Face for header date entry.")

(defface usls-header-data-category
  '((default :inherit bold)
    (((class color) (min-colors 88) (background light))
     :foreground "#721045")
    (((class color) (min-colors 88) (background dark))
     :foreground "#feacd0")
    (t :foreground "magenta"))
  "Face for header category entry.")

(defface usls-header-data-title
  '((default :inherit bold)
    (((class color) (min-colors 88) (background light))
     :foreground "#000000")
    (((class color) (min-colors 88) (background dark))
     :foreground "#ffffff")
    (t :foreground "blue"))
  "Face for header title entry.")

(defface usls-header-data-secondary
  '((((class color) (min-colors 88) (background light))
     :foreground "#093060")
    (((class color) (min-colors 88) (background dark))
     :foreground "#c6eaff")
    (t :inherit (bold shadow)))
  "Face for secondary header information.")

(defface usls-header-data-key
  '((((class color) (min-colors 88) (background light))
     :foreground "#505050")
    (((class color) (min-colors 88) (background dark))
     :foreground "#a8a8a8")
    (t :inherit shadow))
  "Face for secondary header information.")

(defface usls-section-delimiter
  '((((class color) (min-colors 88) (background light))
     :background "#d7d7d7" :foreground "#404148")
    (((class color) (min-colors 88) (background dark))
     :background "#323232" :foreground "#bfc0c4")
    (t :inherit shadow))
  "Face for section delimiters.")

(defface usls-dired-field-date
  '((((class color) (min-colors 88) (background light))
     :foreground "#2544bb")
    (((class color) (min-colors 88) (background dark))
     :foreground "#79a8ff")
    (t :inherit font-lock-string-face))
  "Face for file name date in `dired-mode' buffers.")

(defface usls-dired-field-delimiter
  '((t :inherit shadow))
  "Face for file name field delimiters in `dired-mode' buffers.")

(defface usls-dired-field-category
  '((((class color) (min-colors 88) (background light))
     :foreground "#8f0075")
    (((class color) (min-colors 88) (background dark))
     :foreground "#f78fe7")
    (t :inherit font-lock-builtin-face))
  "Face for file name category in `dired-mode' buffers.")

(defface usls-dired-field-name
  '((((class color) (min-colors 88) (background light))
     :foreground "#000000")
    (((class color) (min-colors 88) (background dark))
     :foreground "#ffffff")
    (t :inherit default))
  "Face for file name title in `dired-mode' buffers.")

(defconst usls-font-lock-keywords
  '(("\\(title:\\) \\(.*\\)"
     (1 'usls-header-data-key)
     (2 'usls-header-data-title))
    ("\\(date:\\) \\(.*\\)"
     (1 'usls-header-data-key)
     (2 'usls-header-data-date))
    ("\\(category:\\) \\(.*\\)"
     (1 'usls-header-data-key)
     (2 'usls-header-data-category))
    ("\\(orig_\\(name\\|id\\):\\) \\(.*\\)"
     (1 'usls-header-data-key)
     (2 'usls-header-data-key)
     (3 'usls-header-data-secondary))
    ("\\(-\\{24\\}\\|[*\s]\\{5\\}\\)"
     (1 'usls-section-delimiter))
    ("\\(\\^\\)\\([0-9_]\\{15\\}\\)"
     (1 'escape-glyph)
     (2 'font-lock-variable-name-face))
    ("\\(^\\(@@\\|\\^^\\)\\) \\([0-9_]+\\{15\\}.*\\.txt\\)"
     (1 'escape-glyph t)
     (2 'escape-glyph t)
     (3 'font-lock-constant-face t))
    ;; These conflict with `diredfl-mode'.  Maybe there is some way to
    ;; avoid that?
    ("\\([0-9_]\\{15\\}\\)\\(--\\)\\([0-9A-Za-z_-]*\\)\\(--\\)\\(.*\\)\\(\\.txt\\)"
     (1 'usls-dired-field-date)
     (2 'usls-dired-field-delimiter)
     (3 'usls-dired-field-category)
     (4 'usls-dired-field-delimiter)
     (5 'usls-dired-field-name)
     (6 'usls-dired-field-delimiter)))
  "Rules to apply font-lock highlighting with `usls--fontify'.")

(defun usls--fontify ()
  "Font-lock setup for `usls-font-lock-keywords'."
  (font-lock-flush (point-min) (point-max))
  (if usls-mode
      (font-lock-add-keywords nil usls-font-lock-keywords)
    (font-lock-remove-keywords nil usls-font-lock-keywords))
  (font-lock-flush (point-min) (point-max)))

(add-hook 'usls-mode-hook #'usls--fontify)

(provide 'usls)

;;; usls.el ends here
