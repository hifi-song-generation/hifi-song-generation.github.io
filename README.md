# FunMusic Demo

This repository hosts the public FunMusic demo page:

- Text-to-music generation
- Instrumental music generation
- Cover song generation

The listening interface, player logic, artwork references, lyric timelines, and demo metadata are contained in `index.html`. The technical report is available through `paper.html` and `paper.pdf`.

## Audio delivery

The public page remains on GitHub Pages, so it does not require an ICP-filed custom domain. Audio uses a failover layout designed for visitors in mainland China:

- Shanghai OSS is the primary source for all 88 player entries.
- Every primary object is MP3, supports byte-range requests and CORS, and carries a one-year immutable cache policy.
- A repository-local MP3 is the fallback for every entry.
- Playback switches to the fallback if the browser does not confirm playback within six seconds, or immediately after a primary-source error. A stalled fallback stops after a hard 15-second limit instead of buffering forever.
- Audio keeps `preload="none"`; opening the page does not download songs.
- The page never waits for audio before becoming interactive and has no full-page “Still preparing” gate.

The 11 lossless FLAC sources remain recoverable from Git history, while the published tree carries their 320 kbps, 48 kHz, stereo MP3 web copies. Pre-existing MP3 files were not re-encoded. Signed OSS URLs currently expire in July 2036 and must be rotated before then.

Waveforms are fetched only for the selected track from `assets/data/waveforms/v2/`. Web fonts are also external and deferred, keeping the HTML response small and fail-open if an optional asset is slow.

GitHub Pages publishes the site from the root of the `main` branch. After changing player metadata or audio assets, run:

```sh
ruby scripts/verify_audio_delivery.rb
```
