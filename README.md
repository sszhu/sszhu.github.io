# Personal Website — Shanshan Zhu

Private source for a bilingual (EN + 中文) personal site built with Jekyll and published via GitHub Pages. The site presents CV, publications, selected projects, and posts with a clean, content‑first structure. This repository is the editable source; the public deployment (e.g. `sszhu.github.io`) may contain only generated static files when using a two‑repo model.

## Features
- Bilingual content (`/` and `/zh/` trees)
- Project collection in `_projects/`
- Markdown-based content, easy diff & versioning
- Jekyll remote theme + plugins (configured in `_config.yml`)
- Optional blog via `_posts/`
- Private source + public generated output workflow (GitHub Actions)

## Tech Stack
- Ruby / Jekyll (GitHub Pages compatible build)
- GitHub Actions for deployment (optional two-repo pattern)
- Markdown for all content; YAML front matter for metadata

## Directory Overview
- `_config.yml` — Site + theme + plugin config
- `_layouts/` — Base HTML templates (e.g. `default.html`)
- `index.md`, `cv.md`, `publications.md`, `projects.md`, `contact.md` — English top-level pages
- `zh/` — Chinese counterparts (`index.md`, `cv.md`, `publications.md`, etc.)
- `_posts/` — Blog posts (`YYYY-MM-DD-title.md`)
- `_projects/` — Individual project pages with front matter
- `assets/img/` — Images
- `Gemfile` — Ruby dependencies

## Prerequisites (Local Development)
Install a recent Ruby (>= 3.1 recommended) and Bundler.
```zsh
gem install bundler
```

## Run Locally
```zsh
bundle install
bundle exec jekyll serve --livereload
```
Visit `http://127.0.0.1:4000` (or `http://localhost:4000`).

## Updating Content
- Add a publication: edit `publications.md` (consider consistent citation style).
- Add a project: create a new markdown file in `_projects/` with front matter (e.g. `title`, `description`, `tags`).
- Add a post: place `YYYY-MM-DD-title.md` in `_posts/` with `layout: post` (if theme supports) and appropriate categories.
- Add Chinese translation: mirror the file under `zh/` maintaining similar front matter keys for future i18n enhancements.
- Images: store under `assets/img/` and reference with relative paths.

## Two-Repo Deployment (Optional)
Keep this repo private while publishing publicly:
1. Private source repo (this one): `personal-site-src`.
2. Public Pages repo: `sszhu/sszhu.github.io` (must stay public for user site).
3. Add workflow `.github/workflows/deploy.yml` that builds and pushes `_site/` contents to the public repo.
4. Create a PAT with suitable write scope; save as secret `PUBLISH_TOKEN`.
5. Push to `main` here → Action builds & force-updates static site in public repo.

### Required Secret
`PUBLISH_TOKEN` — PAT (classic `repo` scope or fine‑grained with write to `sszhu.github.io`).

## Single-Repo Deployment (Simpler Alternative)
If you do NOT need private history, place source directly in a public `<username>.github.io` repository and enable GitHub Pages (Branch: `main`, Folder: `/root`).

## Custom Domain
1. Purchase domain (e.g. `shanshanzhu.com`).
2. Add domain under Settings → Pages.
3. Configure DNS: `CNAME` pointing to `<username>.github.io`. (Optional: add `A` records for apex with GitHub IPs.)

## Internationalization Notes
- Current approach: duplicate page trees (`/` and `/zh/`).
- Future enhancement: central language toggle + shared metadata; can add `lang:` key in front matter.
- For posts: optionally create `zh/_posts/` parallel structure.

## Extending
- Analytics: add Plausible or GA snippet via `_config.yml` includes.
- Contact form: integrate Formspree or similar in `contact.md`.
- Structured data: add JSON-LD blocks in layout for publications/projects.
- SEO: set `title`, `description`, `url`, `lang` in `_config.yml`.

## Maintenance Tips
- Keep Ruby + Bundler updated: `bundle update` periodically.
- Pin theme/plugin versions in `Gemfile` to avoid unexpected build diffs.
- Use feature branches; merge to `main` after local preview.

## Deployment Verification
After a workflow run, confirm:
- Public repo updated (latest commit message matches Action).
- Site loads with expected content and language toggle.
- No missing asset 404s in developer console.

## License
Content © Shanshan Zhu. Site scaffold code may be reused with attribution.

## Attribution
Feel free to adapt this structure; please retain credit where practical.
