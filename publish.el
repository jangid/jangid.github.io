;;; publish.el --- Build jangid.info from command line
;;
;; Usage:
;;   /Applications/Emacs.app/Contents/MacOS/Emacs --batch -l publish.el
;;
;; Run from the project root. Generates HTML in docs/ from src/.

;; Batch Emacs doesn't auto-initialise packages; htmlize lives in ELPA
(require 'package)
(package-initialize)

(require 'org)
(require 'ox-publish)
(require 'ox-html)
(require 'htmlize)

;; Resolve project root to the directory containing this script
(defvar jangid-root
  (file-name-directory (or load-file-name buffer-file-name default-directory)))

(defvar jangid-src (expand-file-name "src/" jangid-root))
(defvar jangid-docs (expand-file-name "docs/" jangid-root))

;; Disable interactive prompts in batch mode
(setq org-confirm-babel-evaluate nil)

;; Only rebuild changed files unless FORCE_PUBLISH is set
(setq org-publish-use-timestamps-flag
      (not (getenv "FORCE_PUBLISH")))

;; Register #+UPDATED: as a recognised file keyword so it lands in the
;; export info plist as :updated.
(add-to-list 'org-export-options-alist
             '(:updated "UPDATED" nil nil parse))

;; Navigation bar HTML
(defvar jangid-nav
  "<nav class=\"site-nav\"><a href=\"/\">Home</a> | <a href=\"/notes/\">Notes</a></nav>")

;; Suppress build timestamp in HTML comment to avoid noisy diffs
(setq org-html-metadata-timestamp-format "")

(defun jangid--footer-html ()
  "Shared site footer: contact, socials, license, copyright."
  (let ((year (format-time-string "%Y")))
    (concat
     "<div class=\"site-footer\">"
     "<span><a href=\"mailto:pankaj@jangid.info\">pankaj@jangid.info</a></span>"
     "<span class=\"sep\">·</span>"
     "<span><a href=\"https://x.com/jangid\" rel=\"me\">X</a></span>"
     "<span class=\"sep\">·</span>"
     "<span><a href=\"https://www.linkedin.com/in/pankaj-jangid/\" rel=\"me\">LinkedIn</a></span>"
     "<span class=\"sep\">·</span>"
     "<span><a href=\"https://github.com/jangid\" rel=\"me\">GitHub</a></span>"
     "</div>"
     (format
      (concat "<div class=\"legal\">"
              "&copy; 2005&ndash;%s Pankaj Jangid. "
              "Prose licensed under "
              "<a href=\"https://creativecommons.org/licenses/by/4.0/\">CC BY 4.0</a>; "
              "code snippets under the MIT License."
              "</div>")
      year))))

(defun jangid-notes-postamble (info)
  "Postamble for notes: published / updated dates, then site footer."
  (let* ((date (org-export-get-date info))
         (updated (plist-get info :updated))
         (updated-str (and updated (org-element-interpret-data updated))))
    (concat
     (cond
      (date
       (concat
        (format "<p class=\"date\">Published: %s"
                (org-export-data date info))
        (when (and updated-str (not (string-blank-p updated-str)))
          (format " &middot; Updated: %s" updated-str))
        "</p>"))
      (t
       (format "<p class=\"date\">Last updated: %s</p>"
               (format-time-string "%Y-%m-%d"))))
     (jangid--footer-html))))

(defun jangid-pages-postamble (info)
  "Postamble for top-level pages: just the site footer."
  (jangid--footer-html))

(setq org-publish-project-alist
      `(("pages"
         :base-directory ,jangid-src
         :publishing-directory ,jangid-docs
         :publishing-function org-html-publish-to-html
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"css/main.css\" />"
         :with-toc nil
         :html-preamble ,jangid-nav
         :html-postamble jangid-pages-postamble
         :section-numbers nil
         :html-prefer-user-labels t)
        ("notes"
         :base-directory ,(expand-file-name "notes/" jangid-src)
         :publishing-directory ,(expand-file-name "notes/" jangid-docs)
         :publishing-function org-html-publish-to-html
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"../css/main.css\" />"
         :with-toc nil
         :with-date t
         :html-preamble ,jangid-nav
         :html-postamble jangid-notes-postamble
         :section-numbers nil
         :html-prefer-user-labels t)
        ("css"
         :base-directory ,(expand-file-name "css/" jangid-src)
         :base-extension "css"
         :publishing-directory ,(expand-file-name "css/" jangid-docs)
         :publishing-function org-publish-attachment)
        ("images"
         :base-directory ,(expand-file-name "images/" jangid-src)
         :base-extension "jpeg\\|jpg\\|gif\\|png"
         :publishing-directory ,(expand-file-name "images/" jangid-docs)
         :publishing-function org-publish-attachment)
        ("other"
         :base-directory ,(expand-file-name "other/" jangid-src)
         :publishing-directory ,(expand-file-name "other/" jangid-docs)
         :publishing-function org-publish-attachment)
        ("website"
         :components ("pages" "notes" "images" "css" "other"))))

;; Publish
(message "Publishing jangid.info from %s to %s" jangid-src jangid-docs)
(org-publish "website")
(message "Done.")
