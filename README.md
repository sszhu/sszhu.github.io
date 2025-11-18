# Personal Website — Shanshan Zhu

This repository hosts a personal website powered by GitHub Pages (Jekyll with a remote theme). It highlights experience, publications, and selected projects.

## Structure
- `_config.yml` — Site configuration (title, theme, plugins, social links).
- `index.md` — Landing page with highlights and navigation.
- `cv.md` — Structured CV.
- `publications.md` — Selected publications.
- `projects.md` — Selected projects.
- `contact.md` — Contact information.
- `_posts/` — Blog posts (optional).
- `assets/` — Images and static assets.

## Quick Start

1. Create a new GitHub repository.
   - For a personal site: name it `<your-username>.github.io`.
   - For a project site: any name (e.g., `ss-image`).

2. Push this folder’s contents to the repository.

3. Enable GitHub Pages.
   - Go to Settings → Pages → Build and deployment.
   - Source: `Deploy from a branch` → Branch: `main` → Folder: `/root`.
   - Save. GitHub will build and publish at `https://<your-username>.github.io/` or `https://<your-username>.github.io/<repo>/`.

4. Optional: Set a custom domain.
   - Buy a domain (e.g., `shanshanzhu.com`).
   - In Settings → Pages, add the domain.
   - Configure DNS (CNAME to `<your-username>.github.io`).

5. Customize.
   - Edit `_config.yml` (title, social links, description).
   - Add your photo to `assets/img/` and link it on `index.md`.
   - Add more posts under `_posts/` following `YYYY-MM-DD-title.md`.

## Two-Repo Deployment Model (Private Source + Public Site)

If you want to keep source code private while publishing a public site:

1. Create a private source repository (e.g. `personal-site-src`).
2. Keep the public repository named `sszhu.github.io` (must remain public for user site).
3. Copy this scaffold into the private source repo and commit changes there.
4. In the private repo, create a Personal Access Token (PAT) with `repo` scope and add it as a secret named `PUBLISH_TOKEN`.
5. Add the workflow file `.github/workflows/deploy.yml` (copy from this repo) to the private source repo.
6. Update the `DEPLOY_REPO` value in the workflow if your public repo differs.
7. On each push to `main` of the private repo, the workflow will:
   - Build the Jekyll site into `_site/`
   - Push the static output directly to `sszhu/sszhu.github.io@main`.

Result: The public repo only contains generated static files; authorship history and drafts stay private.

### Required Secret
`PUBLISH_TOKEN`: Personal Access Token with `repo` scope (classic) or a fine-grained token granting write access to `sszhu.github.io`.

### Local Development (Private Source)
```zsh
bundle install
bundle exec jekyll serve --livereload
```

### Notes
- Do not make `sszhu.github.io` private; GitHub Pages user sites require public visibility for open access.
- For staging, add a `staging` branch and only merge to `main` when ready.
- Bilingual: Chinese pages live under `zh/`.

## Bilingual Content
- English root pages: `/`
- Chinese pages: `/zh/`
- Navigation includes language toggle.
- For translated posts, you can mirror them under `zh/_posts/` (configure if needed).

## Future Enhancements
- Analytics (Plausible / GA) via keys in `_config.yml`.
- Contact form (Formspree) when `features.contact_form` is enabled.
- Structured data extensions per project page.
- Expanded project collection (`_projects/`).

## Local Preview (optional)
If you want to preview locally, install Ruby and Jekyll, then serve. GitHub will build for you even if you don’t.

## License
Content © Shanshan Zhu. Code is provided for site scaffolding; reuse with attribution.
