# frozen_string_literal: true

require "json"
require "fileutils"
require "zlib"

class EventCache
  def initialize(dir)
    @dir = dir
    FileUtils.mkdir_p(@dir)
  end

  def exists?(filename)
    File.exist?(path_for(filename))
  end

  def write_archive(filename, data)
    File.binwrite(path_for(filename), data)
  end

  def read_all
    Dir.glob(File.join(@dir, "*.gz")).sort.flat_map { |path| read_gz(path) }
  end

  private

  def path_for(filename)
    File.join(@dir, filename)
  end

  def read_gz(path)
    events = []
    Zlib::GzipReader.open(path) do |gz|
      gz.each_line do |line|
        events << JSON.parse(line)
      rescue JSON::ParserError
        next
      end
    end
    events
  rescue Zlib::GzipFile::Error => e
    warn "  Skipping corrupt archive #{File.basename(path)}: #{e.message}"
    []
  end
end
