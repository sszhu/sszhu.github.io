# Personal Site Improvement Plan

This phased plan guides structured enhancements to the site source in this repository.

## Phase 0: Baseline & Goals
- Confirm current structure, theme, plugins, bilingual content status.
- Define success metrics: load speed (<1.5s first render), mobile Lighthouse >90, bilingual parity (100% of main pages), simplified deploy workflow.
- Capture initial screenshots + Lighthouse baseline (manual outside repo).

## Phase 1: Content Audit & Foundation (Current Phase)
Focus: Ensure core pages are complete, consistent, and ready for design iteration.
- Audit English pages (`index`, `cv`, `publications`, `projects`, `contact`).
- Audit Chinese counterparts under `zh/`.
- Introduce consistent front matter: `title`, `description`, `lang`, optional `layout`.
- Add new `about.md` (EN) + `zh/about.md` describing profile, mission, interests.
- Standardize project page front matter (`title`, `summary`, `tags`, `link`, `date`).
- Create content checklist for future additions (blog posts, projects, publications).
- Outcome: All core pages have minimal metadata; bilingual parity achieved for existing sections.

## Phase 2: Design & UX Refresh
Focus: Modern visual language, navigation clarity, accessibility.
- Add global navigation component (include partial) with language toggle.
- Improve spacing, typography scale (modular scale). Update color palette (contrast >= 4.5:1 for body text).
- Add favicon + social preview image (Open Graph/Twitter). Include meta tags in layout.
- Introduce basic accessibility audit: headings order, alt text, skip link.
- Optimize responsive layout (mobile nav, readable line lengths).
- Outcome: Consistent, accessible, modern styling; improved nav and language switching experience.

## Phase 3: Technical & Performance & SEO
Focus: Build reliability, speed, discoverability.
- Update `Gemfile` dependencies; pin versions.
- Add SEO front matter defaults (`title`, `description`, `lang`, `canonical`, `image`).
- Inject structured data (JSON-LD) for `Person` and `Article` in layout when context available.
- Image optimization (compress + convert key images to WebP fallback).
- Add lazy-loading to images (`loading="lazy"`).
- Lighthouse review and adjust (e.g., reduce render-blocking CSS, leverage preload for hero image).
- Outcome: Faster loads, better search engine metadata, structured data present.

## Phase 4: Internationalization Enhancements
Focus: Systematic bilingual support & maintainability.
- Add front matter `translation_of` and `translation_status` attributes.
- Introduce language preference persistence (JS storing choice in `localStorage`).
- Evaluate plugin or custom logic for listing available translations of posts.
- Outcome: Stable bilingual workflow with clear translation states.

## Phase 5: Workflow & Automation
Focus: Reliable deployment and quality gates.
- Add GitHub Actions: build + deploy (production), preview (PR/staging), lint (Markdown + HTML), link checker.
- Add CI caching for Bundler to speed builds.
- Document workflows in `README.md`.
- Introduce draft detection (`draft: true` front matter) to exclude from production.
- Outcome: Automated, dependable deployments; quality checks pre-merge.

## Phase 6: Extensibility & Advanced Features
Focus: Future-proofing and optional enhancements.
- Add dark mode (CSS variables + toggle).
- Add RSS feed for posts & publications.
- Integrate analytics (Plausible) conditionally via `_config.yml` flag.
- Optional contact form (Formspree) with honeypot field.
- Modular includes for repeated components (project cards, publication entries).
- Outcome: Enhanced engagement and easier future iteration.

## Phase 7: Polishing & Metrics
Focus: Validation and final refinements.
- Re-run Lighthouse and accessibility tools; address remaining issues.
- Final content proofreading and translation review.
- Tag initial release (e.g., `v1.0-site-refresh`).
- Create short changelog summarizing improvements.
- Outcome: Polished, measured, documented site foundation.

## Cross-Cutting Considerations
- Accessibility: alt text, semantic structure, keyboard navigation.
- Performance: minimize blocking assets, compress images, avoid unnecessary JS.
- Maintainability: consistent front matter, modular includes, documented workflows.
- Security: forms protected against spam; dependencies kept updated.

## Success Criteria Summary
| Area | Metric | Target |
|------|--------|--------|
| Performance | First Contentful Paint | < 1.5s desktop / <2.0s mobile |
| Accessibility | Lighthouse Accessibility | ≥ 95 |
| Bilingual Coverage | Core pages EN/zh parity | 100% |
| Deploy Reliability | CI success rate | ≥ 99% |
| Content Freshness | Blog/projects updated | ≥ Quarterly |

## Implementation Tracking
Progress tracked via TODO list tool in this workspace. Each phase moves tasks from audit → implement → review.

---
Current Active Phase: Phase 1 (Content Audit & Foundation)
Next Step: Audit existing pages and add missing front matter + create about pages.
