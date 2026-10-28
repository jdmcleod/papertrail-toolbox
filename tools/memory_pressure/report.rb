# frozen_string_literal: true

class Report
  TOP_JUMPS = 10
  TOP_PATHS = 12

  def initialize(analyzer, window)
    @analyzer = analyzer
    @window = window
  end

  def print
    puts "=" * 80
    puts "Memory pressure report (#{@window})"
    puts "=" * 80

    print_coverage
    print_errors
    print_lifecycle
    @analyzer.dynos.each { |dyno| print_dyno(dyno) }
  end

  private

  def print_coverage
    expected = hours_in_window
    missing = expected - @analyzer.hours_seen.keys

    puts
    puts "Log coverage: #{expected.length - missing.length} of #{expected.length} hours (UTC)"
    puts "  Missing: #{collapse(missing).join(', ')}" if missing.any?
  end

  def print_errors
    puts
    puts "Dyno errors:"
    print_counts(@analyzer.dyno_errors.transform_keys { |dyno, code| "#{dyno} #{code}" })
    puts "Router errors:"
    print_counts(@analyzer.router_errors)
  end

  def print_counts(counts)
    return puts("  none") if counts.empty?

    counts.sort_by { |_, count| -count }.each { |key, count| puts "  #{key}: #{count}" }
  end

  def print_lifecycle
    puts
    puts "Restarts and exits:"
    return puts("  none") if @analyzer.lifecycle_events.empty?

    @analyzer.lifecycle_events.each do |time, dyno, message|
      puts "  #{time.strftime('%Y-%m-%d %H:%M:%S')} #{dyno}: #{message[0, 100]}"
    end
  end

  def print_dyno(dyno)
    puts
    puts "-" * 80
    puts "#{dyno} memory (MB, UTC)"
    puts "-" * 80
    print_hourly(dyno)
    print_jumps(dyno)
    print_growth(dyno)
  end

  def print_hourly(dyno)
    puts format("  %-16s %6s %6s %6s %6s", "hour", "n", "min", "median", "max")
    @analyzer.hourly_memory(dyno).sort.each do |hour, stats|
      puts format("  %-16s %6d %6d %6d %6d", hour, stats[:count], stats[:min], stats[:median], stats[:max])
    end
  end

  def print_jumps(dyno)
    jumps = @analyzer.jumps(dyno)
    rises = jumps.sum { |j| [j.megabytes, 0].max }
    falls = jumps.sum { |j| [j.megabytes, 0].min }

    puts
    puts "  Rises total #{rises} MB, falls total #{falls} MB, net #{rises + falls} MB"
    puts "  Largest rises between samples:"
    jumps.max_by(TOP_JUMPS, &:megabytes).each do |jump|
      paths = jump.requests.map { |r| "#{r.method} #{r.path} (#{r.service_ms}ms)" }
      puts "    +#{jump.megabytes}MB #{jump.time.strftime('%Y-%m-%d %H:%M:%S')}  #{paths.first(4).join(', ')}"
    end
  end

  def print_growth(dyno)
    counts = @analyzer.requests_by_path(dyno)

    puts
    puts "  Memory rises shared across concurrent requests, by path:"
    @analyzer.growth_by_path(dyno).max_by(TOP_PATHS) { |_, mb| mb }.each do |path, mb|
      puts format("    %7.1f MB  %5s reqs  %s", mb, counts.fetch(path, "-"), path[0, 80])
    end
  end

  def hours_in_window
    first = Time.at((@window.start_time.to_i / 3600) * 3600).utc
    (first.to_i..@window.end_time.to_i).step(3600).map { |t| Time.at(t).utc.strftime("%Y-%m-%d %H:00") }
  end

  def collapse(hours)
    hours.slice_when { |a, b| Time.parse("#{b} UTC") - Time.parse("#{a} UTC") > 3600 }
         .map { |run| run.length == 1 ? run.first : "#{run.first}–#{run.last[-5..]}" }
  end
end
