# frozen_string_literal: true

Match = Struct.new(:request_id, :client_ip, :timestamp, :detail, :source, keyword_init: true)

class LogAnalyzer
  def initialize(user_id)
    @user_id = user_id
    @user_pattern = /user_id=#{user_id}\b/
  end

  def correlate(events)
    router_index = {}
    app_index = {}

    events.each do |event|
      logmsg = event["logmsg"] || ""
      heroku = event["heroku"] || {}
      timestamp = event.dig("syslog", "timestamp")
      request_id = heroku["request_id"] || extract_request_id(logmsg)

      index_router_event(router_index, request_id, heroku["fwd"], timestamp)
      index_app_event(app_index, request_id, logmsg, timestamp, event)
    end

    build_matches(app_index, router_index)
  end

  private

  def extract_request_id(message)
    message[/request_id=([0-9a-f-]+)/, 1] || message[/^\[([0-9a-f-]+)\]/, 1]
  end

  def index_router_event(index, request_id, fwd, timestamp)
    return unless request_id && fwd && !fwd.empty?

    index[request_id] = { ip: fwd, timestamp: timestamp }
  end

  def index_app_event(index, request_id, logmsg, timestamp, event)
    return unless logmsg.match?(@user_pattern)

    rid = logmsg[/^\[([0-9a-f-]+)\]/, 1] || request_id
    return unless rid

    index[rid] = {
      message: logmsg,
      timestamp: timestamp,
      source: event["syslog_appname"] || "#{event["source_name"]}/#{event.dig("syslog", "procId")}"
    }
  end

  def build_matches(app_index, router_index)
    app_index.map do |req_id, app_data|
      router = router_index[req_id]

      Match.new(
        request_id: req_id,
        client_ip: router&.dig(:ip) || "unknown",
        timestamp: app_data[:timestamp] || router&.dig(:timestamp),
        detail: app_data[:message],
        source: app_data[:source]
      )
    end.sort_by { |m| m.timestamp.to_s }
  end
end
