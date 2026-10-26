# Solarwinds Papertrail Logs Toolbox

A collection of tools for investigating user activity and security events using Papertrail (SolarWinds) log archives.

## Setup

Requires Ruby (see `.ruby-version`) and Bundler.

```sh
bundle install
```

Create a `.env` file in the project root with the required credentials:

```
PAPERTRAIL_API_TOKEN=your_token_here
APP_NAME=C12
TARGET_USER_ID=229
```

`APP_NAME` picks which app's cache to use. Each app gets its own folder under `log_cache/`, so one checkout can serve several projects.

Generate the Solarwinds Papertrail token within the Solarwinds "Settings => API Tokens" tab.

## How it works

### Log fetching and caching

The shared library (`lib/`) handles downloading and caching Papertrail log archives. Archives are fetched once and stored as gzipped JSONL files in `log_cache/<APP_NAME>/`. On subsequent runs, only new archives are downloaded — cached files are skipped automatically. This makes repeated analysis fast and avoids redundant API calls.

The app's cache folder is created on first run.

### Time window

Tools that fetch logs take the window as options. With none, they fetch the last 24 hours.

| Option | Meaning |
|---|---|
| `--from TIME` | Start of the window (e.g. `2026-05-18` or `2026-05-18T14:00`) |
| `--to TIME` | End of the window (default: now) |
| `--hours N` | Window length when `--from` is left out (default: 24) |

### Shared library (`lib/`)

| File | Purpose |
|---|---|
| `papertrail_client.rb` | Papertrail API client (archive listing, downloading, rate-limit handling) |
| `event_cache.rb` | Local gzip cache for downloaded log archives |
| `event_fetcher.rb` | Fetches and caches the archives in a time window |
| `time_window.rb` | Parses `--from`, `--to` and `--hours` options |

## Tools

Each tool lives in its own directory under `tools/` with a `script.rb` entry point.

### search_user

Searches all cached logs for activity by a specific user, correlates app-level events with Heroku router logs to determine client IP addresses, and prints a timeline of requests.

```sh
bundle exec ruby tools/search_user/script.rb --from 2026-05-18 --to 2026-06-05
```

Output includes:
- Total request count
- Client IP summary with request counts and date ranges
- Warning if multiple distinct IPs are detected
- Full request timeline with timestamps, IPs, and request details

## Adding new tools

To add a new investigation tool:

1. Create a new directory under `tools/` (e.g. `tools/my_tool/`)
2. Add a `script.rb` entry point
3. Use the shared `lib/` classes for log fetching and caching
4. Keep tool-specific logic (analyzers, formatters, reports) within the tool's directory
