#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "uri"

ROOT = File.expand_path("..", __dir__)
INDEX_PATH = File.join(ROOT, "index.html")
OSS_HOST = "fun-resource-shanghai.oss-cn-shanghai.aliyuncs.com"
WAVEFORM_ROOT = File.join(ROOT, "assets/data/waveforms/v2")

def extract_json(html, id)
  opening = %(<script type="application/json" id="#{id}">)
  start = html.index(opening)
  abort("Missing JSON payload: #{id}") unless start

  start += opening.bytesize
  finish = html.index("</script>", start)
  abort("Unclosed JSON payload: #{id}") unless finish

  JSON.parse(html.byteslice(start, finish - start))
rescue JSON::ParserError => error
  abort("Invalid JSON payload #{id}: #{error.message}")
end

def assert(condition, message)
  abort(message) unless condition
end

html = File.binread(INDEX_PATH)
track_data = extract_json(html, "track-data")
wave_data = extract_json(html, "waveform-data")
extract_json(html, "lyrics-timeline-data")
cover_data = extract_json(html, "cover-pair-data")
extract_json(html, "cover-lyrics-timeline-data")

items = track_data.fetch("tracks").map { |track| ["track #{track.fetch("track_id")}", track] }
cover_data.fetch("pairs").each do |pair|
  %w[original cover].each do |role|
    items << ["cover pair #{pair.fetch("pair_id")} #{role}", pair.fetch(role)]
  end
end

assert(items.length == 88, "Expected 88 audio entries, found #{items.length}")
assert(Dir.glob(File.join(ROOT, "assets/audio/**/*.flac")).empty?, "FLAC files must not ship in the published tree")

fallback_bytes = 0
items.each do |label, item|
  primary = URI(item.fetch("audio_url"))
  assert(primary.scheme == "https", "#{label}: primary audio is not HTTPS")
  assert(primary.host == OSS_HOST, "#{label}: primary audio is not on Shanghai OSS")
  assert(primary.path.end_with?(".mp3"), "#{label}: primary audio is not MP3")

  query = URI.decode_www_form(primary.query.to_s).to_h
  %w[Expires OSSAccessKeyId Signature].each do |key|
    assert(!query.fetch(key, "").empty?, "#{label}: signed OSS URL is missing #{key}")
  end
  assert(query.fetch("Expires").to_i > Time.now.to_i, "#{label}: signed OSS URL has expired")

  fallback = item.fetch("audio_fallback_url")
  assert(fallback.start_with?("assets/audio/"), "#{label}: fallback is outside assets/audio")
  assert(fallback.end_with?(".mp3"), "#{label}: fallback is not MP3")
  fallback_path = File.join(ROOT, fallback)
  assert(File.file?(fallback_path) && File.size?(fallback_path), "#{label}: fallback file is missing")
  fallback_bytes += File.size(fallback_path)
end

assert(wave_data.fetch("tracks").empty?, "Waveforms must not remain inline")
track_data.fetch("tracks").each do |track|
  track_id = track.fetch("track_id")
  path = File.join(WAVEFORM_ROOT, "#{track_id}.json")
  assert(File.file?(path), "Missing lazy waveform: #{track_id}")
  waveform = JSON.parse(File.binread(path))
  assert(waveform.fetch("track_id") == track_id, "Waveform ID mismatch: #{track_id}")
end

%w[
  source-serif-4-regular.woff2
  source-serif-4-semibold.woff2
  inter-regular.woff2
  inter-semibold.woff2
  funmusic-cjk-regular.woff2
].each do |name|
  path = File.join(ROOT, "assets/fonts", name)
  assert(File.file?(path) && File.size?(path), "Missing deferred font: #{name}")
  assert(html.include?("assets/fonts/#{name}"), "Font is not referenced: #{name}")
end

assert(!html.include?("Still preparing"), "Blocking preparation copy remains in index.html")
assert(!html.include?("player-boot-overlay"), "Blocking preparation overlay remains in index.html")
assert(html.include?("switchToBackupSource"), "Audio failover logic is missing")
assert(html.include?("armSourceStallTimer"), "Stall watchdog is missing")

average_mib = fallback_bytes.fdiv(items.length * 1024 * 1024)
puts format(
  "Verified %d OSS-primary MP3 entries, %d lazy waveforms, and local fallbacks (average %.2f MiB).",
  items.length,
  track_data.fetch("tracks").length,
  average_mib
)
