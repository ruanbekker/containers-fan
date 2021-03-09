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

## Run your own Hugo Container

Build:

```
docker build -t hugo .
```

Create a new site:

```
docker run -it -v $PWD/data:/hugo hugo new site blog
```

Get a new theme:

```
git clone https://github.com/adityatelange/hugo-PaperMod data/blog/themes/PaperMod --depth=1
echo 'theme = "PaperMod"' >> data/blog/config.toml
```

Create a new post:

```
docker run -it -v $PWD/data/blog:/hugo hugo new posts/my-first-post.md
```

Run:

```
$ docker run -it \
  -v $PWD/data/blog:/hugo \
  -p 1313:1313 \
  hugo serve --bind "0.0.0.0"
```
