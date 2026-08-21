# frozen_string_literal: true

require "cgi"

class HtmlReport
  def initialize(grouped)
    @grouped = grouped
  end

  def render
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Request Logs</title>
      <style>#{styles}</style>
      </head>
      <body>
      <h1>Request Logs</h1>
      <p class="meta">#{@grouped.length} requests &middot; generated from Papertrail archive cache</p>
      #{@grouped.map { |rid, events| accordion_item(rid, events) }.join("\n")}
      </body>
      </html>
    HTML
  end

  private

  def accordion_item(rid, events)
    <<~HTML
      <details id="#{rid}">
      <summary>
      #{status_badge(events)}
      <code>#{h(rid)}</code>
      <span class="summary-meta">#{h(summary(events))}</span>
      </summary>
      #{log_table(events)}
      </details>
    HTML
  end

  def status_badge(events)
    code = status_code(events)
    return %(<span class="badge badge-none">?</span>) unless code

    %(<span class="badge badge-#{code[0]}xx">#{h(code)}</span>)
  end

  def status_code(events)
    events.reverse_each do |event|
      code = (event["logmsg"] || "")[/\bstatus=(\d{3})\b/, 1]
      return code if code
    end
    nil
  end

  def log_table(events)
    return %(<p class="meta">No matching log lines found in cache</p>) if events.empty?

    <<~HTML
      <table>
      <thead><tr><th>Time (UTC)</th><th>Source</th><th>Severity</th><th>Message</th></tr></thead>
      <tbody>
      #{events.map { |e| event_row(e) }.join("\n")}
      </tbody>
      </table>
    HTML
  end

  def summary(events)
    return "no log lines found" if events.empty?

    first = events.first.dig("syslog", "timestamp").to_s
    sources = events.map { |e| e["source_name"] }.uniq.compact.join(", ")
    "#{first[0, 19]} · #{sources} · #{events.length} lines"
  end

  def event_row(event)
    severity = event.dig("syslog", "severity").to_s
    <<~HTML
      <tr class="sev-#{severity.downcase.gsub(/\s+/, '-')}">
      <td class="time">#{h(event.dig('syslog', 'timestamp').to_s[11, 15])}</td>
      <td class="source">#{h(event['syslog_appname'])}</td>
      <td class="severity">#{h(severity)}</td>
      <td class="message">#{h(event['logmsg'])}</td>
      </tr>
    HTML
  end

  def h(text)
    CGI.escapeHTML(text.to_s)
  end

  def styles
    <<~CSS
      :root {
        --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --border: #e5e7eb;
        --section-bg: #f9fafb; --error: #b91c1c; --warn: #b45309;
        --badge-2xx-bg: #dcfce7; --badge-2xx-fg: #166534;
        --badge-3xx-bg: #dbeafe; --badge-3xx-fg: #1e40af;
        --badge-4xx-bg: #fef3c7; --badge-4xx-fg: #92400e;
        --badge-5xx-bg: #fee2e2; --badge-5xx-fg: #991b1b;
        --badge-none-bg: #e5e7eb; --badge-none-fg: #4b5563;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #111418; --fg: #e5e7eb; --muted: #9ca3af; --border: #2d333b;
          --section-bg: #1a1f26; --error: #f87171; --warn: #fbbf24;
          --badge-2xx-bg: #14532d; --badge-2xx-fg: #86efac;
          --badge-3xx-bg: #1e3a8a; --badge-3xx-fg: #93c5fd;
          --badge-4xx-bg: #78350f; --badge-4xx-fg: #fcd34d;
          --badge-5xx-bg: #7f1d1d; --badge-5xx-fg: #fca5a5;
          --badge-none-bg: #374151; --badge-none-fg: #d1d5db;
        }
      }
      * { box-sizing: border-box; }
      body {
        margin: 0 auto; padding: 2rem 1.5rem; max-width: 1200px;
        background: var(--bg); color: var(--fg);
        font: 15px/1.5 -apple-system, "Segoe UI", sans-serif;
      }
      h1 { font-size: 1.4rem; margin: 0 0 0.25rem; }
      .meta { color: var(--muted); font-size: 0.85rem; margin: 0 0 1rem; }
      code { font-family: ui-monospace, "SF Mono", Menlo, monospace; }
      details {
        margin-bottom: 0.5rem;
        background: var(--section-bg); border: 1px solid var(--border); border-radius: 8px;
      }
      summary {
        display: flex; align-items: center; gap: 0.75rem;
        padding: 0.6rem 0.9rem; cursor: pointer; font-size: 0.85rem;
        list-style: none;
      }
      summary::-webkit-details-marker { display: none; }
      summary::after { content: "▸"; margin-left: auto; color: var(--muted); }
      details[open] summary::after { content: "▾"; }
      details[open] summary { border-bottom: 1px solid var(--border); }
      .summary-meta { color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      .badge {
        flex-shrink: 0; min-width: 2.6em; text-align: center;
        padding: 0.15em 0.5em; border-radius: 999px;
        font: 700 0.8rem/1.4 ui-monospace, "SF Mono", Menlo, monospace;
      }
      .badge-2xx { background: var(--badge-2xx-bg); color: var(--badge-2xx-fg); }
      .badge-3xx { background: var(--badge-3xx-bg); color: var(--badge-3xx-fg); }
      .badge-4xx { background: var(--badge-4xx-bg); color: var(--badge-4xx-fg); }
      .badge-5xx { background: var(--badge-5xx-bg); color: var(--badge-5xx-fg); }
      .badge-none { background: var(--badge-none-bg); color: var(--badge-none-fg); }
      details .meta { padding: 0.75rem 0.9rem; margin: 0; }
      table {
        width: 100%; border-collapse: collapse; display: block; overflow-x: auto;
        padding: 0.5rem 0.9rem 0.9rem;
        font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 0.78rem;
      }
      th, td {
        text-align: left; padding: 0.25rem 0.6rem;
        border-bottom: 1px solid var(--border); vertical-align: top;
      }
      th { color: var(--muted); font-weight: 600; }
      td.time, td.source, td.severity { white-space: nowrap; }
      td.message { white-space: pre-wrap; word-break: break-word; }
      tr.sev-error td, tr.sev-critical td { color: var(--error); }
      tr.sev-warning td { color: var(--warn); }
    CSS
  end
end
