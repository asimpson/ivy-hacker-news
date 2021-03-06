;;; ivy-hacker-news.el --- A scrapper that displays the front page of hackernews via Ivy.
;; -*- lexical-binding: t; -*-

;; Adam Simpson <adam@adamsimpson.net>
;; Version: 0.2.0
;; Package-Requires: ((pinboard-popular "0.1.2") (loop "1.4") (ivy "9.0"))
;; Keywords: hackernews

;;; Commentary:
;; This is a little fragile given that the class I'm using to scrape the data could disappear.

;;; Code:
(require 'loop)
(require 'ivy)
(require 'pinboard-popular)

(defun ivy-hacker-news--fetch-pinboard-token()
  "Return the pinboard API token from auth-source."
  (let ((entry (auth-source-search :host "pinboard.in" :max 1)))
    (funcall (plist-get (car entry) :secret))))

;;;###autoload
(defun ivy-hacker-news()
  "Browse hackernews from Ivy."
  (interactive)
  (let ((url "https://news.ycombinator.com/news") links)
    (with-current-buffer (url-retrieve-synchronously url t)
      (keep-lines "storylink")
      (kill-new (buffer-substring-no-properties url-http-end-of-headers (point-max)))
      (loop-for-each-line
        (unless (= (point-max) (point))
          (push (let (title link id)
                  (when (ignore-errors (re-search-forward "storylink"))
                    (re-search-backward "<")
                    (setq link (substring (pinboard-popular--re-capture-between "href=\\\"" "\\\"") 0 -1))
                    (setq title (decode-coding-string (substring (pinboard-popular--re-capture-between ">" "<") 0 -1) 'utf-8))
                    (move-beginning-of-line nil)
                    (setq id (concat "https://news.ycombinator.com/item?id=" (buffer-substring-no-properties (re-search-forward "up_") (- (re-search-forward "'") 1))))
                    `(,title :title ,title :link ,link :id ,id))) links))))
    (ivy-read "Hackernews: " (reverse (seq-uniq links))
              :action (lambda(link) (browse-url (plist-get (cdr link) :link))))))

(ivy-set-actions 'ivy-hacker-news
                 '(("c" (lambda(item) (browse-url (plist-get (cdr item) :id))) "Jump to comments")
                   ("r" (lambda (item)
                          (url-retrieve-synchronously (concat "https://api.pinboard.in/v1/posts/add?auth_token="
                                                              (ivy-hacker-news--fetch-pinboard-token)
                                                              "&url="
                                                              (plist-get (cdr item) :link)
                                                              "&description="
                                                              (plist-get (cdr item) :title)
                                                              "&extended="
                                                              (concat "HN comments: " (plist-get (cdr item) :id))
                                                              "&toread=yes"))) "Save as unread in pinboard")
                   ("v" (lambda(item) (eww (plist-get (cdr item) :link))) "View in Emacs")))

(provide 'ivy-hacker-news)

;;; ivy-hacker-news.el ends here
