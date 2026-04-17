---
name: ci-gamekeeper
version: 0.1.0
description: |
  Investigate and fix CI or local test failures. Pulls pipeline artifacts
  (screenshots, HTML snapshots, trace logs), cross-references the project's
  playbook for matching fix patterns, classifies failures (real regression vs
  timing race vs test pollution vs DOM fragility), and proposes or auto-applies
  minimal test-layer fixes. Never modifies application code. Triggers on: CI
  failure investigation, pipeline failures, flaky test diagnosis, broken tests,
  test stability work, integration test failures, Capybara ElementNotFound
  errors, and "why is this test failing on CI but passing locally" questions.
license: MIT
compatibility: claude-code
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Agent
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# CI Gamekeeper — Failure Investigation and Fix

Specialized workflow for investigating CI or local test failures, understanding them within project context, and proposing (or auto-applying) fixes that match the project's existing patterns.

The metaphor is intentional: you are the steward of the test ecosystem. Your job is to know the terrain (project playbook, prior incidents), identify what's broken, and restore balance with the smallest necessary intervention. Not a one-shot hunter.

## Invocation modes

This skill can be triggered explicitly or auto-invoked when Claude detects CI/test-failure context in the user's message.

Explicit invocation:

```
/ci-gamekeeper                              # investigate latest pipeline on current branch
/ci-gamekeeper <pipeline-id-or-url>         # specific pipeline
/ci-gamekeeper job <job-id>                 # single failed job
/ci-gamekeeper local <test-path>            # locally failing test
/ci-gamekeeper --auto <target>              # auto-apply high-confidence fixes
```

`--auto` applies fixes whose pattern match is unambiguous (verified or evidence-backed hypothesis AND a matching playbook recipe). Ambiguous fixes still stop for review even in auto mode.

## Operating principles

- **Never modify application code to fix a test.** Tests adapt to application code. If a test is failing because of a real regression, stop and report — do not patch the app.
- **Never stage or commit.** End by telling the user which files are ready to review, test, and commit. The user owns those actions.
- **Diff-first outside `--auto`.** Show proposed edits before writing them.
- **Never run tests autonomously.** Give copy-pasteable commands; the user runs them.
- **Run all final report text through the `humanizer` skill** before presenting, if available in the environment.

## Phase 1 — Project discovery

Before anything else, invoke the `project-scanner` agent to establish:

- Knowledge base paths — look for `.claude/context/playbook.md`, `.claude/context/code.md`, `memory/`, `.claude/personal/activeContext.md`
- CI tooling (gitlab / github / buildkite / circle), artifact naming, job structure
- Test frameworks in use (RSpec / Minitest / Jest / pytest / etc.) and their support directories (`spec/support/`, `test/support/`)
- Stub modules, factories, and preferred mocking style (e.g., WebMock vs VCR)
- Docker container names for running tests locally
- Branch the user is on and the default branch name

Read `.claude/context/playbook.md` (or the project's equivalent) cover to cover. This file is the canonical library of project-specific fix patterns — every investigation must cross-reference it before proposing a fix.

If the project has `.claude/personal/activeContext.md`, read it for current work context and prior related sessions.

## Phase 2 — Failure discovery

### CI mode

```bash
# Pipeline jobs — API is faster than trace
glab api "projects/<URL_ENCODED_PATH>/pipelines/<PID>/jobs" --paginate
```

Identify all `failed` jobs. If `allow_failure: true` hides them at pipeline level, still surface them — pipeline "success" does not mean test success.

If pipeline ID returns 404, list the last 10 pipelines on the current branch and ask the user to confirm.

If the pipeline is still running, stop and suggest `/ci-monitor` — do not investigate live failures.

### Local mode

Read `log/test.log`, the failing test's captured output (passed by the user or printed to terminal), `tmp/capybara/`, and `tmp/screenshots/` directly from the working directory.

Note: local mode has no retry info and `tmp/` may have been flushed between runs.

## Phase 3 — Artifact collection

### CI mode

For each failed job:

```bash
mkdir -p tmp/ci-artifacts/p<PID>/<job_slug>
glab api "projects/<URL_ENCODED_PATH>/jobs/<JOB_ID>/artifacts" > tmp/ci-artifacts/p<PID>/<job_slug>.zip
unzip -o -q tmp/ci-artifacts/p<PID>/<job_slug>.zip -d tmp/ci-artifacts/p<PID>/<job_slug>/
```

For trace-only fallback (failed job with no artifacts):

```bash
glab api "projects/<URL_ENCODED_PATH>/jobs/<JOB_ID>/trace"
```

### Artifacts to always look for

- `tmp/capybara/*.html` — DOM state at the moment of failure
- `tmp/screenshots/*.png` — visual confirmation of what the browser saw
- `log/ci/*.log` — trace with test ordering, memory state, browser console

## Phase 4 — Evidence analysis

Parse and correlate:

- **HTML snapshot**: what was actually on the page? Empty result area, missing element, unexpected modal state?
- **Screenshot**: visual confirmation the DOM reflects what the user sees.
- **`[JS-DEBUG]` lines**: `lockstep`, `hydratedComponents`, `reactComponents`, `jsErrors`. `hydratedComponents=0` on a page expecting React is a smoking gun.
- **`[BROWSER-CONSOLE]`**: CSP violations are usually cosmetic; genuine `TypeError`, `ReferenceError`, module load failures are not.
- **`[MinitestRetry]` lines**: retry-count and retry message.
  - Same error twice → state / data / pollution issue, not timing
  - Different errors across retries → timing race
- **Test ordering**: which tests ran before the failing one on this node? A heavy test mutating ES or cache right before is a pollution suspect.

## Phase 5 — Cross-reference with playbook and memory

Before forming a hypothesis:

```bash
# Grep the project playbook for the error class and related keywords
grep -n -i "<error_keyword>" .claude/context/playbook.md

# Grep memory/personal context for prior incidents with the same symptom
grep -rln "<error_keyword>" memory/ .claude/personal/ 2>/dev/null
```

Also check git log on the failing test file and any app code it touches over the last 2 weeks — a recent change is often the trigger.

If a prior incident matches, surface it: *"this matches the fix pattern from [memory file / ticket X]."*

## Phase 6 — Root cause hypothesis

Classify the failure:

| Class | Signal | Action |
|---|---|---|
| Real app regression | Same error on many nodes, error class is not environmental, git log shows recent app change | STOP, report to user, do not patch |
| Test environment mismatch | External service unreachable, missing stub, VCR cassette absent | Add stub from project's support modules |
| Timing race | Different error on retries, `lockstep=false`, missing `wait_for_*` | Add wait guard |
| Data race / pollution | Same error on both retries, prior test mutates shared state, ES/cache stale | Add `refresh_index` / clear state / fix factory |
| DOM position fragility | `[n]`-based lookup, dynamic list, position changes after refresh | Replace with scoped / content-based lookup |

State the hypothesis with **confidence**: `verified`, `evidence-backed`, `heuristic`, or `guess`. Do not propose fixes on a `guess`.

## Phase 7 — Fix strategy

Decide between:

- **In-place patch** for timing / data / DOM fragility matching a known playbook recipe.
- **Partial migration** to a lower test level (request spec / unit spec) when the integration test is testing logic that doesn't need a browser (permission matrices, data math, JSON endpoint behavior). Trim the integration test to one happy-path scenario only.
- **No fix, escalate** when a real app regression is suspected.

## Phase 8 — Red baseline (coverage check)

Before applying any fix, a test must exist that captures the broken scenario. This is the red half of a red-green loop. Three cases:

- **The failing CI/local test IS the red baseline.** Most common case. You already have the failing evidence from phases 2–4. Proceed to Phase 9.
- **Partial migration path** — e.g., extracting logic from a flaky integration test to a request spec. The new test file is being created. Write the extracted tests first and confirm they PASS against current code (they codify existing behavior). Only then trim the integration test. Here "red" is inverted: verify the new coverage is green on current code *before* reducing the old coverage, so the net coverage never dips below zero.
- **Fix target has no test coverage** — a factory, helper, stub module, migration file, or other support file the fix will touch, with no spec of its own. Write a test that reproduces the failure mode first.
  - Present as a diff, write on approval.
  - Handoff: *"Run this command to confirm the test fails (red) before I apply the fix: `<cmd>`."*
  - Wait for the user to confirm the test is red. **Do not apply the fix until the baseline is confirmed.**

This phase is non-negotiable. A fix without a test that proves the failure existed is a fix that can silently regress.

## Phase 9 — Apply fix and verify green

Rules regardless of mode:

- Prefer editing existing files. Never add new files unless a migration needs one (e.g., new request spec) or Phase 8 required writing a new test.
- Use existing stub modules from the project's test support directory — never add VCR cassettes where WebMock stubs exist.
- Follow project conventions for RSpec vs Minitest (per project playbook / CLAUDE.md).
- Never add `if Rails.env.test?` branches, test-only routes, or test-only controller actions in app code.
- Never use `--no-verify`, `--no-gpg-sign`, or similar bypasses.

Diff-first mode (default): show the proposed change, wait for approval, then write.

`--auto` mode: apply when the hypothesis is `verified` or `evidence-backed` AND a matching playbook recipe exists. Otherwise fall back to diff-first.

After writing the fix:

- Handoff: *"Run this command to confirm the fix turns the test green: `<cmd>`."*
- If the user reports the test is still red, do **not** double down on the current hypothesis. Return to Phase 4 (evidence analysis) with the new information and re-classify.

Do not run tests. Do not stage. Do not commit.

Files-ready report once green is confirmed:

```
Files ready to review, test, and commit:
  - test/integration/foo_test.rb       (in-place patch)
  - spec/requests/foo_spec.rb          (new request spec examples)

Suggested broader verification:
  docker exec -it <container> bundle exec rspec spec/requests/foo_spec.rb
  docker exec -it <container> bundle exec rails test test/integration/foo_test.rb
```

## Phase 10 — Playbook update

Every investigation ends here — this is mandatory, not optional.

If the fix applied a pattern already in `.claude/context/playbook.md`: skip the update, but reference the pattern in the final report.

If the fix revealed a new pattern, or clarified an existing one:

- Draft a short playbook entry: **Symptom → Root cause → Fix (with code snippet) → Reason it works**
- Present the draft in diff form against the playbook file
- Ask the user to approve before writing

Also propose a memory file entry if the session surfaced a non-obvious decision (`memory/project_<short_name>.md` per the project's memory conventions).

## Rules of thumb

- If the user gives you a URL, extract the pipeline / job ID and work from that.
- If you're about to propose a fix that changes app code, STOP. You're on the wrong track.
- If two retries failed with different errors, it's timing. If they failed with the same error, it's state.
- If one node out of many fails, suspect test pollution. If many nodes fail the same test, suspect a real bug.
- CSP errors in browser console are almost always noise. JS errors are almost always signal.
- Prefer content-based and scoped Capybara lookups over position and global ones.
- Request spec > integration spec when the logic doesn't need a browser.
