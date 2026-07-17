# DS lore

The blog is built with [Hugo](https://gohugo.io/) and deployed to GitHub Pages by GitHub Actions.

## Preview locally

Install Hugo, then run:

```sh
./preview
```

Open <http://localhost:1313>. The browser reloads when a post or template changes.

## Write a post

Create `content/posts/YYYY-MM-DD-your-post-title.md`:

```yaml
---
title: "Your post title"
date: 2026-07-17T12:00:00+01:00
categories: [example]
draft: true
---

Write Markdown here.
```

Preview with `./preview`. Remove `draft: true`, commit, and push to publish.

The `master` branch currently contains the published HTML. Merge this migration branch only after inspecting the local preview, then select **GitHub Actions** under repository **Settings → Pages**.
