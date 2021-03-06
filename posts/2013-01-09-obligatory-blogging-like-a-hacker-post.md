title: Obligatory Blogging Like a Hacker Post
date: 2013-01-09 12:00
summary: If you use Jekyll, you must have a post like this right?
---

### The New Site
For quite a while I have wanted to redesign my site. I originally set it up
with [wordpress](http://wordpress.org) as it was easy to get started. I tried
various different themes, and even took a look at some of the code in an
attempt to make my site my own. What I learned is that while very flexible,
wordpress has a lot going on. In the end I found that it was just too
complicated for me to dig into the guts and make the changes that I wanted. I
came across [jekyll](https://github.com/mojombo/jekyll) and the geek in me said

>Yes! Do it now!

I had to exhibit a little self control though as I had a dissertation to write.
Incidentally you'll notice I haven't updated this blog since March, yes it
takes a while to write a dissertation and find a job. Now that I've taken care
of those two small details I have been able to come back to this site and you
can see the end result. Now I know every last little bit of code that goes into
this site, and I feel better about that. You'll notice that typically when
someone switches over to using jekyll they inevitably write a
**Blogging Like a Hacker™** post, so I thought I would too. Since there are
many out there, I'll just post some of my thoughts on the process.

### What's a Jekyll and Why Do I Care?
Jekyll is a static website generator that is "blog aware". It is a bit of ruby
code that parses posts and pages into static HTML/css. This means that you write
your blog posts in [Markdown](http://daringfireball.net/projects/markdown/) and
let Jekyll sort out the details (sort of). There's no database to
protect/crash, just some text files. This website is now sitting inside my
[GitHub repository](https://github.com/seepel/seanplynch.com). Feel free to
glean what you can from it, take anything you want short of plagiarising my
blog posts. Now that I have it setup I simply write my blog posts in a plain
text file (using vi of course), run jekyll and copy the contents over to my web
directory. No fuss no muss. There are some other static site generators out
there, [octopress](http://octopress.org) tends to stand out from the crowd, and
is actually based on jekyll. These other projects often come with theming,
which to a non-css wizard sounds pretty good. When I started to work with them
however, I found myself in the same position again. While it was somewhat toned
down compared to wordpress, I still found myself getting lost as I tried to
tweak here and there. So I decided that I didn't **want** any theming. I wanted
to build it from the ground up. Ironic, since I don't think I ended up with a
particularly unique design. The one thing I can say, is that aside from
[twitter bootstrap](http://twitter.github.com/bootstrap/) lending me a helping
hand, every line is mine. Turns out, that's pretty important to me.
 
### In closing
There were some bumps, blogging like a hacker is not for the faint of heart. It
took some time for me to get [less](http://lesscss.org) working, ended up
stealing a plugin from gist somewhere that I can't remember. I grabbed a
wordpress "more" excerpt style plugin from
[Jacques Fortier](http://www.jacquesf.com/2011/03/creating-excerpts-in-jekyll-with-wordpress-style-more-html-comments/).
There are certainly a lot of things that I don't have running yet, but that is
the beauty I see in switching to Jekyll. I can very easily update my site with
new tricks and fix bugs as I go.
