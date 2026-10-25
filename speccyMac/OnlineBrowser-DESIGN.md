# Online Game Browser — Design Notes (future work)

Status: **researched, not started.** Captured so the investigation isn't lost.

## Goal

Let the user browse/search the ZX Spectrum archive from inside the app and
load a chosen game directly — ideally recreating the World of Spectrum
"drill down" feel (category → letter → title list → detail) rather than just a
search box. A selected game is downloaded and handed to the existing
`Spectrum.loadGame(_:)`, which already handles `.sna/.z80/.tap/.tzx` and `.zip`.

## Why not a WebView onto World of Spectrum

A `WKWebView` + `WKDownload` interception → `loadGame` would work mechanically,
but research showed the current site (`worldofspectrum.net`) is a catalogue
that is self-described as out of date with broken links, with downloads
resolving to the older `worldofspectrum.org/pub/...` tree. Scraping a
third-party site's evolving HTML is the least robust option. Rejected.

## Chosen direction: ZXDB / ZXInfo

**ZXDB** (https://github.com/zxdb/ZXDB) is the canonical open database of
Spectrum software (titles, authors, genres, machine type, releases, scores,
screenshots, and — crucially — per-title distribution permissions). It feeds
most Spectrum sites and an open REST API.

Two ways to consume it:

1. **ZXInfo API** (`api.zxinfo.dk`) — **the preferred route.** A genuine hosted
   REST/JSON API on top of ZXDB: query search/browse endpoints live over HTTP
   and get JSON back — no database to bundle or refresh (lightweight, which is
   the whole point). Used by the official Zx App and the open-source
   `zxinfo-vue` web frontend, so it's a real, proven query API. Download links
   resolve to archive.org mirrors and `spectrumcomputing.co.uk/zxdb/`.
2. **Self-hosted SQLite** — *fallback only.* Convert the ZXDB MySQL dump with
   the project's `ZXDB_to_SQLite.py` and bundle it. This is the heavy
   static-dump approach; its only advantage is removing any dependency on a
   third party's server. Prefer the API unless its terms rule it out.

## Licensing / permissions (important)

Three separate layers, each with its own status:

- **ZXDB data** — Open Database License (ODbL 1.0): free to use **with
  attribution** ("mention somewhere if you used it"). We would add a ZXDB
  credit in-app and in the README. ✅ Clear.
- **ZXInfo API service** — the *data* being open doesn't automatically cover
  someone else's hosted server. For personal use likely fine; be a polite
  client (cache, don't poll). Self-hosting the SQLite dump avoids this
  question entirely. ⚠️ Confirm the API's own terms, or self-host.
- **The game files themselves** — ZXDB stores metadata only and is explicit
  that downloading/redistributing copyrighted games is the user's
  responsibility. ZXDB tracks per-title permission (`permissions` /
  `permissiontypes`: Allowed / Denied / Partial). **Design rule: only offer
  downloads for titles marked distribution-allowed**, matching the standard
  the bundled games already follow. ⚠️ Must respect per title.

## Proposed UI (native SwiftUI, no WebView)

- Browse hierarchy mirroring WoS: Category → Letter (A–Z, using ZXDB
  `prefixes` for correct ordering of "The"/"An") → title list → detail.
- Search field for direct lookup.
- Detail view: title, year, publisher, machine type, screenshot, Play button.
- Play → download the (permission-allowed) file → `loadGame` (reuses zip/tape
  pipeline, including the loading screech and fast load).

## Open items before implementation

1. Capture a **real** `api.zxinfo.dk` response to model the JSON against
   (earlier guessed endpoints 404'd — do not design against guesses), **or**
   decide to self-host the SQLite conversion.
2. Confirm the API service's acceptable-use/terms (if using the hosted API).
3. Decide attribution placement (About box / README).
4. Note: if the app is ever sandboxed, outbound networking needs the
   `com.apple.security.network.client` entitlement.

## Scope

This is a multi-session feature (networked API client + JSON models +
multi-screen browse/search/detail UI + async image loading + download &
error/offline handling). Belongs on its own branch. The download→play
hand-off itself is trivial — it reuses `loadGame`.
