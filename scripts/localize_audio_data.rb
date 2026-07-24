#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"

ROOT = File.expand_path("..", __dir__)
INDEX_PATH = File.join(ROOT, "index.html")

def extract_json(html, id)
  match = html.match(%r{<script type="application/json" id="#{Regexp.escape(id)}">(.*?)</script>}m)
  abort("Missing JSON payload: #{id}") unless match

  JSON.parse(match[1])
end

def safe_json(value)
  JSON.generate(value)
      .gsub("&", "\\u0026")
      .gsub("<", "\\u003c")
      .gsub(">", "\\u003e")
end

def replace_json(html, id, value)
  pattern = %r{(<script type="application/json" id="#{Regexp.escape(id)}">).*?(</script>)}m
  html.sub(pattern) { "#{Regexp.last_match(1)}#{safe_json(value)}#{Regexp.last_match(2)}" }
end

def localized_extension(url)
  extension = File.extname(url.split("?", 2).first).delete_prefix(".")
  extension == "wav" ? "flac" : extension
end

def localize_item(item, local_url, replacements)
  current_url = item.fetch("audio_url")
  return item if current_url == local_url

  abort("Unexpected non-HTTP audio URL: #{current_url}") unless current_url.start_with?("http://", "https://")

  replacements[current_url] = local_url
  item.each_with_object({}) do |(key, value), localized|
    localized[key] = key == "audio_url" ? local_url : value
    localized["audio_fallback_url"] = current_url if key == "audio_url"
  end
end

html = File.read(INDEX_PATH)
track_data = extract_json(html, "track-data")
cover_data = extract_json(html, "cover-pair-data")
replacements = {}

track_data.fetch("tracks").map! do |track|
  next track unless track.fetch("audio_url").start_with?("http://", "https://")

  extension = localized_extension(track.fetch("audio_url"))
  local_url = "assets/audio/tracks/#{track.fetch("track_id")}.#{extension}"
  localize_item(track, local_url, replacements)
end

cover_data.fetch("pairs").each do |pair|
  %w[original cover].each do |role|
    item = pair.fetch(role)
    extension = localized_extension(item.fetch("audio_url"))
    local_url = "assets/audio/covers/#{pair.fetch("pair_id")}-#{role}.#{extension}"
    pair[role] = localize_item(item, local_url, replacements)
  end
end

replacements.each do |remote_url, local_url|
  asset_path = File.join(ROOT, local_url)
  abort("Missing localized asset: #{asset_path}") unless File.file?(asset_path) && File.size?(asset_path)

  html.gsub!(CGI.escapeHTML(remote_url), local_url)
end

html = replace_json(html, "track-data", track_data)
html = replace_json(html, "cover-pair-data", cover_data)
File.write(INDEX_PATH, html)

puts "Localized #{replacements.length} audio URLs in #{INDEX_PATH}"
