# Grav 2.2.32 — tester-env deployment

Baseline: `getgrav/grav` tag `2.2.32` = `fff1198f33c84acecdcd6f52dad32eaa96fce60c`
(latest stable GitHub Release, published 2026-11-20). The Grav 2.x admin panel is
not in the core repo; the pinned plugin chain below is checked out into
`user/plugins` and `user/themes` of the build context.

## Quick start

```bash
./tester-env deploy   # build image, start container, prove the baked super-admin login
./tester-env seed     # install the deterministic site, account and config fixtures
./tester-env verify   # SPA, front-end routes, page states, journal data, accounts
./tester-env reset    # stop + remove the container (image kept)
./tester-env stop     # stop, state preserved ('down' is an alias)
./tester-env status
./tester-env logs [--follow]
```

Ports: host `53821` -> container `80` (`--port` / `PORT`). URL:
`http://localhost:53821/admin` (admin2 SPA) and `http://localhost:53821/` (quark2
site). Credentials: `admin` / `GravAdmin2026` (super admin) and
`june.park` / `JunePark2026` (seeded content editor: pages and media only).

## Source build

- `Dockerfile` (php:8.3-apache): apt `git unzip libzip-dev libpng-dev
  libjpeg62-turbo-dev libfreetype6-dev libonig-dev libsqlite3-dev`, then
  `docker-php-ext-install gd zip mbstring pdo_sqlite opcache`; `a2enmod rewrite
  headers`; `AllowOverride All` in apache2.conf for Grav's shipped root
  `.htaccess`; composer binary from `composer:2`.
- Vendor tree comes from the committed `composer.lock` in its own layer with a
  BuildKit composer cache mount and `--no-autoloader`, then `composer
  dump-autoload -o` runs after the source `COPY`. `vendor/` is never committed.
- Pinned plugins/themes (all checked out at tag and then committed in the fork):

  | plugin/theme | tag | commit |
  | --- | --- | --- |
  | admin2 | 2.2.16 | e056e3d651adf2402472693a9146d8224c581855 |
  | api | 1.1.23 | 66f17671b49b8c284dc59851d96f5430cf733e94 |
  | login | 3.13.5 | 09f6f28beca68a5dc60bbd08acfb344dd05e8f30 |
  | form | 9.2.2 | 2530369139a5116e35f2a7c5c4abb5bd62834d9b |
  | email | 5.3.5 | 8a529a3ada3201708b1e236203d6bd65e117a1b4 |
  | shortcode-core | 6.2.9 | 818bc7a56757246b3095d94603ea8145550376c8 |
  | flex-objects (trilbymedia) | 1.4.18 | 9bf8ca4c605cfd812fe6024967cb70d056e1e58e |
  | error | 2.0.5 | e676ac6d7dd7c32074f67d1548c1309762b76d63 |
  | problems | 3.0.2 | 81c08171cb851deb125b8c6eb655250b9916621d |
  | quark2 (theme) | 1.1.25 | e32d23e0cb35ee7c8258589ca67e05cc0d0894d2 |

- admin2 ships its compiled SvelteKit bundle under `app/_app`, so there is no
  npm build step for the baseline.
- Measured: cold build 96 s (apt + PHP extensions + composer install); a
  source-only mutation rebuild is 18 s (COPY + `composer dump-autoload` +
  chown); fully cached rebuild is ~5 s.

## Fork baseline

Canonical fork: <https://github.com/sma-rl-dev/grav>, branch
`tester-env-baseline`. It is upstream `getgrav/grav` tag `2.2.32`
(`fff1198f33c84acecdcd6f52dad32eaa96fce60c`) plus one tooling commit that adds
`tester-env`, `tester-env-content/`, `tester-env-seed.json`, `Dockerfile`,
`.dockerignore` and this file.

The upstream `.gitignore` ignores `user/plugins/*`, `user/themes/*`,
`user/accounts/*`, `vendor/*` and the cache dirs, so the ten pinned plugin/theme
trees and `user/accounts/admin.yaml` are **force-added** (`git add -f`) in that
commit; without them the image builds without the admin panel. Their nested
`.git` directories were stripped before the commit, so the pinned SHAs in the
table above are the provenance record (they match the upstream tags). `vendor/`
stays uncommitted: the Dockerfile installs it from the committed
`composer.lock`.

## State, reset, determinism

- No database and no volumes. Content is flat Markdown/YAML under `user/`;
  `cache/`, `tmp/`, `images/`, `assets/`, `logs/`, `backup/` are regenerable.
  The container's writable layer is the whole state, so `reset` removes the
  container and `deploy` recreates the pristine image state.
- No first-run wizard: `user/accounts/admin.yaml` is baked into the image with a
  fixed bcrypt hash (`$2y$10$zcbR91FHBR71KeXfBwT2zujx/HLdTto9a//NhOQ1vTgcVLI4dXgje`)
  and `access: {site: {login: true}, api: {super: true}}`, matching what the
  admin2 setup controller writes. `GET /api/v1/auth/setup` reports
  `setup_required: false`.
- Password policy: the seeded password satisfies the default
  `system.pwd_regex` (`(?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,}`).
- `seed` replaces `user/pages/` with `tester-env-content/pages/` (it wipes the
  directory first, so the image's demo pages and any earlier fixture cannot
  survive), copies `tester-env-content/accounts/` into `user/accounts/` and
  `tester-env-content/config/` into `user/config/`, chowns both to www-data and
  clears the cache with `php bin/grav cache -n`. It is idempotent.
- Seeded product state: the Hawthorn Works garden-furniture site, 15 pages in a
  two-level tree with numeric ordering (`/home`, `/studio` + about/team/careers,
  `/services` + benches/tables/restoration/commissions, `/journal` + 3 dated
  posts, `/contact`). Thirteen pages are published; `/studio/careers` and
  `/services/commissions` are drafts (front-end 404); `/services/restoration` is
  published but `visible: false` (routable, absent from navigation). The journal
  lists its posts newest first with fixed dates 2026-06-05, 2026-08-14 and
  2026-10-02, tags (Workshop/Events, Benches/Materials, Joinery/Materials) and
  one 800x420 JPEG page media (`bench-in-oak.jpg` + `.meta.yaml`). Site title
  and description come from the seeded `user/config/site.yaml`.
- Seeded accounts: the baked `admin` super admin plus `june.park` /
  `JunePark2026` (fixed bcrypt hash), a content editor holding only
  `api.access`, `api.pages.read|write` and `api.media.read|write`; the panel
  shows Pages and Media for it, and `/api/v1/users` returns only its own row
  while `/api/v1/config` returns 403.
- Static seed manifest: `tester-env-seed.json` at this checkout root (it is
  `apps/grav/tester-env-seed.json` inside the corpus submodule).
- Network isolation: the container starts with `--add-host
  getgrav.org:127.0.0.1 --add-host grav.org:127.0.0.1 --add-host
  getgrav.com:127.0.0.1`, so GPM update checks, the notification feed and the
  news feed fail fast locally instead of reaching getgrav.org.

## Browser origin

Grav builds absolute links from the request host (`site.host` is empty), so no
base-URL variable is needed; the panel answers on
`http://172.16.0.1:53821/` from the Docker bridge (verified with a throwaway
`curlimages/curl` container on the default bridge).

## Verified evidence

- Source build, browser smoke, deterministic reset and seed verification were
  performed on 2026-11-22 by the deployment and browser-checker agents against
  this same tree (before the fork existed). The browser evidence below was
  relayed to the fork integrator, which ran no browser itself.
- Browser-visible seeded state in the admin2 panel and the quark2 site: the
  Page tree holds 15 pages (13 published; drafts Studio > Careers and
  Services > Commissions; the published-but-hidden Services > Restoration is
  absent from the site navigation), the Journal listing shows newest first with
  dates 2026-10-02 / 2026-08-14 / 2026-06-05 and tags
  Joinery/Materials/Benches/Workshop/Events, the Bench post renders
  `bench-in-oak.jpg`, the site title is Hawthorn Works, and
  `june.park`/`JunePark2026` sees Pages and Media but not Users or
  Configuration.

## Mutation surface notes

Cheap: PHP under `system/` and `user/plugins/api/classes/Api/Controllers/*`
(pages, media, users, groups, config, audit, reports, GPM) — the server side of
the SPA, visible in the admin UI without a JS build. The `api` plugin
`PagesController`/`UsersController` are the primary target; `admin2.php` is
route/shell glue only. Mutating the SPA itself needs the separate
`getgrav/grav-admin-next` SvelteKit repo and an npm build — avoid for the first
scenarios.

## Safety

`reset`/`stop` only touch `tester-env-grav[<run-id>]`. No image removal, no
prune, no volumes. Never touch `alevern/chromium-browser` or `chromium-ls*`
containers.

## Known nondeterminism

- Each admin/API login from a new client host queues a `login-untrusted-host`
  dashboard notification (the login plugin's untrusted-host check, because
  `plugins.login.site_host` is empty so localhost and the bridge gateway both
  count as untrusted). Scenarios should not assert on the notifications feed.
- `/api/v1/dashboard/stats` reports live counts (seeded baseline: 15 pages, 13
  published, 2 drafts, 2 users), and page dates come from the file copy time
  unless the page has an explicit frontmatter date, so assert content, publish
  state and the journal post dates rather than other dates.
- The admin2 SPA is prebuilt; JS-level mutants need the separate
  `getgrav/grav-admin-next` repo and an npm build. PHP-side mutants under
  `system/` and `user/plugins/api/classes/Api/Controllers/*` need only this
  Dockerfile's source COPY.
