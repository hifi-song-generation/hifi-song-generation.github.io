# FunMusic Demo

This repository hosts the public FunMusic demo page:

- Text-to-music generation
- Instrumental music generation
- Cover song generation

The listening interface, player logic, artwork references, lyric timelines, and demo metadata are contained in `index.html`. The technical report is available through `paper.html` and `paper.pdf`.

Audio is served from this repository, with the original FunMusic OSS URLs retained as a runtime fallback. WAV masters are stored as lossless FLAC; existing MP3 sources are preserved without transcoding because converting them to FLAC would not restore lost audio data. Artwork remains on the FunMusic OSS asset host.

GitHub Pages publishes the site from the root of the `main` branch. Run `ruby scripts/localize_audio_data.rb` after editing demo metadata to regenerate the repository-local audio paths and fallback URLs.
