title: Understanding the Guile Type Inferencer
date: 2020-04-15 12:00
tags: guile types cps
summary: How does Guile infer types? Let's find out!
---

Lately I've been investigating what it would take to provide some sort of type
analysis to the scheme programming language. In the process I wanted to learn
a bit about how the Guile Scheme type system works. Naturally my first step was
to ask the kind folks over at the #guile irc channel for some pointers. Along
the way someone over there was interested as well, and asked me to write up
what I found. It's been a while since I've blogged, so here we are.

This topic really digs into the internals of Guile's compiler, which is of
course a very large topic. I'll also try my best to explain the bits that a
reader absolutely must know to understand the main points. I'll try to only
assume a reasonably proficient understanding of programming (in any language)
and link to resources that provide more in depth background on the Guile
compiler itself. I don't think a reader *must* know the Scheme programming
language in order to understand what's happening here, but we will be using the
scheme language throughout the post. Here is a quick mental mapping that should
get you through.

```js
// A top level variable
var foo = "foo"
// A top level function definition
function foo(bar, baz) { 
  return bar + baz 
} 
// A function call
foo(1, 2)
```

```scheme
;; A top level variable
(define foo "foo")
;; A top level function (procedure) definition
(define (foo bar baz) 
  (+ bar baz))
;; A function call
(foo 1 2)
```

One last note before we get started. I'm *almost* going to walk through all the
steps that I used to learn this topic. I say *almost* because along the way I
went down many paths that proved to be useless or just plain wrong. Here I only
show the questions that led to useful answers. With that, let's dig in! 

### The Guile Compiler
In order to understand the details here, it is incredibly helpful to understand
the [Guile Compiler Tower](https://www.gnu.org/software/guile/manual/html_node/Compiler-Tower.html).
So best to go read that page and come back (don't worry it's not long). It is
also pretty helpful to read the entire [Compiling to the Virtual Machine](https://www.gnu.org/software/guile/manual/html_node/Compiling-to-the-Virtual-Machine.html)
section. But don't worry if you don't understand everything, or just don't have
the time. We'll cover the important bits here. In particular the Intermediate
Language (IL) that we are interested in here is the
[Continuation Passing Style](https://www.gnu.org/software/guile/manual/html_node/Continuation_002dPassing-Style.html)
IL, as that is the compiler pass that does type analysis.

### Continuation Passing Style (CPS)
Without getting all **Compiler Theory™** on you, for our purposes it will
probably suffice to consider CPS as a big goto table. Yes,
[goto is considered harmful](https://homepages.cwi.nl/~storm/teaching/reader/Dijkstra68.pdf),
but as a tool for a compiler back-end it is actually pretty practical.

#### Compiling to CPS
Guile is great, it exposes the entire compiler to the user, so we can start
exploring right away. For our example let's consider a simple "hello world"
program.

```scheme
(define (main)
  (display "Hello world!\n"))
```

In order to compile this to CPS we can just use the compile procedure in the
Guile repl.

```scheme
scheme@(guile-user)> (define hello-world
                      '(define (main)
                         (display "Hello world!\n")))
scheme@(guile-user)> (compile hello-world #:to 'cps)
$1 = #<intmap 0-18>
```

wtf is that `#<intmap 0-21>` thing? Well, like I said, this is essentially a
big goto lookup table, so Guile has an efficient data structure for that: the
intmap found in the [CPS Soup](https://www.gnu.org/software/guile/docs/docs-2.2/guile-ref/CPS-Soup.html)
section of the manual. Now, let's import the intmap module so that we can
inspect what the compiler just gave us. At the Guile repl again we call the
`use-modules` procedure.

```scheme
scheme@(guile-user)> (use-modules (language cps intmap))
```

Now we can start to poke at our intmap, but it is probably also useful to
assign a sensible name to this intmap, so let's do that now. We'll just use the
identifier that the repl automatically assigned to the result of our
expression (namely `$1`).

```scheme
scheme@(guile-user)> (define hello-world-cps $1)
```

#### Poking at CPS
An intmap is essentially a mapping of small integers to CPS values. Let's see
what the first value (at index `0`) is, for that we'll use `intmap-ref`.
`intmap-ref` is very similar to `list-ref` and `vector-ref`.

```scheme
scheme@(guile-user)> (intmap-ref hello-world-cps 0)
$2 = #<cps (kfun () 0 1 18)>
```

Here we can see that we got some sort of CPS value out. It is a cps record of
type `$kfun`. You can go find *all* the possible CPS record types in the
[CPS in Guile](https://www.gnu.org/software/guile/docs/docs-2.2/guile-ref/CPS-in-Guile.html#CPS-in-Guile)
section of the manual, but (spoiler alert `$kfun` defines a function entry).
Looking at that manual page we see that `$kfun` has five arguments.

1. **src**
   This is the source location of the original scheme expression. First
   of all this property isn't printed. And second of all, we didn't
   compile our program from a file anyway, so this would be pretty
   useless for us. So we'll just ignore it.

2. **meta**
   The `meta` field is some sort of association list describing the
   properties of the procedure (function). We aren't entirely sure
   what this is yet. But none of our functions have arguments, and
   there are no variables, so it should come as no surprise that it is
   empty.

3. **self**
   The documentation for the `self` field says:

   > self is a variable bound to the procedure being called, and which may be
   > used for self-references

   So it should make sense that this value is `0`. Remember we are looking at
   the CPS value at index `0` in our intmap.

4. **tail**
   The documentation for the `tail` field says:

   > tail is the label of the $ktail for this function, corresponding to the
   > function’s tail continuation

   So it seems that this field should be the "goto" label for when we are done
   with this function and are going to return.

5. **clause**
   The documentation for the `clause` field says:

   > clause is the label of the first $kclause for the first case-lambda clause
   > in the function, or otherwise #f

   So this should be the "goto" label for the first expression of the function
   body.



Well, that was fun. If we look back at what the repl printed initially this all
lines up pretty nicely.

1. src: not printed
2. meta: `'()`
3. self: `0`
4. tail: `1`
5. clause: `18`


#### What's in my intmap?
Of course we could do the same for all indices in the intmap from 0-18, but
that sounds annoying. Let's instead write a function to do it for us! First
we'll need another module `(language cps utils)`. This will give us two
very useful functions `intmap-keys` and `intmap-map`, along with a bunch of
other goodies that we won't need today.

```scheme
scheme@(guile-user)> (use-modules (language cps utils))
```

Now let's write our function, doesn't have to be *too* special.

```scheme
scheme@(guile-user)> (define (print-intmap intmap)
                       (intmap-map (lambda entry
                                     (format #t "~a\n" entry))
                                   intmap))
```

And now we're ready to see what our intmap contains!

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
$3 = #<intmap 0-18>
```

Whew! That's a lot of stuff! That's because there is a lot of implicit control
flow in the higher level scheme language compared to the CPS IL that makes all
of that control flow explicit. Let's dissect this.

We've already seen that our compiled CPS starts at index 0 with some function,
and that the first expression in that function is at index 18. Nearly every
expression I've compiled follows this format. The entry to the program is at
index 0, and then there is some boilerplate at the very end of the intmap.
Here we see that from indices 18-17 Guile is setting up the current module
environment.

I'm afraid we can't tell much about the first field of the `$kclause` record at
index 18. Like the `meta` field of the first `kfun` record we encountered, it
is empty, and I suppose we also kind of expect it to be empty. Anyway, here is
what the documentation says:

> **CPS Continuation: $kclause arity cont alternate**
> 
> A clause of a function with a given arity. Applications of a function with
> a compatible set of actual arguments will continue to the continuation
> labelled cont, a $kargs instance representing the clause body. If the
> arguments are incompatible, control proceeds to alternate, which is a
> $kclause for the next clause, or #f if there is no next clause.

At any rate it is a sure bet that after this `$kclause` we jump to index 17
where we encounter a `$kargs` record. Here's what the documentation has to say
about that:

> **CPS Continuation: $kargs names vars term**

> Bind the incoming values to the variables *vars*, with original names
> *names*, and then evaluate *term*.

So this seems like it is pretty much `let`, and that makes sense, even though
ours is empty. The reason for that is that the `current-module` `$primcall`
record takes no arguments. But don't worry, next we jump to index 16 where we
see a `$kargs` record that *does* have a parameter. This one is called `mod`
and it is the result of the `current-module` call we just stepped through.
It's assigned to variable `1`. We aren't quite sure yet *why* this variable is
associated to index 1 though. It could be an arbitrary number, or it could
relate back to our CPS index 1.  So for now just remember that the
current-module is located at variable index 1. From here we continue to index
15 with the constant symbol `'main`. At index 15 we see that we now call the
`define!` primitive with the variable at index 1 (`(current-module)`),
and the variable at index 10 (`(const main)`). As far as we can tell this
places the `main` symbol in our module. For the documentation on these
primitive calls you'll have to jump over to the
[Intrinsic Call Instructions](https://www.gnu.org/software/guile/manual/html_node/Intrinsic-Call-Instructions.html)
section of the manual. Then we jump through indices 14-13 which seems to be
more environment setup, though I can't seem to find the documentation for this.
Finally once we jump through index 12 we reach our main function. He we jump to
index 4 with the value of `(fun 11)`. If we quickly scan up we can see our
function body starting at index 11 and ending with the `$ktail` record at index 5.
Then from indices 4-1 we see the ending boilerplate for the current module. We'll skip
over this part.

#### Where is *my* code?
As we've seen, our function body is located across indices 11-5.
Here we see something slightly different though. The
`meta` field of our `$kfun` at index 11 actually has some values! In our
case it is just the name of the function because it takes no arguments. Then we
see that the `self` field is actually index 5 and the `tail` field is also at
index 5, and the `clause` field is at index 10 as expected. The self and tail
fields being the same seems to indicate that this function cannot recurse,
however that may be a tenuous assumption. At any rate, let's move on to our
function body at index 10.

Again we see a relatively empty `$kclause` that forwards us to
index 9 where see another empty `$kargs` record that continues to index 8
assigning the `display` box that we just evaluated into variable 8, named `box`
and continues to index 7 by unboxing our `display` procedure. At index 7 we see
that we store our unboxed `display` procedure at variable 6 and continue
to index 6 with our `"Hello world!\n"` constant string. At index 6 we see that
our string constant is assigned to variable 7. Then we continue to index 5 with
the result of `(call 6 7)`. Our `display` function is stored in variable 6, and
our constant string is stored in variable 7, so you can think of this as
`(call display "Hello world!\n")`. From there we continue to our procedure's
`$ktail` record which means this is the entire body. And from there we jump
back to index 4 to finish up the program's entry `$kfun`.

After a few shuffling around of arguments we finally arrive at the `$ktail` of
the entire program at index 1. Remember back when we started our journey that
the `tail` field of the entry function was located at index 1? Well we're done
now! Yay!

### Wait Sean, didn't you say something about types?
Whew, yes. Let's figure out what Guile thinks of our types shall we? For this
we will need to deviate from the manual and look at some code 😱. Here we will
want to dig through the Guile code-base for something that looks like it does
some type inference. Lucky for you I did just that and found the module
`(language cps types)`. You can find it in the Guile source tree at the path
`module/language/cps/types.scm`. Yes, it does sound like a pain to go find the
Guile source code and open this file in a text editor. So here is a snippet
from the top of the file that gives a quick overview.

```scheme
;;; Commentary:
;;;
;;; Type analysis computes the possible types and ranges that values may
;;; have at all program positions.  This analysis can help to prove that
;;; a primcall has no side-effects, if its arguments have the
;;; appropriate type and range.  It can also enable constant folding of
;;; type predicates and, in the future, enable the compiler to choose
;;; untagged, unboxed representations for numbers.
;;;
;;; For the purposes of this analysis, a "type" is an aspect of a value
;;; that will not change.  Guile's CPS intermediate language does not
;;; carry manifest type information that asserts properties about given
;;; values; instead, we recover this information via flow analysis,
;;; garnering properties from type predicates, constant literals,
;;; primcall results, and primcalls that assert that their arguments are
;;; of particular types.
;;;
;;; A range denotes a subset of the set of values in a type, bounded by
;;; a minimum and a maximum.  The precise meaning of a range depends on
;;; the type.  For real numbers, the range indicates an inclusive lower
;;; and upper bound on the integer value of a type.  For vectors, the
;;; range indicates the length of the vector.  The range is the union of
;;; the signed and unsigned 64-bit ranges.  Additionally, the minimum
;;; bound of a range may be -inf.0, and the maximum bound may be +inf.0.
;;; For some types, like pairs, the concept of "range" makes no sense.
;;; In these cases we consider the range to be -inf.0 to +inf.0.
;;;
;;; Types are represented as a bitfield.  Fewer bits means a more precise
;;; type.  Although normally only values that have a single type will
;;; have an associated range, this is not enforced.  The range applies
;;; to all types in the bitfield.  When control flow meets, the types and
;;; ranges meet with the union operator.
;;;
;;; It is not practical to precisely compute value ranges in all cases.
;;; For example, in the following case:
;;;
;;;   (let lp ((n 0)) (when (foo) (lp (1+ n))))
;;;
;;; The first time that range analysis visits the program, N is
;;; determined to be the exact integer 0.  The second time, it is an
;;; exact integer in the range [0, 1]; the third, [0, 2]; and so on.
;;; This analysis will terminate, but only after the positive half of
;;; the 64-bit range has been fully explored and we decide that the
;;; range of N is [0, +inf.0].  At the same time, we want to do range
;;; analysis and type analysis at the same time, as there are
;;; interactions between them, notably in the case of `sqrt' which
;;; returns a complex number if its argument cannot be proven to be
;;; non-negative.  So what we do instead is to precisely propagate types
;;; and ranges when propagating forward, but after the first backwards
;;; branch is seen, we cause backward branches that would expand the
;;; range of a value to saturate that range towards positive or negative
;;; infinity (as appropriate).
;;;
;;; A naive approach to type analysis would build up a table that has
;;; entries for all variables at all program points, but this has
;;; N-squared complexity and quickly grows unmanageable.  Instead, we
;;; use _intmaps_ from (language cps intmap) to share state between
;;; connected program points.
;;;

```

This looks like a pretty good description of a Lattice Constraint Propagation
algorithm. The tricky bit might be that it seems like Guile handles dynamic
ranges which I personally haven't found in the literature. Of course, for this
type of type inference (no pun intended, but certainly appreciated), I've actually had a hard time finding
a wealth of information. There is *a lot* of information on Hindley-Milner
style type systems though, and I'm only one man (who wasn't trained in computer
science), so your mileage may vary. Anywho, this sounds like what we're looking
for, so how can I run it in the repl?

Well, in particular there is one procedure that looks interesting called
`infer-types`. Here is an excerpt of the leading comment and doc-string that
I pulled from whatever Guile-3.0 version I currently have checked out.

```scheme
;; For best results, the labels in the function starting should be
;; topologically sorted (renumbered).  Otherwise the backward branch
;; detection mentioned in the module commentary will trigger for
;; ordinary forward branches.
(define (infer-types conts kfun)
  "Compute types for all variables bound in the function labelled
@var{kfun}, from @var{conts}.  Returns an intmap mapping labels to type
entries.

A type entry is a vector that describes the types of the values that
flow into and out of a labelled expression.  The first slot in the type
entry vector corresponds to the types that flow in, and the rest of the
slots correspond to the types that flow out.  Each element of the type
entry vector is an intmap mapping variable name to the variable's
inferred type.  An inferred type is a 3-vector of type, minimum, and
maximum, where type is a bitset as a fixnum."
  ...)

```

It seems like once we have our CPS we should be able to call this procedure
with it (somehow) to get the types out. Through some trial and error I figured
out that the parameters you want to pass are:

1. **conts**
This is your program's CPS representation in intmap form. So in our case
this would be `hello-world-cps`
2. **kfun**
This is an index into your intmap pointing at *any* `$kfun` value.

Let's call this procedure! Index 0 seems like as good a choice as any right?
We'll ignore the whole comment about sorting from the source. I'm sure it is
improtant, but our case is so simple let's hope it doesn't actually cause a
problem. When we call
`compile` on our simple function does it already spit out a sorted intmap?
¯\_(ツ)_/¯. We'll import the types module and then call `infer-types` with
our cps.

```scheme
scheme@(guile-user)> (use-modules (language cps types))
scheme@(guile-user)> (infer-types hello-world-cps 0)
$4 = #<intmap 0-4,12-18>
```

#### But What Does it all **Mean**?
Hey, look at that, we have another intmap. Let's assign it to some meaningful
name and then peek at what's inside.

```scheme
scheme@(guile-user)> (define hello-world-types $4)
scheme@(guile-user)> (print-intmap hello-world-types)
(0 #(#<intmap> #<intmap 0>))
(1 #(#<intmap 0-4,9-10>))
(2 #(#<intmap 0-4,9-10> #<intmap 0-4,9-10>))
(3 #(#<intmap 0-2,4,9-10> #<intmap 0-4,9-10>))
(4 #(#<intmap 0-2,4,9-10> #<intmap 0-2,4,9-10>))
(12 #(#<intmap 0-2,9-10> #<intmap 0-2,4,9-10>))
(13 #(#<intmap 0-2,9-10> #<intmap 0-2,9-10>))
(14 #(#<intmap 0-2,10> #<intmap 0-2,9-10>))
(15 #(#<intmap 0-1,10> #<intmap 0-2,10>))
(16 #(#<intmap 0-1> #<intmap 0-1,10>))
(17 #(#<intmap 0> #<intmap 0-1>))
(18 #(#<intmap 0> #<intmap 0>))
$5 = #<intmap 0-4,12-18>
```

True to the source code's word we have an intmap of vectors that contain
intmaps. There is one particular line in the source that I'd like to call out
(because at first I only skimmed this file, and so it took me *forever* to
realize).

> The first slot in the type entry vector corresponds to the types that flow
> in, and the rest of the slots correspond to the types that flow out.

Just to reiterate, the first item in each vector is the inferred type of the
*inputs* and the remaining are the inferred types of the *outputs*.

As usual, let's just look at the first entry (the program entry) to test our
assumptions (it should be pretty boring). First let's look at the input types
to our program. We'll access the first element of the inner intmap, that is
stored in the first element of the vector that is stored in the first element
of our outter intmap. So we are looking at indices (0, 0, 0).

```scheme
scheme@(guile-user)> (intmap-ref (vector-ref (intmap-ref hello-world-types 
                                                         0) 
                                             0) 
                                 0)
ice-9/boot-9.scm:1669:16: In procedure raise-exception:
not found 0

Entering a new prompt.  Type `,bt' for a backtrace or `,q' to continue.
scheme@(guile-user) [1]> ,q
```

We get an error, though we shouldn't be surprised. The printed representation
of the first intmap in the first vector has no indices, because obviously the
entry point to our program has no inputs!

Let's look at the outputs, to do that we'll just look at index 1 of
the first vector. Looking at the printed representation it should have an entry
at index 0.

```scheme
scheme@(guile-user)> (intmap-ref (vector-ref (intmap-ref hello-world-types 
                                                         0) 
                                             1) 
                                 0)
$6 = #(67108863 -inf.0 +inf.0)
```

Now we got a vector with a weird looking number at the front, and then two
trailing entries for `-inf.0` and `+inf.0`. So at least we immediately see the
variable can range from negative to positive infinity. But what is that first
number? Well let's remember the source comments

> An inferred type is a 3-vector of type, minimum, and maximum, where type is a
> bitset as a fixnum.

We clearly see the minimum and maximum, but what does the type mean. Well we can
find more clues in the exports from `language/cps/types.scm`. In particular the
module exports constants for all types starting on line 99 and ending on line 124.

It's a little hard to tell exactly what they all are from the source alone, but
I bet they are all integer constants. Let's see if I'm right by just
copy/pasting them into the repl

```scheme
scheme@(guile-user)> &fixnum
$7 = 1
scheme@(guile-user)> &bignum
$8 = 2
scheme@(guile-user)> &flonum
$9 = 4
scheme@(guile-user)> &complex
$10 = 8
scheme@(guile-user)> &fraction
$11 = 16
scheme@(guile-user)>
scheme@(guile-user)> &char
$12 = 32
scheme@(guile-user)> &special-immediate
$13 = 64
scheme@(guile-user)> &symbol
$14 = 128
scheme@(guile-user)> &keyword
$15 = 256
scheme@(guile-user)> &procedure
$16 = 512
scheme@(guile-user)> &pointer
$17 = 1024
scheme@(guile-user)> &fluid
$18 = 2048
scheme@(guile-user)> &pair
$19 = 4096
scheme@(guile-user)> &immutable-vector
$20 = 8192
scheme@(guile-user)> &mutable-vector
$21 = 16384
scheme@(guile-user)> &box
$22 = 32768
scheme@(guile-user)> &struct
$23 = 65536
scheme@(guile-user)> &string
$24 = 131072
scheme@(guile-user)> &bytevector
$25 = 262144
scheme@(guile-user)> &bitvector
$26 = 524288
scheme@(guile-user)> &array
$27 = 1048576
scheme@(guile-user)> &syntax
$28 = 2097152
scheme@(guile-user)> &other-heap-object
$29 = 4194304
scheme@(guile-user)>
scheme@(guile-user)> ;; Special immediate values.
scheme@(guile-user)> &null &nil &false &true &unspecified &undefined &eof
$30 = 0
$31 = 1
$32 = 2
$33 = 3
$34 = 4
$35 = 5
$36 = 6
scheme@(guile-user)>
scheme@(guile-user)> ;; Union types.
scheme@(guile-user)> &exact-integer &exact-number &real &number &vector
$37 = 3
$38 = 19
$39 = 23
$40 = 31
$41 = 24576
scheme@(guile-user)>
scheme@(guile-user)> ;; Untagged types.
scheme@(guile-user)> &f64
$42 = 8388608
scheme@(guile-user)> &u64
$43 = 16777216
scheme@(guile-user)> &s64
$44 = 33554432
```

Well it sure seems like they are. It also seems like each one has just a single
bit set. So let's clean this up a bit and print the values with some padding so
we can compare them. First the regular `format` procedure isn't up to the task,
so we'll import the `ice-9` version that has hex/binary format strings. Then we
define a list of all the types. And then we'll loop through each of them
printing the hex, binary, symbol name, and decimal values for each type.

```scheme
scheme@(guile-user)> (use-modules (ice-9 format))
scheme@(guile-user)> (define types 
                       '(&fixnum
                         &bignum
                         &flonum
                         &complex
                         &fraction

                         &char
                         &special-immediate
                         &symbol
                         &keyword
                         &procedure
                         &pointer
                         &fluid
                         &pair
                         &immutable-vector
                         &mutable-vector
                         &box
                         &struct
                         &string
                         &bytevector
                         &bitvector
                         &array
                         &syntax
                         &other-heap-object

                         ;; Special immediate values.
                         &null &nil &false &true &unspecified &undefined &eof

                         ;; Union types.
                         &exact-integer &exact-number &real &number &vector

                         ;; Untagged types.
                         &f64
                         &u64
                         &s64))
scheme@(guile-user)> (for-each (lambda (type-pair) 
                                 (format #t "~8,'0x ~32'0b ~a ~a\n" (car type-pair)
                                                                    (car type-pair) 
                                                                    (cdr type-pair) 
                                                                    (car type-pair)))
                               ;; Here we combine the symbol name with the value of
                               ;; of the symbol. In the end we get something like this
                               ;; '((1 . &fixnum) (2 . &bignum) ...)
                               (map (lambda (type) 
                                      (cons (eval type (current-module)) type))
                                    types))
00000001 00000000000000000000000000000001 &fixnum 1
00000002 00000000000000000000000000000010 &bignum 2
00000004 00000000000000000000000000000100 &flonum 4
00000008 00000000000000000000000000001000 &complex 8
00000010 00000000000000000000000000010000 &fraction 16
00000020 00000000000000000000000000100000 &char 32
00000040 00000000000000000000000001000000 &special-immediate 64
00000080 00000000000000000000000010000000 &symbol 128
00000100 00000000000000000000000100000000 &keyword 256
00000200 00000000000000000000001000000000 &procedure 512
00000400 00000000000000000000010000000000 &pointer 1024
00000800 00000000000000000000100000000000 &fluid 2048
00001000 00000000000000000001000000000000 &pair 4096
00002000 00000000000000000010000000000000 &immutable-vector 8192
00004000 00000000000000000100000000000000 &mutable-vector 16384
00008000 00000000000000001000000000000000 &box 32768
00010000 00000000000000010000000000000000 &struct 65536
00020000 00000000000000100000000000000000 &string 131072
00040000 00000000000001000000000000000000 &bytevector 262144
00080000 00000000000010000000000000000000 &bitvector 524288
00100000 00000000000100000000000000000000 &array 1048576
00200000 00000000001000000000000000000000 &syntax 2097152
00400000 00000000010000000000000000000000 &other-heap-object 4194304
00000000 00000000000000000000000000000000 &null 0
00000001 00000000000000000000000000000001 &nil 1
00000002 00000000000000000000000000000010 &false 2
00000003 00000000000000000000000000000011 &true 3
00000004 00000000000000000000000000000100 &unspecified 4
00000005 00000000000000000000000000000101 &undefined 5
00000006 00000000000000000000000000000110 &eof 6
00000003 00000000000000000000000000000011 &exact-integer 3
00000013 00000000000000000000000000010011 &exact-number 19
00000017 00000000000000000000000000010111 &real 23
0000001f 00000000000000000000000000011111 &number 31
00006000 00000000000000000110000000000000 &vector 24576
00800000 00000000100000000000000000000000 &f64 8388608
01000000 00000001000000000000000000000000 &u64 16777216
02000000 00000010000000000000000000000000 &s64 33554432
```

Well, I think that should satisfy our curiosity. It turns out we were *almost*
right. The "raw" types are indeed components of a bit mask. But thankfully
Guile has also conveniently provided us with some relevant unions. For
example the type code for number is `00000000000000000000000000011111` so that
encompasses all of the appropriate number subtypes. But does it answer our
question of what the number 67108863 means? An easy hypothesis to make is that
it is the union of *all* types. Let's test that theory at the repl!

```scheme
scheme@(guile-user)> (apply logior (map (lambda (type)
                                          (eval type (current-module)))
                                        types))
$45 = 67108863
```

And we get our magic number!. So the return type of the first function is *any*
scheme value! Now we should be able to go hunting in our intmap for a sensible
type, don't we have a constant string somewhere?

#### Type Hunting
If we examine the intmap for our types, we see something troubling. The
procedure body we are interested in seems to be missing. We only have entries
for the `$kfun` representing the entire program. The string we are looking for
only exists in the `main` procedure's body. So we'll want to go analyze that
instead. That's ok though, this should all look pretty familiar.

```scheme
scheme@(guile-user)> (define main-types (infer-types hello-world-cps 11))
```

Now let's crack this intmap open and see what we have. If we look at index 6 of
our CPS intmap we can see that there should be a `&string` type flowing into it
from the constant string at index 7. So we'll want to pull out the CPS value in
the `main-types` intmap for index 6, and then look at the first entry in the
vector that we get back.

```scheme
scheme@(guile-user)> (print-intmap (vector-ref (intmap-ref main-types 6) 0))
(5 #(67108863 -inf.0 +inf.0))
(6 #(67108863 -inf.0 +inf.0))
(7 #(131072 13 13))
(8 #(32768 2 +inf.0))
$46 = #<intmap 5+0-3>
```

This seems to be the set of variables that our `main` procedure can see.

* At index 8 we see `32768` which is `&box` with a range of 2 to +inf.0. This
is our `define` box.
* At variable index 7 we see `131072` which is our `"Hello world!\n"` string
constant. You can see that Guile has even conveniently provided us with
bounds for the string's length! It is 13 characters long.
* At index 6 we see *any* scheme type. Under our current assumptions this
should be our unboxed `display` function, so I would have expected to see
`512` for `&procedure`. But perhaps that is just not something Guile infers
for us, or possibly this is due to not sorting our input intmap? A question
for another day though.
* At index 5 we see another *any* scheme type. This one is a bit more puzzling,
as nowhere in our CPS intmap do we see a `$kargs` that stores a variable to
index 5. We'll also leave this as another question for another day.


It seems that we haven't quite sorted everything out yet, but we certainly have
seen the tools that will help us fill in the gaps. We've also verified enough
of our assumptions that it seems pretty clear we are on the right track.

### Closing Thoughts
There are still some open questions to this analysis.

* Why only one set of input types, but multiple sets of output types? My
initial hypothesis (that I have not yet tested) is that multiple output sets
would be needed when branching (for example with `if`).
* There seems to be some relevance to the integers used to specify variables,
but I don't think I see what that significance is. And if there is
significance; is it intentional or coincidental?
* We also haven't discussed at all the significance of Guile's type inferencer,
nor have we discussed alternatives. What can it do? What *can't* it do?


At any rate, this post is already long enough, and we have covered our
hello-world example to my satisfaction. The rest will have to wait for another
time.

### Appendix A
Yes, I included the repl prompt in all the code snippets that I expected a
reader to copy/paste, which is just annoying. It means you have to copy paste
them all one at a time. So here is a big dump of the entire repl history. Now
you can dump this into your own repl and explore on your own!

Happy Hacking!

```scheme
(define hello-world
  '(define (main)
    (display "Hello world!\n")
    #;"Hello world!\n"))
(compile hello-world #:to 'cps)
(use-modules (language cps intmap))
(define hello-world-cps $1)
(intmap-ref hello-world-cps 0)
(use-modules (language cps utils))
(define (print-intmap intmap)
  (intmap-map (lambda entry
                (format #t "~a\n" entry))
              intmap))
(print-intmap hello-world-cps)
(use-modules (language cps types))
(infer-types hello-world-cps 0)
(define hello-world-types $4)
(print-intmap hello-world-types)
(intmap-ref (vector-ref (intmap-ref hello-world-types 
                                    0)
                        0) 
            0)
,q
(intmap-ref (vector-ref (intmap-ref hello-world-types 
                                    0) 
                        1) 
            0)
&fixnum
&bignum
&flonum
&complex
&fraction

&char
&special-immediate
&symbol
&keyword
&procedure
&pointer
&fluid
&pair
&immutable-vector
&mutable-vector
&box
&struct
&string
&bytevector
&bitvector
&array
&syntax
&other-heap-object

;; Special immediate values.
&null &nil &false &true &unspecified &undefined &eof

;; Union types.
&exact-integer &exact-number &real &number &vector

;; Untagged types.
&f64
&u64
&s64
(define types 
  '(&fixnum
    &bignum
    &flonum
    &complex
    &fraction

    &char
    &special-immediate
    &symbol
    &keyword
    &procedure
    &pointer
    &fluid
    &pair
    &immutable-vector
    &mutable-vector
    &box
    &struct
    &string
    &bytevector
    &bitvector
    &array
    &syntax
    &other-heap-object

    ;; Special immediate values.
    &null &nil &false &true &unspecified &undefined &eof

    ;; Union types.
    &exact-integer &exact-number &real &number &vector

    ;; Untagged types.
    &f64
    &u64
    &s64))
(use-modules (ice-9 format))
(for-each (lambda (type-pair) 
            (format #t "~8,'0x ~32'0b ~a ~a\n" (car type-pair)
                                               (car type-pair) 
                                               (cdr type-pair) 
                                               (car type-pair)))
          ;; Here we combine the symbol name with the value of
          ;; of the symbol. In the end we get something like this
          ;; '((1 . &fixnum) (2 . &bignum) ...)
          (map (lambda (type) 
                 (cons (eval type (current-module)) type))
               types))
(apply logior (map (lambda (type)
                     (eval type (current-module)))
                   types))
(define main-types (infer-types hello-world-cps 11))
(print-intmap (vector-ref (intmap-ref main-types 6) 0))
```

