# CI Pipeline Monitor

Monitor a GitLab CI pipeline execution with periodic checkpoint reports.

## Usage

```
/ci-monitor <pipeline-url-or-id>
/ci-monitor                        # monitors the latest pipeline
```

## Instructions

You are monitoring a GitLab CI pipeline for the FilmFreeway project on the self-hosted EC2 runner.

### Setup

1. Extract the pipeline ID from the argument. If a URL is provided, extract the ID from it. If no argument is given, get the latest pipeline from `glab ci status`.
2. Store the pipeline ID for all subsequent checks.

### Report format

Use this exact table format for every report:

```
┌──────────────┬─────────┬────────┬────────────────────┬────────┐
│     Node     │ Status  │ Elapsed│     Tests          │ Broken │
├──────────────┼─────────┼────────┼────────────────────┼────────┤
│ test:jest    │ passed  │  2m39s │    418 / 418       │      0 │
├──────────────┼─────────┼────────┼────────────────────┼────────┤
│ test:rspec   │ running │ 10m22s │    ??? / 704       │      - │
├──────────────┼─────────┼────────┼────────────────────┼────────┤
│ minitest 1/8 │ running │ 25m00s │    testing         │      - │
└──────────────┴─────────┴────────┴────────────────────┴────────┘
```

- For completed jobs: show exact test counts and broken count (0 for passed, number for failed)
- For running jobs: show "testing" in Tests column, "-" in Broken column
- For pending jobs: show "--" in Elapsed, "pending" in Tests column
- Jest total: 418, RSpec total: 704
- Include a checkpoint number and elapsed time header above each table

### How to fetch data

Use the GitLab API for speed (not `glab ci trace` which downloads full logs):

```bash
glab api projects/team_backstage%2Ffilmfreeway%2Ffilmfreeway/pipelines/PIPELINE_ID/jobs --paginate
```

Parse the JSON response to get job name, status, and duration.

### Monitoring loop

1. Fetch and display the first checkpoint immediately
2. Schedule the next checkpoint in 5 minutes using a background task:
   ```bash
   sleep 300 && glab api projects/team_backstage%2Ffilmfreeway%2Ffilmfreeway/pipelines/PIPELINE_ID/jobs --paginate
   ```
3. When the background task completes, display the checkpoint report
4. If the pipeline is still running, schedule another 5-minute check
5. If the pipeline is complete (success or failed), display the final report with:
   - All job times sorted by completion time
   - Spread (fastest to slowest minitest node)
   - Any failures with test names (fetch trace only for failed jobs)
   - Pipeline state

### Getting failure details

Only download traces for failed jobs (traces are large and slow):

```bash
glab ci trace --repo team_backstage/filmfreeway/filmfreeway "test:minitest N/8" 2>/dev/null | grep -A10 "FAILURES AND ERRORS SUMMARY"
```

### Key facts

- Pipeline has 10 jobs: test:jest (1), test:rspec (1), test:minitest 1-8/8 (8)
- Runner: c6i.4xlarge at ci-runner-101.filmfreeway.net, concurrent=9
- Typical times: Jest ~3 min, RSpec ~11 min, minitest ~40-50 min per node
- Pipeline wall time target: ~45-50 min
- `allow_failure: true` on minitest and rspec, so pipeline shows "success" even with test failures

### Important

- Use ONLY ONE background task at a time. Never stack multiple.
- Use the fast API call for status checks, never `glab ci trace` for running jobs.
- Keep reports concise. No extra commentary unless there's a failure or anomaly to explain.
