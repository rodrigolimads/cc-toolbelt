---
description: Autonomous development workflow that coordinates specialized agents to build, test, and review production-ready code through a systematic 10-phase process.
argument-hint: feature-description or ISSUE-KEY
---

# Autonomous Development Workflow (/dev)

You are orchestrating a comprehensive development workflow that delivers production-ready code through specialized agents. Guide the user through 10 phases with clear decision gates.

## Project Discovery (runs before everything)

Before any phase, run the project scanner to build context:

```
Use Agent tool with subagent_type="project-scanner"

Prompt:
"Scan this project and build a context summary. Read all CLAUDE.md files
(global and project-level), discover knowledge base directories, check for
config.md, detect the tech stack, and report git state.

Skip session summaries, diaries, and MEMORY.md index files.
Report only what you find -- don't guess."
```

Store the scanner's output as `PROJECT_CONTEXT`. Pass it to every subsequent agent as part of their prompt. This ensures all agents share the same understanding of the project's conventions, rules, and existing knowledge.

The project scanner will also find `config.md` if it exists, which provides issue tracker configuration and any custom settings.

## Command Input

Parse the command argument:

**Pattern 1: Natural Language**
```
/dev "add user authentication with JWT tokens"
```

**Pattern 2: Issue Tracker Ticket**
```
/dev "FF-1234"
```

Detect issue key pattern: `[A-Z]+-\d+`

## Workflow Overview

Execute these 10 phases sequentially, with user approval at decision gates:

0. **Input Processing** - Detect and fetch issue tracker ticket if needed
1. **Requirements Discovery** - Clarify intent and acceptance criteria
2. **Architecture Design** - Propose implementation approach
3. **Implementation** - Write code
4. **Test Strategy** - Design testing approach
5. **Test Creation** - Build test suite
6. **Test Execution** - Run tests and fix failures
7. **Manual Testing Guide** - Create QA instructions
8. **Quality Review** - Final validation
9. **Knowledge Base Update** - Document decisions
10. **Deployment Readiness** - Confirm production-ready

## Phase 0: Input Processing

### If Issue Tracker Pattern Detected

Check if argument matches an issue key pattern (e.g., `FF-1234`, `JER-567`).
The pattern `[A-Z]+-\d+` indicates an issue tracker reference.

**Steps:**
1. Detect issue key pattern
2. Use the issue tracker settings from PROJECT_CONTEXT (discovered by scanner from config.md or project conventions)
3. Fetch issue details using the configured MCP tool (e.g., `mcp__atlassian__getJiraIssue` for Jira, `mcp__linear-server__get_issue` for Linear)
4. Extract:
   - Title
   - Description
   - Labels / Tags
   - Project
   - Assignee
   - Related issues (blocked by, blocks, duplicates, related to)
5. Present issue summary to user
6. Use this as the requirements input

**Output:**
```
Issue: FF-1234

Title: [Issue title]
Description: [Issue description]
Labels: [labels]
Project: [project name]

Related Issues:
- Blocked by: [issue keys]
- Blocks: [issue keys]
- Related: [issue keys]

Proceeding with requirements analysis...
```

### If Natural Language

Proceed directly to Phase 1 with the user's description.

## Phase 1: Requirements Discovery

**Use TodoWrite** to track phases:
```
1. [done] Input processed
2. [in-progress] Analyzing requirements
3. [pending] Architecture design
4. [pending] Implementation
...
```

**Launch Agent:**
```
Use Task tool with subagent_type="requirements-analyst"

Prompt:
"Analyze the following feature request and clarify requirements:

[Issue details OR user description]

Project Context (from scanner):
[INSERT PROJECT_CONTEXT here]

Also review existing codebase for similar features.

Provide:
1. Functional requirements
2. Non-functional requirements
3. Edge cases
4. Acceptance criteria
5. Technical constraints
6. Clarifying questions if needed
"
```

**After Agent Returns:**
1. Review agent's findings
2. If clarifying questions exist: Use AskUserQuestion
3. Present requirements summary
4. **DECISION GATE:** Ask user to approve requirements before proceeding

**User Approval Required:**
```
Requirements Summary:
[Agent's summary]

Do you approve these requirements?
[Yes/No/Modify]
```

Only proceed to Phase 2 after approval.

## Phase 2: Architecture Design

**Update Todo:** Mark requirements complete, start architecture

**Launch Agent:**
```
Use Task tool with subagent_type="code-architect"

Prompt:
"Design implementation architecture for:

Requirements:
[Approved requirements from Phase 1]

Project Context (from scanner):
[INSERT PROJECT_CONTEXT here]

Provide:
1. Recommended architecture
2. Files to create/modify
3. Key design decisions with rationale
4. Alternative approaches considered
5. Risks and mitigations
6. Implementation steps
"
```

**After Agent Returns:**
1. Review proposed architecture
2. Read critical files identified by agent
3. Present architecture summary
4. **DECISION GATE:** Ask user to approve architecture

**User Approval Required:**
```
Proposed Architecture:
[Agent's architecture overview]

Key Decisions:
[Major decisions with rationale]

Files to Modify:
[List of files]

Do you approve this architecture?
[Yes/No/Modify]
```

Only proceed to Phase 3 after approval.

## Phase 3: Implementation

**Update Todo:** Mark architecture complete, start implementation

**Launch Agent:**
```
Use Task tool with subagent_type="code-builder"

Prompt:
"Implement the following architecture:

Architecture:
[Approved architecture from Phase 2]

Requirements:
[Requirements from Phase 1]

Guidelines:
- Follow approved architecture exactly
- Use existing gems and patterns
- Write clean, readable code
- Handle edge cases properly
- No comments unless genuinely needed
- Follow Ruby/Rails style guide
- Follow project conventions from PROJECT_CONTEXT

Present:
1. Files created (full content)
2. Files modified (clear diffs)
3. Key implementation decisions
4. Edge cases handled
"
```

**After Agent Returns:**
1. Review all code changes
2. Present clear diffs to user
3. **DECISION GATE:** Ask user to approve implementation

**User Approval Required:**
```
Implementation Summary:
[Agent's summary]

Files Created:
[List with purposes]

Files Modified:
[List with changes]

Do you approve this implementation?
[Yes/No/Modify]
```

Only proceed to Phase 4 after approval.

## Phase 4: Test Strategy

**Update Todo:** Mark implementation complete, start test strategy

**Launch Agent:**
```
Use Task tool with subagent_type="test-strategist"

Prompt:
"Design test strategy for:

Implementation:
[Code from Phase 3]

Requirements:
[From Phase 1]

Guidelines:
- Check spec/support/ for existing test infrastructure
- Prefer request specs over integration tests
- Only create integration tests for UI behavior
- Focus on core logic, not implementation details
- Consider existing test patterns

Provide:
1. Test types recommended (unit/request/integration)
2. Coverage plan (happy path, edge cases, errors)
3. Existing test infrastructure to reuse
4. Mocking strategy
5. Test organization
6. Rationale for decisions
"
```

**After Agent Returns:**
1. Review test strategy
2. Present strategy summary
3. **DECISION GATE:** Ask user to approve test strategy

**User Approval Required:**
```
Test Strategy:
[Agent's summary]

Test Types:
- Unit tests: [count and purpose]
- Request specs: [count and purpose]
- Integration tests: [count and purpose, if any]

Do you approve this test strategy?
[Yes/No/Modify]
```

Only proceed to Phase 5 after approval.

## Phase 5: Test Creation

**Update Todo:** Mark test strategy complete, start test creation

**Launch Agent:**
```
Use Task tool with subagent_type="test-builder"

Prompt:
"Create tests following this strategy:

Test Strategy:
[Approved strategy from Phase 4]

Implementation:
[Code from Phase 3]

Guidelines:
- Reuse test infrastructure from spec/support/
- Follow project RSpec patterns
- Descriptive test names
- Focus on core logic
- One concept per test
- Use appropriate matchers

Provide:
1. All test files (full content)
2. Test coverage summary
3. Test infrastructure used
4. Notable decisions
"
```

**After Agent Returns:**
1. Review all test files
2. Present test summary
3. **DECISION GATE:** Ask user to approve tests

**User Approval Required:**
```
Tests Created:
[List of test files]

Coverage:
[Summary of what's tested]

Do you approve these tests?
[Yes/No/Modify]
```

Only proceed to Phase 6 after approval.

## Phase 6: Test Execution

**Update Todo:** Mark test creation complete, start test execution

**Launch Agent:**
```
Use Task tool with subagent_type="test-runner"

Prompt:
"Run tests and iterate until all pass:

Tests:
[Test files from Phase 5]

Process:
1. Run bundle exec rspec for new/modified tests
2. If failures exist:
   - Diagnose root causes
   - Propose specific fixes with file:line
   - Apply fixes
   - Re-run tests
3. Iterate until all tests pass
4. Report final status

Provide:
1. Test run results
2. Failure analysis (if any)
3. Specific fixes applied
4. Final status (all passing)
"
```

**After Agent Returns:**
1. Verify all tests pass
2. If tests don't pass, re-launch agent or ask user for guidance
3. Present final test results

**No Decision Gate** - Automatic iteration until tests pass

Continue when all tests pass.

## Phase 7: Manual Testing Guide

**Update Todo:** Mark test execution complete, start manual guide

**Launch Agent:**
```
Use Task tool with subagent_type="manual-test-guide"

Prompt:
"Create comprehensive manual testing guide for:

Feature:
[Requirements from Phase 1]

Implementation:
[Code from Phase 3]

Provide:
1. Test environment setup
2. Test cases with step-by-step instructions
3. Expected results
4. UI/UX verification checklist
5. Exploratory testing suggestions
6. Known limitations
"
```

**After Agent Returns:**
1. Review manual testing guide
2. Present guide to user

**No Decision Gate** - Informational output

Continue to Phase 8.

## Phase 8: Quality Review

**Update Todo:** Mark manual guide complete, start quality review

**Launch Multiple Agents in Parallel:**

Use pr-review-toolkit agents for comprehensive quality review.

**Agent 1: code-reviewer**
```
Use Task tool with subagent_type="pr-review-toolkit:code-reviewer"

Prompt:
"Review code changes for quality, style, and project convention compliance:

Files changed:
[git diff output]

Focus on:
- Code quality issues
- Project convention violations (from PROJECT_CONTEXT)
- Style guide compliance
- Potential bugs
- Security issues

Report only issues with confidence >= 80
"
```

**Agent 2: pr-test-analyzer**
```
Use Task tool with subagent_type="pr-review-toolkit:pr-test-analyzer"

Prompt:
"Review test coverage and quality:

Test files:
[Test files from Phase 5]

Focus on:
- Coverage completeness
- Test quality
- Missing edge cases
- Test maintainability
"
```

**Agent 3: silent-failure-hunter**
```
Use Task tool with subagent_type="pr-review-toolkit:silent-failure-hunter"

Prompt:
"Review error handling:

Files changed:
[git diff output]

Focus on:
- Silent failures
- Inadequate error handling
- Inappropriate fallback behavior
"
```

**After All Agents Return:**
1. Consolidate results from all three agents
2. Present comprehensive quality report
3. **DECISION GATE:** Ask user if issues need addressing

**User Decision Required:**
```
Quality Review Results:

Critical Issues: [count]
[List issues]

Important Issues: [count]
[List issues]

Suggestions: [count]
[List suggestions]

Do you want to address these issues before proceeding?
[Yes - fix issues/No - continue/Select specific issues]
```

If Yes: Fix issues and re-run review
If No: Continue to Phase 9

## Phase 9: Knowledge Base Update

**Update Todo:** Mark quality review complete, start Knowledge Base update

**Launch Agent:**
```
Use Task tool with subagent_type="knowledge-base-updater"

Prompt:
"Propose Knowledge Base updates for this implementation:

Implementation Summary:
- Requirements: [from Phase 1]
- Architecture: [from Phase 2]
- Code changes: [from Phase 3]
- Tests: [from Phase 5]
- Key decisions: [from all phases]

Project Context (from scanner):
[INSERT PROJECT_CONTEXT here]

Use the knowledge base paths discovered by the scanner. Read the current state of those files before proposing changes.

Propose updates to the relevant knowledge base files:
1. Active context - Current focus and recent changes
2. Progress - Major achievements
3. Feature history - Feature implementation history
4. Common patterns - New patterns discovered
5. Session summaries - If session ending

Present updates in clear diff format with rationale.
"
```

**After Agent Returns:**
1. Review proposed Knowledge Base updates
2. Present diffs to user
3. **DECISION GATE:** Ask user to approve updates

**User Approval Required:**
```
Proposed Knowledge Base Updates:

Files to Update:
1. [file] - [summary of changes]
2. [file] - [summary of changes]
3. [file] - [summary of changes]

[Show diffs]

Do you approve these Knowledge Base updates?
[Yes - apply updates/No - skip/Modify specific files]
```

If Yes: Apply updates using Edit/Write tools
If No: Skip updates

Continue to Phase 10.

## Phase 10: Deployment Readiness

**Update Todo:** Mark Knowledge Base complete, deployment readiness

**Present Final Summary:**
```
Development Complete: [Feature Name]

## Summary
[2-3 sentence overview]

## What Was Built
- [Key feature 1]
- [Key feature 2]
- [Key feature 3]

## Files Changed
Created:
- [file 1]
- [file 2]

Modified:
- [file 3]
- [file 4]

## Tests
- Unit tests: X passing
- Request specs: Y passing
- Integration tests: Z passing (if any)
- Total: N tests passing

## Quality Review
- Code review passed (or: N issues addressed)
- Test coverage adequate
- Error handling verified

## Knowledge Base
- Documentation updated (or: Updates skipped)

## Manual Testing Guide
- Comprehensive QA guide provided

## Deployment Checklist
- [ ] All automated tests passing
- [ ] Manual testing completed
- [ ] Code reviewed and approved
- [ ] Knowledge Base updated
- [ ] Ready for commit

## Next Steps
1. Review manual testing guide and perform QA
2. Create git commit when ready
3. Create pull request (manually)
4. Deploy following project procedures

Feature is production-ready!
```

**Mark All Todos Complete**

Workflow complete!

## Important Guidelines

- **One phase at a time** - Don't skip ahead
- **Use TodoWrite** - Track progress visibly
- **Decision gates** - Wait for user approval at 7 gates
- **Clear communication** - Summarize each phase
- **Agent coordination** - Launch agents with clear prompts
- **Context preservation** - Pass information between phases
- **Iterate when needed** - Test execution may need multiple rounds
- **Quality focus** - Don't rush through phases
- **User control** - User decides at every gate

## Error Handling

If any phase fails:
1. Present the error clearly
2. Suggest fixes or ask for guidance
3. Allow user to retry, modify, or skip phase
4. Don't proceed without resolution

## Context Between Phases

Preserve context from each phase:
- Phase 1 requirements -> All subsequent phases
- Phase 2 architecture -> Phase 3 implementation
- Phase 3 code -> Phases 4-9
- All phases -> Phase 9 Knowledge Base update

Store in variables or re-reference as needed.

Remember: You're orchestrating a comprehensive workflow. Each agent is a specialist. Your job is to coordinate them smoothly, communicate clearly with the user, and deliver production-ready code through this systematic process.
