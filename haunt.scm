(use-modules (haunt asset)
             (haunt builder blog)
             (haunt builder assets)
             (haunt builder atom)
             (haunt post)
             (haunt html)
             (haunt utils)
             (haunt reader)
             (haunt reader commonmark)
             (haunt site)
             (web uri))

(define (stylesheet name)
  `(link (@ (rel "stylesheet")
            (href ,(string-append "/css/" name ".css")))))

(define (script name)
  `(script (@ (src ,(string-append "/js/" name ".js")))))

(define site-theme
  (theme #:name "site"
         #:layout (lambda (site title body)
                    `((doctype "html")
                      (head
                        (meta (@ (charset "utf-8")))
                        (title ,(string-append title " - " (site-title site)))
                        ,(stylesheet "main")
                        ,(stylesheet "normalize")
                        ,(stylesheet "prism")
                        ,(script "prism")
                        )
                      (body
                        (div (@ (class container))
                             ,body))))
         #:post-template (lambda (post)
                           `((h1 (a (@ (href "/")) 
                                    "seanplynch.com"))
                             (h2 ,(post-ref post 'title))
                             (div ,(post-sxml post))))
         #:collection-template (lambda (site title posts prefix)
                                 (define (post-uri post)
                                   (string-append "/blog/" ; This is a bit annoying
                                                  (site-post-slug site post)
                                                  ".html"))
                                 `((h1 (a (@ (href "/")) 
                                          ,title))
                                   (p 
                                    (string-append
                                     "Let's be honest. You'll find these posts"
                                     " from some search engine. If you've " 
                                     "landed here you either know me, or don't"
                                     " care what this looks like."))
                                   (ul ,@(map (lambda (post)
                                               `(li (a (@ (href ,(post-uri post)))
                                                       ,(post-ref post 'title))
                                                    " - "
                                                    ,(date->string* (post-date post))
                                                    ))
                                             (posts/reverse-chronological posts)))))))

(define %collections
  `(("seanplynch.com" "index.html" ,posts/reverse-chronological)))

(site #:title "seanplynch.com"
      #:domain "seanplynch.com"
      #:default-metadata '((author . "Sean Lynch")
                           (email . "sean@seanplynch.com"))
      #:build-directory "blog"
      #:readers (list commonmark-reader sxml-reader)
      #:builders (list (blog #:collections %collections
                             #:theme site-theme) 
                       (atom-feed)
                       (static-directory "css")
                       (static-directory "js")
                       )
      )
