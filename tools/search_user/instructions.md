# search_user

Search Papertrail log archives for all activity by a specific user, correlate app events with Heroku router logs to identify client IPs, and print a request timeline.

## Prerequisites

1. A valid Papertrail (SolarWinds) API token
2. Ruby installed (see `.ruby-version` in project root)
3. Dependencies installed via `bundle install`

## Configuration

Set the following in the `.env` file at the project root:

```
PAPERTRAIL_API_TOKEN=your_token_here
TARGET_USER_ID=229
START_DATE=2026-05-18
END_DATE=2026-06-05
```

| Variable | Description |
|---|---|
| `PAPERTRAIL_API_TOKEN` | SolarWinds API token (Settings > API Tokens) |
| `TARGET_USER_ID` | The user ID to search for in logs |
| `START_DATE` | Beginning of the search window (YYYY-MM-DD) |
| `END_DATE` | End of the search window (YYYY-MM-DD) |

## Running

From the project root:

```sh
bundle exec ruby tools/search_user/script.rb
```

On the first run, all log archives in the date range are downloaded and cached to `log_cache/`. Subsequent runs skip already-cached archives, so re-runs are fast.

## Output

The report prints to stdout with three sections:

1. **Summary** -- total request count for the user
2. **Client IP summary** -- each IP address seen, with request count and date range. A warning is shown if the user was seen from multiple distinct IPs.
3. **Request timeline** -- chronological list of every matched request with timestamp, client IP, Heroku source, and the log message

Example output:

```
======================================================================
Results for user_id=229
======================================================================
Total requests found: 14

Client IPs:
  203.0.113.42 -- 12 request(s), 2026-05-18T08:12:03Z to 2026-05-20T14:33:11Z
  198.51.100.7 -- 2 request(s), 2026-05-19T22:01:44Z to 2026-05-19T22:05:12Z

  user_id=229 seen from 2 distinct IPs:
    203.0.113.42
    198.51.100.7

Request timeline:
  [2026-05-18T08:12:03Z] IP=203.0.113.42 web.1
    [abc-123] method=GET path=/dashboard user_id=229 status=200
  [2026-05-18T08:12:05Z] IP=203.0.113.42 web.2
    [abc-124] method=POST path=/settings user_id=229 status=302
  ...
```

## Generating visualizations with AI

You can pipe the output into an AI tool to generate visualizations. Save the output to a file first:

```sh
bundle exec ruby tools/search_user/script.rb > results.txt
```

Then share `results.txt` with an AI assistant (Claude, etc.) along with a prompt like:

> Here is a log of HTTP requests made by a single user, including timestamps, client IPs, and request paths. Generate a single-file HTML page with embedded JavaScript that visualizes:
>
> 1. A timeline chart showing requests over time, color-coded by client IP
> 2. A bar chart breaking down request counts by path
> 3. A table summarizing activity per IP address
>
> Use Chart.js loaded from a CDN. The page should be self-contained with no external dependencies beyond the CDN.

Open the generated HTML file in a browser to explore the results interactively. You can adjust the prompt to focus on whatever dimension matters for your investigation -- geographic patterns, request frequency, endpoint usage, time-of-day clustering, etc.
