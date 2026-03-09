;;; publish.el --- Build codeisgreat.org site from command line
;;
;; Usage:
;;   /Applications/Emacs.app/Contents/MacOS/Emacs --batch -l publish.el
;;
;; Run from the codeisgreat directory. Generates HTML in docs/ from src/.

(require 'org)
(require 'ox-publish)
(require 'ox-html)

;; Resolve project root to the directory containing this script
(defvar codeisgreat-root
  (file-name-directory (or load-file-name buffer-file-name default-directory)))

(defvar codeisgreat-src (expand-file-name "src/" codeisgreat-root))
(defvar codeisgreat-docs (expand-file-name "docs/" codeisgreat-root))

;; Disable interactive prompts in batch mode
(setq org-confirm-babel-evaluate nil)

;; Only rebuild changed files unless FORCE_PUBLISH is set
(setq org-publish-use-timestamps-flag
      (not (getenv "FORCE_PUBLISH")))

;; Navigation bar HTML
(defvar codeisgreat-nav
  "<nav class=\"site-nav\"><a href=\"/\">Home</a> | <a href=\"/notes/\">Notes</a></nav>")

(setq org-publish-project-alist
      `(("pages"
         :base-directory ,codeisgreat-src
         :publishing-directory ,codeisgreat-docs
         :publishing-function org-html-publish-to-html
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"css/main.css\" />"
         :with-toc nil
         :html-preamble ,codeisgreat-nav
         :html-postamble t
         :html-postamble-format (("en" "<p class=\"creator\">Created with %c</p>"))
         :section-numbers nil
         :html-indent t)
        ("notes"
         :base-directory ,(expand-file-name "notes/" codeisgreat-src)
         :publishing-directory ,(expand-file-name "notes/" codeisgreat-docs)
         :publishing-function org-html-publish-to-html
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"../css/main.css\" />"
         :with-toc nil
         :with-date t
         :html-preamble ,codeisgreat-nav
         :html-postamble t
         :html-postamble-format (("en" "<p class=\"date\">Published: %d</p><p class=\"creator\">Created with %c</p>"))
         :section-numbers nil
         :html-indent t)
        ("css"
         :base-directory ,(expand-file-name "css/" codeisgreat-src)
         :base-extension "css"
         :publishing-directory ,(expand-file-name "css/" codeisgreat-docs)
         :publishing-function org-publish-attachment)
        ("images"
         :base-directory ,(expand-file-name "images/" codeisgreat-src)
         :base-extension "jpeg\\|jpg\\|gif\\|png"
         :publishing-directory ,(expand-file-name "images/" codeisgreat-docs)
         :publishing-function org-publish-attachment)
        ("other"
         :base-directory ,(expand-file-name "other/" codeisgreat-src)
         :publishing-directory ,(expand-file-name "other/" codeisgreat-docs)
         :publishing-function org-publish-attachment)
        ("website"
         :components ("pages" "notes" "images" "css" "other"))))

;; Publish
(message "Publishing codeisgreat.org from %s to %s" codeisgreat-src codeisgreat-docs)
(org-publish "website")
(message "Done.")
