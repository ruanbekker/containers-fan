# hugo-blog-papermod-example
Hugo Blog Example with Papermod

## Resources

- [Quickstart](https://gohugo.io/getting-started/quick-start/)
- [Theme](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation)
- [Wiki](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation)
- [Example Site](https://github.com/adityatelange/hugo-PaperMod/tree/exampleSite)

## Quickstart

Clone:

```
$ git clone https://github.com/ruanbekker/hugo-blog-papermod-example
$ cd hugo-blog-papermod-example
```

Build:

```
$ docker run --rm -it -v $(pwd):/src -p 1313:1313 klakegg/hugo:0.81.0
```

Run:

```
$ docker run --rm -it -v $(pwd):/src -p 1313:1313 klakegg/hugo:0.81.0 server
```

## Create a Post

Create a post:

```
$ docker run --rm -it -v $(pwd):/src klakegg/hugo:0.81.0 new posts/hello-world.md
```

You can view the [examplesite content](https://github.com/adityatelange/hugo-PaperMod/tree/exampleSite/content/posts) for more examples, but a basic example would be:

```
$ cat content/posts/hello-world.md
---
author: "Hugo Author"
title: "Hello World"
date: "2021-03-09"
description: "Hello World Page."
tags: ["markdown", "hugo"]
categories: ["hugo-starter"]
aliases: ["hello-world-this-will-redirect"]
---

Hello World
```

## Sub Pages

We can have sub pages like: `/posts/docker/docker-faq` and when we access `/posts/docker` we will have all posts for that folder nested under that path.

To do that:

```
$ mkdir content/posts/docker 
$ cat content/posts/docker/_index.md
---
title: Docker
summary: Contains posts related to Docker
description: Contains posts related to Docker
---
```

Now that we have that we can create a post like:

```
$ docker run --rm -it -v $(pwd):/src klakegg/hugo:0.81.0 new posts/docker/docker-faq.md
```

## Templates

You can follow the instructions [here](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation#sample-pagemd) to create a template, but in short:

Create the `archetypes` folder in the root directory:

```
$ mkdir archetypes
```

Then create the name file, in this case for `post.md`:

```
$ cat archetypes/post.md
---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: false
description: "."
tags: ["."]
categories: ["."]
--- 
```

Now when we create a post and specify `--kind post` the above section will be placed in our post file:

```
$ docker run --rm -it -v $(pwd):/src klakegg/hugo:0.81.0 new --kind post posts/hello-again.md
```

Then we will see our post will have the defaults, and we can just replace and add what we want:

```
$ cat content/posts/hello-agains.md
---
title: "Hello World"
date: 2021-03-09T08:36:35Z
draft: false
description: "."
tags: ["."]
categories: ["."]
---
```


