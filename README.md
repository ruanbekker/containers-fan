# hugo-blog-papermod-example
Hugo Blog Example with Papermod

## Resources

- [Quickstart](https://gohugo.io/getting-started/quick-start/)
- [Theme](https://github.com/adityatelange/hugo-PaperMod/wiki/Installation)

## Setup

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
echo 'theme: "PaperMod"' >> data/blog/config.toml
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
