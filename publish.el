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
  "Return a plist of metadata for FILE, or nil when required fields missing.
Keys: :base :title :date :description :tags.  Notes without #+DATE are skipped."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((title nil) (date nil) (description nil) (tags nil))
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\([A-Za-z_]+\\):[ \t]*\\(.*\\)$" nil t)
        (let ((k (upcase (match-string 1)))
              (v (string-trim (match-string 2))))
          (cond
           ((string= k "TITLE") (setq title v))
           ((string= k "DATE") (setq date v))
           ((string= k "DESCRIPTION") (setq description v))
           ((string= k "FILETAGS")
            ;; #+FILETAGS: :tech:governance: or space-separated words
            (setq tags
                  (cl-remove-if
                   #'string-empty-p
                   (split-string v "[: \t]+" t)))))))
      (when (and title date (not (string-empty-p date)))
        (list :base (file-name-base file)
              :title title
              :date date
              :description description
              :tags tags)))))

(defun jangid--build-notes-manifest (&rest _)
  "Scan the notes directory and cache a sorted manifest (newest first)."
  (let* ((dir (expand-file-name "notes/" jangid-src))
         (files (directory-files dir t "\\.org\\'"))
         (entries (delq nil (mapcar #'jangid--read-note-meta files))))
    (setq jangid--notes-manifest
          (sort entries
                (lambda (a b)
                  (string> (plist-get a :date) (plist-get b :date)))))
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
                                :key (lambda (e) (plist-get e :base))
                                :test #'string=))))
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
                       (plist-get newer :base)
                       (org-html-encode-plain-text (plist-get newer :title)))
             "<span></span>")
           (if older
               (format "<a class=\"older\" href=\"./%s.html\">Older: %s &rarr;</a>"
                       (plist-get older :base)
                       (org-html-encode-plain-text (plist-get older :title)))
             "<span></span>")
           "</nav>"))))))

;; ---------------------------------------------------------------------------
;; Index and tag-page generation.  These write directly into docs/ after
;; the main org-publish run, so we don't need to ship generated .org files
;; in the source tree.

(defun jangid--tag-slug (tag)
  "Normalise TAG into a URL-safe slug."
  (downcase (replace-regexp-in-string "[^A-Za-z0-9]+" "-" tag)))

(defun jangid--all-tags ()
  "Return sorted unique list of tags used across notes."
  (sort (cl-remove-duplicates
         (apply #'append
                (mapcar (lambda (e) (plist-get e :tags))
                        jangid--notes-manifest))
         :test #'string=)
        #'string<))

(defun jangid--render-entry (entry &optional link-prefix)
  "Render a single note ENTRY as an <li>.  LINK-PREFIX is prepended to article hrefs."
  (let* ((prefix (or link-prefix ""))
         (title (org-html-encode-plain-text (plist-get entry :title)))
         (base (plist-get entry :base))
         (date (plist-get entry :date))
         (desc (plist-get entry :description))
         (tags (plist-get entry :tags)))
    (concat
     "<li class=\"note-entry\">"
     (format "<a class=\"title\" href=\"%s%s.html\">%s</a>" prefix base title)
     (format " <span class=\"date\">%s</span>" date)
     (when (and desc (not (string-empty-p desc)))
       (format "<p class=\"teaser\">%s</p>"
               (org-html-encode-plain-text desc)))
     (when tags
       (concat
        "<div class=\"tags\">"
        (mapconcat
         (lambda (tag)
           (format "<a class=\"tag-chip\" href=\"%stags/%s.html\">%s</a>"
                   prefix (jangid--tag-slug tag)
                   (org-html-encode-plain-text tag)))
         tags " ")
        "</div>"))
     "</li>")))

(defun jangid--group-by-year (entries)
  "Group ENTRIES by year of their :date field.  Returns ((YEAR . ENTRIES) ...) newest first."
  (let ((groups nil))
    (dolist (e entries)
      (let* ((year (substring (plist-get e :date) 0 4))
             (cell (assoc year groups)))
        (if cell
            (setcdr cell (append (cdr cell) (list e)))
          (push (cons year (list e)) groups))))
    (sort groups (lambda (a b) (string> (car a) (car b))))))

(defun jangid--wrap-html (title css-href body)
  "Emit a full HTML document that mirrors org-publish output so CSS matches."
  (format "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\"/>
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
<title>%s</title>
<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\"/>
</head>
<body>
<div id=\"preamble\" class=\"status\">%s</div>
<div id=\"content\" class=\"content\">
<h1 class=\"title\">%s</h1>
%s
</div>
<div id=\"postamble\" class=\"status\">%s</div>
</body>
</html>\n"
          (org-html-encode-plain-text title)
          css-href
          jangid-nav
          (org-html-encode-plain-text title)
          body
          (jangid--footer-html)))

(defun jangid--write-notes-index ()
  "Generate docs/notes/index.html from the manifest."
  (let* ((all-tags (jangid--all-tags))
         (groups (jangid--group-by-year jangid--notes-manifest))
         (browse
          (if all-tags
              (concat
               "<p class=\"tags-browse\">Browse by tag: "
               (mapconcat
                (lambda (tag)
                  (format "<a href=\"./tags/%s.html\">%s</a>"
                          (jangid--tag-slug tag)
                          (org-html-encode-plain-text tag)))
                all-tags " &middot; ")
               "</p>")
            ""))
         (body
          (concat
           browse
           (mapconcat
            (lambda (group)
              (concat
               (format "<h2>%s</h2>\n" (car group))
               "<ul class=\"notes-list\">\n"
               (mapconcat (lambda (e) (jangid--render-entry e "./"))
                          (cdr group) "\n")
               "\n</ul>\n"))
            groups "\n")))
         (out (expand-file-name "notes/index.html" jangid-docs)))
    (with-temp-file out
      (insert (jangid--wrap-html "Notes" "../css/main.css" body)))
    (message "jangid: wrote %s" out)))

(defun jangid--write-tag-pages ()
  "Generate one docs/notes/tags/<slug>.html per tag in the manifest."
  (let ((tags-dir (expand-file-name "notes/tags/" jangid-docs)))
    (make-directory tags-dir t)
    (dolist (tag (jangid--all-tags))
      (let* ((slug (jangid--tag-slug tag))
             (matches
              (cl-remove-if-not
               (lambda (e) (member tag (plist-get e :tags)))
               jangid--notes-manifest))
             (groups (jangid--group-by-year matches))
             (body
              (concat
               (format "<p class=\"tags-browse\"><a href=\"../\">&larr; All notes</a></p>")
               (mapconcat
                (lambda (group)
                  (concat
                   (format "<h2>%s</h2>\n" (car group))
                   "<ul class=\"notes-list\">\n"
                   (mapconcat (lambda (e) (jangid--render-entry e "../"))
                              (cdr group) "\n")
                   "\n</ul>\n"))
                groups "\n")))
             (out (expand-file-name (concat slug ".html") tags-dir)))
        (with-temp-file out
          (insert (jangid--wrap-html
                   (format "Tagged: %s" tag)
                   "../../css/main.css"
                   body)))
        (message "jangid: wrote %s" out)))))

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
         :exclude "\\`index\\.org\\'"
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

;; Manifest is built by the notes :preparation-function; generate the
;; notes index and per-tag pages directly into docs/ afterwards.
(unless jangid--notes-manifest
  (jangid--build-notes-manifest))
(jangid--write-notes-index)
(jangid--write-tag-pages)

(message "Done.")
