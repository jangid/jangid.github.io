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
(require 'cl-lib)

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

;; ---------------------------------------------------------------------------
;; Notes manifest: scans src/notes/*.org, reads #+TITLE and #+DATE,
;; sorts newest-first. Used to emit prev/next links on each article.
;; Built once per publish run via :preparation-function on the notes project.

(defvar jangid--notes-manifest nil
  "List of (BASENAME TITLE DATE) entries for notes, newest first.")

(defun jangid--read-note-meta (file)
  "Return (BASENAME TITLE DATE) for FILE, or nil when either is missing.
Notes without a #+DATE (e.g. the index) are skipped."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((title nil) (date nil))
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\([A-Za-z]+\\):[ \t]*\\(.*\\)$" nil t)
        (let ((k (upcase (match-string 1)))
              (v (string-trim (match-string 2))))
          (cond
           ((string= k "TITLE") (setq title v))
           ((string= k "DATE") (setq date v)))))
      (when (and title date (not (string-empty-p date)))
        (list (file-name-base file) title date)))))

(defun jangid--build-notes-manifest (&rest _)
  "Scan the notes directory and cache a sorted manifest (newest first)."
  (let* ((dir (expand-file-name "notes/" jangid-src))
         (files (directory-files dir t "\\.org\\'"))
         (entries (delq nil (mapcar #'jangid--read-note-meta files))))
    (setq jangid--notes-manifest
          (sort entries (lambda (a b) (string> (nth 2 a) (nth 2 b)))))
    (message "jangid: built notes manifest with %d entries"
             (length jangid--notes-manifest))))

(defun jangid--prev-next-html (info)
  "Return HTML for prev/next navigation based on the current note's position.
Returns nil when the current file is not in the manifest (e.g. index)."
  (let* ((file (plist-get info :input-file))
         (base (and file (file-name-base file)))
         (manifest jangid--notes-manifest)
         (idx (and base manifest
                   (cl-position base manifest
                                :key #'car :test #'string=))))
    (when idx
      ;; manifest is newest-first: idx-1 = newer, idx+1 = older
      (let ((newer (and (> idx 0) (nth (1- idx) manifest)))
            (older (and (< (1+ idx) (length manifest))
                        (nth (1+ idx) manifest))))
        (when (or newer older)
          (concat
           "<nav class=\"prev-next\">"
           (if newer
               (format "<a class=\"newer\" href=\"./%s.html\">&larr; Newer: %s</a>"
                       (nth 0 newer)
                       (org-html-encode-plain-text (nth 1 newer)))
             "<span></span>")
           (if older
               (format "<a class=\"older\" href=\"./%s.html\">Older: %s &rarr;</a>"
                       (nth 0 older)
                       (org-html-encode-plain-text (nth 1 older)))
             "<span></span>")
           "</nav>"))))))

;; ---------------------------------------------------------------------------

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
     (or (jangid--prev-next-html info) "")
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
         :preparation-function jangid--build-notes-manifest
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
