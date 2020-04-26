title: Understanding the Guile CPS Variable Indices Moor Better
date: 2020-04-23 12:00
tags: guile cps
summary: What did those variable indices mean anyway?
---

In my [last post](/blog/understanding-the-guile-type-inferencer.html) we left
off with a few open questions. In particular I was a bit confused about what
the various variable indices meant. I think if we dig around a bit, we can sort
it out now, so let's get our repl ready to go.

We'll start out by importing the modules we used last time to work with CPS.
Then, we'll redefine our `print-intmap` helper function from last time, and 
finally setup our hello-world program, by storing it to a variable and then
compiling it to CPS.

```scheme
scheme@(guile-user)> (use-modules (language cps)
                                  (language cps intmap)
                                  (language cps utils))
scheme@(guile-user)> (define (print-intmap intmap)
                       (intmap-map (lambda entry
                                     (format #t "~a\n" entry))
                                   intmap))
scheme@(guile-user)> (define hello-world
                       '(define (main)
                         (display "Hello world!\n")))
scheme@(guile-user)> (define hello-world-cps (compile hello-world #:to 'cps))
```

### Renumbering

Now that we have everything setup, let's investigate a little more code. In
the last post I called out a particular line from the documentation in the
`(language cps types)` module:

```scheme
;; For best results, the labels in the function starting should be
;; topologically sorted (renumbered).  Otherwise the backward branch
;; detection mentioned in the module commentary will trigger for
;; ordinary forward branches.
```

I went exploring in the Guile codebase to see if I couldn't figure out what
that meant. I found an answer in the `(language cps compile-bytecode)` 
module, unsurprisingly found in the file
`modules/language/cps/compile-bytecode.scm`. Towards the bottom of the file
there is a procedure called `lower-cps`, in my checkout it is on line 692. 

```scheme
(define (lower-cps exp opts)
  ;; FIXME: For now the closure conversion pass relies on $rec instances
  ;; being separated into SCCs.  We should fix this to not be the case,
  ;; and instead move the split-rec pass back to
  ;; optimize-higher-order-cps.
  (set! exp (split-rec exp))
  (set! exp (optimize-higher-order-cps exp opts))
  (set! exp (convert-closures exp))
  (set! exp (optimize-first-order-cps exp opts))
  (set! exp (reify-primitives exp))
  (set! exp (add-loop-instrumentation exp))
  (renumber exp))
```

Here we see the Guile compiler performing a number of optimization passes, and
the last one is a procedure called `renumber` from `(language cps renumber)`.
This certainly seems to be what we're looking for. Let's go ahead and just use
that module as well.

```scheme
scheme@(guile-user)> (use-modules (language cps renumber))
```

Let's now go ahead and try out the `renumber` procedure. First we'll print the
intmap for our un-optimized CPS, and then we'll print the intmap for a
renumbered cps.

```scheme
scheme@(guile-user)> (print-intmap hello-world-cps)
(0 #<cps (kfun () 0 1 18)>)
(1 #<cps (ktail)>)
(2 #<cps (kargs (val) (3) (continue 1 (values 3)))>)
(3 #<cps (kargs () () (continue 2 (unspecified)))>)
(4 #<cps (kargs (arg) (4) (continue 3 (primcall scm-set!/immediate (box . 1) 2 4)))>)
(5 #<cps (ktail)>)
(6 #<cps (kargs (arg) (7) (continue 5 (call 6 7)))>)
(7 #<cps (kargs (arg) (6) (continue 6 (const "Hello world!\n")))>)
(8 #<cps (kargs (box) (8) (continue 7 (primcall scm-ref/immediate (box . 1) 8)))>)
(9 #<cps (kargs () () (continue 8 (primcall cached-toplevel-box (0 display #t))))>)
(10 #<cps (kclause (() () #f () #f) 9)>)
(11 #<cps (kfun ((name . main)) 5 5 10)>)
(12 #<cps (kargs () () (continue 4 (fun 11)))>)
(13 #<cps (kargs (module) (9) (continue 12 (primcall cache-current-module! (0) 9)))>)
(14 #<cps (kargs (main) (2) (continue 13 (primcall current-module #f)))>)
(15 #<cps (kargs (arg) (10) (continue 14 (primcall define! #f 1 10)))>)
(16 #<cps (kargs (mod) (1) (continue 15 (const main)))>)
(17 #<cps (kargs () () (continue 16 (primcall current-module #f)))>)
(18 #<cps (kclause (() () #f () #f) 17)>)
$1 = #<intmap 0-18>
scheme@(guile-user)> (print-intmap (renumber hello-world-cps))
(0 #<cps (kfun () 0 11 1)>)
(1 #<cps (kclause (() () #f () #f) 2)>)
(2 #<cps (kargs () () (continue 3 (primcall current-module #f)))>)
(3 #<cps (kargs (mod) (1) (continue 4 (const main)))>)
(4 #<cps (kargs (arg) (2) (continue 5 (primcall define! #f 1 2)))>)
(5 #<cps (kargs (main) (3) (continue 6 (primcall current-module #f)))>)
(6 #<cps (kargs (module) (4) (continue 7 (primcall cache-current-module! (0) 4)))>)
(7 #<cps (kargs () () (continue 8 (fun 12)))>)
(8 #<cps (kargs (arg) (5) (continue 9 (primcall scm-set!/immediate (box . 1) 3 5)))>)
(9 #<cps (kargs () () (continue 10 (unspecified)))>)
(10 #<cps (kargs (val) (6) (continue 11 (values 6)))>)
(11 #<cps (ktail)>)
(12 #<cps (kfun ((name . main)) 7 18 13)>)
(13 #<cps (kclause (() () #f () #f) 14)>)
(14 #<cps (kargs () () (continue 15 (primcall cached-toplevel-box (0 display #t))))>)
(15 #<cps (kargs (box) (8) (continue 16 (primcall scm-ref/immediate (box . 1) 8)))>)
(16 #<cps (kargs (arg) (9) (continue 17 (const "Hello world!\n")))>)
(17 #<cps (kargs (arg) (10) (continue 18 (call 9 10)))>)
(18 #<cps (ktail)>)
$2 = #<intmap 0-18>
```

Let's look at the entry function at index 0. Remember, the fields of the
`$kfun` record are `meta`, `self`, `tail`, and `clause`. Let's consider the
`tail` field first. It is the index of the last expression in the function. In
our unordered CPS the last expression of the program is at index 1, and in the
ordered CPS it is at index 11. Now the `clause` field contains information
about the function's arguments (probably a topic for another blog post, lest
this one get too long), but for our purposes it will serve as the beginning of
our function since that is where execution will begin when the function is
called.  In our unordered CPS the clause is at index 18, and in the ordered CPS
it is at index 1. In between we can see that renumbering our CPS has made our
entry function expressions contiguous at the beginning of our program. This
certainly makes it easier to understand a few things that were confusing last
time around, but let's talk about those variable indices.

### Variables
Now that we've renumbered we can pretty much just read off what these numbers
mean. However, we'll first need to make sure we remember of a few details about
the CPS representation.

We'll first remind ourselves of the `$kfun` record 
`($kfun meta self tail clause)`. The `self` field provides a variable index that allows the function to recurse. So the `self`
field is essentially a variable for the function itself. 

Next is the `$kargs` record `($kargs names vars ($continue cont expression)`.
The `vars` field of the `$kargs` record is a list of variables to bind to
incoming values from the previous continuation, before calling `cont` with the
result values of evaluating `expression`. This is all just a fancy way of
saying that the previous expressions result will be stored in the `vars`
variable indices. 

Now we we're ready to read off what each variable index points to. 
Variable 0 is the `self` field of the entry function:
```scheme
(0 #<cps (kfun () 0 1 18)>)
```

Variable 1 is the `current-module` bound at CPS index 3:
```scheme
(2 #<cps (kargs () () (continue 3 (primcall current-module #f)))>)
(3 #<cps (kargs (mod) (1) (continue 4 (const main)))>)
```

Variable 2 is the constant symbol `main` bound at CPS index 4:
```scheme
(3 #<cps (kargs (mod) (1) (continue 4 (const main)))>)
(4 #<cps (kargs (arg) (2) (continue 5 (primcall define! #f 1 2)))>)
```

Variable 3 is the result of calling `define!` adding `'main` to
`current-module`. It is bound at CPS index 5:
```scheme
(4 #<cps (kargs (arg) (2) (continue 5 (primcall define! #f 1 2)))>)
(5 #<cps (kargs (main) (3) (continue 6 (primcall current-module #f)))>)
```

Variable 4 is again the `current-module`, and is bound at CPS index 6:
```scheme
(5 #<cps (kargs (main) (3) (continue 6 (primcall current-module #f)))>)
(6 #<cps (kargs (module) (4) (continue 7 (primcall cache-current-module! (0) 4)))>)
```

Variable 5 is our `main` function itself bound at CPS index 8:
```scheme
(7 #<cps (kargs () () (continue 8 (fun 12)))>)
(8 #<cps (kargs (arg) (5) (continue 9 (primcall scm-set!/immediate (box . 1) 3 5)))>)`
```

Variable 6 is the `*unspecified*` value. Typically when a function's return
value is unspecified Guile will return a special `*unspecified*` singleton:
```scheme
(9 #<cps (kargs () () (continue 10 (unspecified)))>)
(10 #<cps (kargs (val) (6) (continue 11 (values 6)))>)
```

Variable 7 is the `self` field of our `main` function:
```scheme
(12 #<cps (kfun ((name . main)) 7 18 13)>)`
```

Variable 8 is the `box` that the symbol `'display` points to bound at CPS index 15:
```scheme
(14 #<cps (kargs () () (continue 15 (primcall cached-toplevel-box (0 display #t))))>)
(15 #<cps (kargs (box) (8) (continue 16 (primcall scm-ref/immediate (box . 1) 8)))>)`
```

Variable 9 is the contents of the `display` box from variable 8, bound at CPS index 16: 
```scheme
(15 #<cps (kargs (box) (8) (continue 16 (primcall scm-ref/immediate (box . 1) 8)))>)
(16 #<cps (kargs (arg) (9) (continue 17 (const "Hello world!\n")))>)
```

Variable 10 is our constant string `"Hello world!\n"` bound at CPS index 17: 
```scheme
(16 #<cps (kargs (arg) (9) (continue 17 (const "Hello world!\n")))>)
(17 #<cps (kargs (arg) (10) (continue 18 (call 9 10)))>)
```

That is probably enough for today. I think what we've learned is that there is
no particular significance to the variable indices we saw last time. We also
figured out what the comments in the source code meant about renumbering, 
though we did not really figure out in which cases unordered CPS would break 
the type inferencer.

In the future it would be fun to explore the other optimizations, and perhaps we will!

### Appendix A - The Repl

```scheme
(use-modules (language cps)
             (language cps intmap)
             (language cps utils))
(define (print-intmap intmap)
  (intmap-map (lambda entry
                (format #t "~a\n" entry))
              intmap))
(define hello-world
  '(define (main)
    (display "Hello world!\n")))
(define hello-world-cps (compile hello-world #:to 'cps))
(use-modules (language cps renumber))
(print-intmap hello-world-cps)
(print-intmap (renumber hello-world-cps))
```


