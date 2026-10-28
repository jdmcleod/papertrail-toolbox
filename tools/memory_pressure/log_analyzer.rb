# frozen_string_literal: true

class LogAnalyzer
  MemorySample = Struct.new(:time, :dyno, :megabytes)
  Request = Struct.new(:time, :dyno, :method, :path, :service_ms)
  Jump = Struct.new(:time, :dyno, :megabytes, :requests)

  MEMORY_SAMPLE = /Process running mem=(\d+)M/
  DYNO_ERROR = /Error (R\d+)/
  ROUTER_CODE = /\bcode=(H\d+)/
  LIFECYCLE = /Restarting|Stopping all processes|Process exited|Cycling|crashed/
  SAMPLE_INTERVAL_MS = 20_000

  attr_reader :memory_samples, :requests, :dyno_errors, :router_errors, :lifecycle_events, :hours_seen

  def initialize(events)
    @memory_samples = []
    @requests = []
    @dyno_errors = Hash.new(0)
    @router_errors = Hash.new(0)
    @lifecycle_events = []
    @hours_seen = Hash.new(0)
    events.sort_by { |e| e["time"].to_i }.each { |event| ingest(event) }
  end

  def dynos
    memory_samples.map(&:dyno).uniq.sort
  end

  def hourly_memory(dyno)
    samples_for(dyno).group_by { |s| s.time.strftime("%Y-%m-%d %H:00") }.transform_values do |samples|
      values = samples.map(&:megabytes).sort
      { count: values.length, min: values.first, median: values[values.length / 2], max: values.last }
    end
  end

  def jumps(dyno)
    samples_for(dyno).each_cons(2).map do |before, after|
      window_start = before.time - (SAMPLE_INTERVAL_MS / 1000.0)
      concurrent = requests.select { |r| r.dyno == dyno && r.time >= window_start && r.time <= after.time }
      Jump.new(after.time, dyno, after.megabytes - before.megabytes, concurrent)
    end
  end

  def growth_by_path(dyno)
    totals = Hash.new(0.0)
    jumps(dyno).select { |j| j.megabytes.positive? }.each do |jump|
      if jump.requests.empty?
        totals["(no requests)"] += jump.megabytes
      else
        share = jump.megabytes.to_f / jump.requests.length
        jump.requests.each { |r| totals["#{r.method} #{r.path}"] += share }
      end
    end
    totals
  end

  def requests_by_path(dyno)
    requests.select { |r| r.dyno == dyno }.group_by { |r| "#{r.method} #{r.path}" }.transform_values(&:length)
  end

  private

  def samples_for(dyno)
    memory_samples.select { |s| s.dyno == dyno }
  end

  def ingest(event)
    source = event["syslog_appname"].to_s
    message = event["logmsg"].to_s
    time = Time.at(event["time"].to_i / 1000.0).utc
    hours_seen[time.strftime("%Y-%m-%d %H:00")] += 1

    if source == "heroku/router"
      ingest_router(time, message)
    elsif source.start_with?("heroku/")
      ingest_dyno(time, source.delete_prefix("heroku/"), message)
    end
  end

  def ingest_dyno(time, dyno, message)
    if (match = message.match(MEMORY_SAMPLE))
      memory_samples << MemorySample.new(time, dyno, match[1].to_i)
    elsif (match = message.match(DYNO_ERROR))
      dyno_errors[[dyno, match[1]]] += 1
    elsif message.match?(LIFECYCLE) && !dyno.start_with?("scheduler", "release", "run")
      lifecycle_events << [time, dyno, message]
    end
  end

  def ingest_router(time, message)
    fields = message.scan(/(\w+)=("[^"]*"|\S+)/).to_h
    router_errors[fields["code"]] += 1 if message.match?(ROUTER_CODE)
    path = fields["path"].to_s.delete('"').split("?").first.to_s
    return if path == "/cable" || fields["dyno"].nil?

    requests << Request.new(time, fields["dyno"], fields["method"], normalize(path), fields["service"].to_i)
  end

  def normalize(path)
    path.gsub(%r{/[A-Za-z0-9_=-]{20,}}, "/:token").gsub(/\d+/, ":id")
  end
end
