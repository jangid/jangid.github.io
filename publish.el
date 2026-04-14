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
(require 'xml)

;; Resolve project root to the directory containing this script
(defvar jangid-root
  (file-name-directory (or load-file-name buffer-file-name default-directory)))

(defvar jangid-src (expand-file-name "src/" jangid-root))
(defvar jangid-docs (expand-file-name "docs/" jangid-root))

(defconst jangid-site-url "https://jangid.info"
  "Canonical root URL of the site (no trailing slash).")

(defconst jangid-site-title "Pankaj Jangid"
  "Site title used in OpenGraph and feed metadata.")

(defconst jangid-site-description
  "Notes by Pankaj Jangid on software engineering, entrepreneurship, governance, and the craft of building products, teams, and systems -- an archive that spans over two decades of writing."
  "Default site-wide description used when a page lacks its own.")

(defconst jangid-twitter-handle "@jangid")

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
;; Shared meta helpers.  Canonical URL + OpenGraph + Twitter card tags are
;; emitted on every page (both org-published and directly generated) so
;; shares on LinkedIn / X render a proper preview.

(defun jangid--xml-escape (s)
  "Escape S for inclusion in attribute values or XML text."
  (if s (xml-escape-string s) ""))

(defun jangid--canonical-url (rel-html-path)
  "Build the canonical URL for REL-HTML-PATH (relative to docs root).
Strips trailing \"index.html\" so directory pages use the clean URL that
GitHub Pages actually serves."
  (let ((clean (replace-regexp-in-string "\\(\\`\\|/\\)index\\.html\\'"
                                         (lambda (m) (if (string= m "index.html") "" "/"))
                                         rel-html-path)))
    (concat jangid-site-url "/" clean)))

(defun jangid--meta-head (&rest args)
  "Build per-page <head> meta for canonical, OG, Twitter, and feed discovery.
Accepts a plist with :url :title :description :type :image keys.  Missing
values fall back to site defaults.  When :image is non-nil the Twitter Card
type is upgraded to `summary_large_image' so the picture is actually shown."
  (let* ((url (or (plist-get args :url) jangid-site-url))
         (title (or (plist-get args :title) jangid-site-title))
         (desc (or (plist-get args :description) jangid-site-description))
         (og-type (or (plist-get args :type) "website"))
         (image-path (plist-get args :image))
         (image-url (and image-path
                         (if (string-match-p "\\`https?://" image-path)
                             image-path
                           (concat jangid-site-url image-path))))
         (twitter-card (if image-url "summary_large_image" "summary")))
    (mapconcat
     #'identity
     (delq
      nil
      (list
       (format "<link rel=\"canonical\" href=\"%s\"/>" (jangid--xml-escape url))
       (format "<meta name=\"description\" content=\"%s\"/>" (jangid--xml-escape desc))
       (format "<meta property=\"og:type\" content=\"%s\"/>" og-type)
       (format "<meta property=\"og:site_name\" content=\"%s\"/>"
               (jangid--xml-escape jangid-site-title))
       (format "<meta property=\"og:title\" content=\"%s\"/>" (jangid--xml-escape title))
       (format "<meta property=\"og:description\" content=\"%s\"/>" (jangid--xml-escape desc))
       (format "<meta property=\"og:url\" content=\"%s\"/>" (jangid--xml-escape url))
       (when image-url
         (format "<meta property=\"og:image\" content=\"%s\"/>"
                 (jangid--xml-escape image-url)))
       (when image-url
         (format "<meta property=\"og:image:alt\" content=\"%s\"/>"
                 (jangid--xml-escape title)))
       (format "<meta name=\"twitter:card\" content=\"%s\"/>" twitter-card)
       (format "<meta name=\"twitter:site\" content=\"%s\"/>" jangid-twitter-handle)
       (format "<meta name=\"twitter:title\" content=\"%s\"/>" (jangid--xml-escape title))
       (format "<meta name=\"twitter:description\" content=\"%s\"/>" (jangid--xml-escape desc))
       (when image-url
         (format "<meta name=\"twitter:image\" content=\"%s\"/>"
                 (jangid--xml-escape image-url)))
       (format "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"%s\" href=\"/notes/feed.xml\"/>"
               (jangid--xml-escape (concat jangid-site-title " — Notes")))))
     "\n")))

(defun jangid--extract-first-image ()
  "Scan current buffer for the first org image link and return an /images/X path,
or nil if no image is found.  Accepts link forms `[[file:../images/X]]',
`[[./images/X]]', or `[[images/X]]'."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward
           "\\[\\[\\(?:file:\\)?\\(?:\\.\\./\\|\\./\\)?\\(images/[^]]+\\)\\]"
           nil t)
      (concat "/" (match-string 1)))))

(defun jangid--normalise-image-path (raw)
  "Accept an absolute URL, site-absolute path, or relative path; return a
site-absolute path (starting with /) or a full URL unchanged."
  (cond
   ((null raw) nil)
   ((string-match-p "\\`https?://" raw) raw)
   ((string-prefix-p "/" raw) raw)
   (t (concat "/" raw))))

(defun jangid--extract-file-meta ()
  "Return (TITLE DESCRIPTION IMAGE-PATH) for the current buffer.
TITLE and DESCRIPTION come from file-level keywords.  IMAGE-PATH prefers an
explicit #+OG_IMAGE override, then falls back to the first embedded image
link in the body (e.g. \"/images/foo.png\"), or nil when neither exists."
  (let (title description og-image)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\([A-Za-z_]+\\):[ \t]*\\(.*\\)$" nil t)
        (let ((k (upcase (match-string 1)))
              (v (string-trim (match-string 2))))
          (cond
           ((string= k "TITLE") (setq title v))
           ((string= k "DESCRIPTION") (setq description v))
           ((string= k "OG_IMAGE") (setq og-image v))))))
    (list title
          description
          (jangid--normalise-image-path
           (or (and og-image (not (string-empty-p og-image)) og-image)
               (jangid--extract-first-image))))))

(defun jangid--read-file-meta (file)
  "Read TITLE and DESCRIPTION from FILE's file-level keywords."
  (with-temp-buffer
    (insert-file-contents file)
    (jangid--extract-file-meta)))

(defun jangid--publish-html-with-meta (plist filename pub-dir)
  "Wrapper around `org-html-publish-to-html' that injects per-file meta.
Adds canonical, OpenGraph, Twitter Card, and RSS discovery tags to
`:html-head-extra' based on the source file's #+TITLE and #+DESCRIPTION."
  (let* ((rel (file-relative-name filename jangid-src))
         (html-rel (replace-regexp-in-string "\\.org\\'" ".html" rel))
         (url (jangid--canonical-url html-rel))
         (meta (jangid--read-file-meta filename))
         (title (car meta))
         (desc (cadr meta))
         (image (nth 2 meta))
         (is-note (string-prefix-p "notes/" rel))
         (og-type (if is-note "article" "website"))
         (head (jangid--meta-head :url url
                                  :title title
                                  :description desc
                                  :type og-type
                                  :image image))
         (prev-extra (or (plist-get plist :html-head-extra) ""))
         (new-plist (org-combine-plists
                     plist
                     (list :html-head-extra
                           (concat prev-extra "\n" head)))))
    (org-html-publish-to-html new-plist filename pub-dir)))

;; ---------------------------------------------------------------------------
;; Notes manifest: scans src/notes/*.org, reads #+TITLE and #+DATE,
;; sorts newest-first. Used to emit prev/next links on each article.
;; Built once per publish run via :preparation-function on the notes project.

(defvar jangid--notes-manifest nil
  "List of (BASENAME TITLE DATE) entries for notes, newest first.")

(defun jangid--read-note-meta (file)
  "Return a plist of metadata for FILE, or nil when required fields missing.
Keys: :base :title :date :updated :description :tags.
Notes without #+DATE are skipped."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((title nil) (date nil) (updated nil) (description nil) (tags nil))
      (goto-char (point-min))
      (while (re-search-forward "^#\\+\\([A-Za-z_]+\\):[ \t]*\\(.*\\)$" nil t)
        (let ((k (upcase (match-string 1)))
              (v (string-trim (match-string 2))))
          (cond
           ((string= k "TITLE") (setq title v))
           ((string= k "DATE") (setq date v))
           ((string= k "UPDATED") (setq updated v))
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
              :updated (and updated (not (string-empty-p updated)) updated)
              :description description
              :tags tags)))))

(defun jangid--format-date (iso)
  "Format an ISO YYYY-MM-DD date as \"14 Apr 2026\".  Returns ISO on failure."
  (condition-case nil
      (format-time-string
       "%d %b %Y"
       (date-to-time (concat iso "T00:00:00Z")) t)
    (error iso)))

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
               (format (concat "<a class=\"newer\" href=\"./%s.html\">"
                               "<span class=\"label\">Newer</span>"
                               "<span class=\"title\">&larr; %s</span>"
                               "</a>")
                       (plist-get newer :base)
                       (org-html-encode-plain-text (plist-get newer :title)))
             "<span></span>")
           (if older
               (format (concat "<a class=\"older\" href=\"./%s.html\">"
                               "<span class=\"label\">Older</span>"
                               "<span class=\"title\">%s &rarr;</span>"
                               "</a>")
                       (plist-get older :base)
                       (org-html-encode-plain-text (plist-get older :title)))
             "<span></span>")
           "</nav>"))))))

;; ---------------------------------------------------------------------------
;; Eyebrow: per-article tag label rendered above <h1 class="title">.
;; Pulled from the manifest so it mirrors #+FILETAGS without needing the
;; author to mark anything up.  Only runs on files that are part of the
;; notes manifest (articles); other pages pass through unchanged.

(defun jangid--eyebrow-html (tags)
  "Render the small-caps accent-color TAG · TAG label list for TAGS."
  (when tags
    (concat
     "<p class=\"eyebrow\">"
     (mapconcat
      (lambda (tag)
        (format "<a href=\"/notes/tags/%s.html\">%s</a>"
                (jangid--tag-slug tag)
                (org-html-encode-plain-text tag)))
      tags
      "<span class=\"sep\">·</span>")
     "</p>")))

(defun jangid--byline-html (date updated)
  "Render a Public-Sans small-caps byline with Published and optional Updated."
  (concat
   "<p class=\"byline\">"
   "Published " (jangid--format-date date)
   (when updated
     (concat " <span class=\"sep\">·</span> Updated "
             (jangid--format-date updated)))
   "</p>"))

(defun jangid--inject-article-header (text backend info)
  "Final-output filter: on articles, inject eyebrow before and byline after
<h1 class=\"title\">.  Non-article pages (not in the notes manifest) pass
through unchanged."
  (if (and (eq backend 'html)
           jangid--notes-manifest)
      (let* ((input-file (plist-get info :input-file))
             (base (and input-file (file-name-base input-file)))
             (entry (and base
                         (cl-find base jangid--notes-manifest
                                  :key (lambda (e) (plist-get e :base))
                                  :test #'string=))))
        (if entry
            (let* ((tags (plist-get entry :tags))
                   (date (plist-get entry :date))
                   (updated (plist-get entry :updated))
                   (eyebrow (and tags (jangid--eyebrow-html tags)))
                   (byline (and date (jangid--byline-html date updated)))
                   ;; Insert eyebrow before the opening h1 tag.
                   (after-eyebrow
                    (if eyebrow
                        (replace-regexp-in-string
                         "<h1 class=\"title\">"
                         (concat eyebrow "<h1 class=\"title\">")
                         text t t)
                      text))
                   ;; Then insert byline after the closing </h1>.
                   (close-pos (string-match "</h1>" after-eyebrow)))
              (if (and byline close-pos)
                  (concat (substring after-eyebrow 0 (+ close-pos 5))
                          byline
                          (substring after-eyebrow (+ close-pos 5)))
                after-eyebrow))
          text))
    text))

(add-to-list 'org-export-filter-final-output-functions
             #'jangid--inject-article-header)

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
     (format " <time class=\"date\" datetime=\"%s\">%s</time>"
             date (jangid--format-date date))
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

(defun jangid--wrap-html (title css-href body &optional extra-head)
  "Emit a full HTML document that mirrors org-publish output so CSS matches.
EXTRA-HEAD is inserted inside <head> (e.g. canonical + OG tags)."
  (format "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\"/>
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
<title>%s</title>
<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\"/>
%s
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
          (or extra-head "")
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
         (out (expand-file-name "notes/index.html" jangid-docs))
         (head (jangid--meta-head
                :url (concat jangid-site-url "/notes/")
                :title (concat jangid-site-title " — Notes")
                :description
                "Complete archive of notes by Pankaj Jangid covering software engineering, entrepreneurship, governance, and personal reflections -- grouped by year and browsable by tag."
                :type "website")))
    (with-temp-file out
      (insert (jangid--wrap-html "Notes" "../css/main.css" body head)))
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
             (out (expand-file-name (concat slug ".html") tags-dir))
             (page-title (format "Tagged: %s" tag))
             (head (jangid--meta-head
                    :url (concat jangid-site-url "/notes/tags/" slug ".html")
                    :title (concat page-title " — " jangid-site-title)
                    :description
                    (format "All notes on jangid.info tagged \"%s\" -- part of a writing archive by Pankaj Jangid covering software engineering, entrepreneurship, governance, and personal reflections."
                            tag)
                    :type "website")))
        (with-temp-file out
          (insert (jangid--wrap-html page-title "../../css/main.css" body head)))
        (message "jangid: wrote %s" out)))))

(defun jangid--rfc822-date (iso)
  "Convert YYYY-MM-DD string ISO to an RFC 822 date suitable for RSS."
  (format-time-string
   "%a, %d %b %Y 00:00:00 +0000"
   (date-to-time (concat iso "T00:00:00Z")) t))

(defun jangid--write-rss ()
  "Generate docs/notes/feed.xml from the manifest."
  (let* ((out (expand-file-name "notes/feed.xml" jangid-docs))
         (feed-url (concat jangid-site-url "/notes/feed.xml"))
         (notes-url (concat jangid-site-url "/notes/"))
         (build-date (format-time-string "%a, %d %b %Y %H:%M:%S +0000" nil t))
         (last-build
          (or (and jangid--notes-manifest
                   (jangid--rfc822-date
                    (plist-get (car jangid--notes-manifest) :date)))
              build-date))
         (items
          (mapconcat
           (lambda (e)
             (let* ((base (plist-get e :base))
                    (title (plist-get e :title))
                    (desc (or (plist-get e :description) ""))
                    (date (plist-get e :date))
                    (link (concat jangid-site-url "/notes/" base ".html")))
               (concat
                "    <item>\n"
                (format "      <title>%s</title>\n" (jangid--xml-escape title))
                (format "      <link>%s</link>\n" (jangid--xml-escape link))
                (format "      <guid isPermaLink=\"true\">%s</guid>\n"
                        (jangid--xml-escape link))
                (format "      <pubDate>%s</pubDate>\n" (jangid--rfc822-date date))
                (format "      <description>%s</description>\n"
                        (jangid--xml-escape desc))
                "    </item>\n")))
           jangid--notes-manifest
           "")))
    (with-temp-file out
      (insert
       "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
       "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n"
       "  <channel>\n"
       (format "    <title>%s — Notes</title>\n"
               (jangid--xml-escape jangid-site-title))
       (format "    <link>%s</link>\n" (jangid--xml-escape notes-url))
       (format "    <description>%s</description>\n"
               (jangid--xml-escape jangid-site-description))
       "    <language>en</language>\n"
       (format "    <lastBuildDate>%s</lastBuildDate>\n" last-build)
       (format "    <atom:link href=\"%s\" rel=\"self\" type=\"application/rss+xml\"/>\n"
               (jangid--xml-escape feed-url))
       items
       "  </channel>\n"
       "</rss>\n"))
    (message "jangid: wrote %s" out)))

(defun jangid--write-sitemap ()
  "Generate docs/sitemap.xml covering home, notes index, notes, and tag pages."
  (let* ((out (expand-file-name "sitemap.xml" jangid-docs))
         (entries
          (append
           (list (concat jangid-site-url "/")
                 (concat jangid-site-url "/notes/"))
           (mapcar (lambda (e)
                     (concat jangid-site-url "/notes/"
                             (plist-get e :base) ".html"))
                   jangid--notes-manifest)
           (mapcar (lambda (tag)
                     (concat jangid-site-url "/notes/tags/"
                             (jangid--tag-slug tag) ".html"))
                   (jangid--all-tags)))))
    (with-temp-file out
      (insert
       "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
       "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
       (mapconcat
        (lambda (u) (format "  <url><loc>%s</loc></url>\n" (jangid--xml-escape u)))
        entries "")
       "</urlset>\n"))
    (message "jangid: wrote %s" out)))

(defun jangid--write-robots ()
  "Generate docs/robots.txt pointing at the sitemap."
  (let ((out (expand-file-name "robots.txt" jangid-docs)))
    (with-temp-file out
      (insert
       "User-agent: *\n"
       "Allow: /\n"
       "\n"
       (format "Sitemap: %s/sitemap.xml\n" jangid-site-url)))
    (message "jangid: wrote %s" out)))

;; ---------------------------------------------------------------------------

;; Navigation bar HTML
(defvar jangid-nav
  "<nav class=\"site-nav\"><a href=\"/\">Home</a><a href=\"/notes/\">Notes</a></nav>")

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
  "Postamble for notes: prev/next navigation then shared site footer.
The Published/Updated byline is injected directly below the article
title by `jangid--inject-article-header', not here."
  (concat
   (or (jangid--prev-next-html info) "")
   (jangid--footer-html)))

(defun jangid-pages-postamble (info)
  "Postamble for top-level pages: just the site footer."
  (jangid--footer-html))

(setq org-publish-project-alist
      `(("pages"
         :base-directory ,jangid-src
         :publishing-directory ,jangid-docs
         :publishing-function jangid--publish-html-with-meta
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"css/main.css\" />"
         :with-toc nil
         :html-preamble ,jangid-nav
         :html-postamble jangid-pages-postamble
         :section-numbers nil
         :html-prefer-user-labels t)
        ("notes"
         :base-directory ,(expand-file-name "notes/" jangid-src)
         :publishing-directory ,(expand-file-name "notes/" jangid-docs)
         :publishing-function jangid--publish-html-with-meta
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
         :base-extension any
         :recursive t
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
(jangid--write-rss)
(jangid--write-sitemap)
(jangid--write-robots)

(message "Done.")
