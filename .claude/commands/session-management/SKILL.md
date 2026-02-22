# Session Management Skill v1.0

This skill provides session-aware pacing and resource management for AI coding agents. Follow all instructions below throughout your entire working session.

---

## 1. Session Budget Awareness

You are operating under a finite session budget. Track your resource usage throughout the session.

### Default Budget Parameters
- **Budget Window:** 300 minutes (5 hours)
- **Estimated Max Tool Calls:** 80 per window
- **Estimated Max Tokens:** 200,000 per window

Override these defaults if a `config/session-defaults.yaml` file is present.

### Budget Tracking
After every tool call, mentally increment your internal call counter. After every milestone (completing a file, module, test suite, or logical unit of work), report your status:

```
📊 Checkpoint: ~[N] tool calls used | Budget: [ZONE] | Sprint [X] of session
```

### Budget Zones

| Zone     | Usage   | Color  | Behavior                                    |
|----------|---------|--------|---------------------------------------------|
| GREEN    | 0-50%   | 🟢     | Full speed. All operations permitted.        |
| YELLOW   | 50-75%  | 🟡     | Conserve. Batch operations, skip optional.   |
| RED      | 75-90%  | 🔴     | Planning only. Outlines, TODOs, docs.        |
| CRITICAL | 90-100% | ⛔     | Stop. Write final status and halt all work.  |

---

## 2. Work Cadence — Pomodoro Mode

Structure all work into sprint cycles to prevent budget burnout.

### Sprint Cycle
1. **SPRINT** — Work for up to 20 tool calls or ~15 minutes of activity
2. **CHECKPOINT** — Summarize progress, update tracking docs, estimate budget zone
3. **REST** — Execute synchronous sleep for 5 minutes (see Sleep Commands below)
4. **REPEAT** — Begin next sprint

After **4 consecutive sprints**, take an **extended rest of 15 minutes**.

### Sleep Commands

**Windows (Git Bash):**
```bash
bash scripts/session-timer.sh 5
```

**Linux/macOS:**
```bash
echo "Resting until $(date -d '+5 minutes' '+%H:%M:%S')..." && sleep 300 && echo "Resuming."
```

### Pre-Sprint Checklist
Before starting each sprint, confirm:
- [ ] What is the specific goal for this sprint?
- [ ] What is my current budget zone?
- [ ] Am I continuing previous work or starting something new?
- [ ] Are there any pending rate limit issues?

---

## 3. Rate Limit Detection and Response

Monitor for signs of rate limiting or resource exhaustion.

### Detection Signals
- HTTP 429 (Too Many Requests) or 529 (Overloaded) status codes
- API errors mentioning "rate limit", "capacity", "quota", or "throttle"
- Unusually slow responses (>30 seconds for simple operations)
- Repeated failures on the same operation (3+ consecutive failures)

### Response Protocol

| Attempt | Wait Time | Next Action              |
|---------|-----------|--------------------------|
| 1st     | 5 min     | Retry once               |
| 2nd     | 10 min    | Retry with reduced scope |
| 3rd     | 30 min    | Status report + resume   |
| 4th+    | 60 min    | Enter CRITICAL zone      |

---

## 4. Budget Conservation Strategies

### GREEN Zone (0-50% used)
- Full operations: read, write, edit, test, refactor
- Multi-file changes permitted, exploratory work allowed

### YELLOW Zone (50-75% used)
- Batch file reads, skip optional improvements
- Prefer editing over rewriting, combine related changes
- Reduce sprint size to 15 tool calls

### RED Zone (75-90% used)
- **Planning only** — no file edits
- Write outlines, TODOs, update PROGRESS.md with next steps

### CRITICAL Zone (90-100% used)
- **Stop all work immediately**
- Write final status to PROGRESS.md: completed, in-progress, remaining, blockers

### Always
- Complete the current atomic unit before entering a lower zone
- Never leave files in a broken or half-edited state
- Commit or save before resting

---

## 5. Session Logging

Write entries to `SESSION_LOG.md`:

```
## [TIMESTAMP] — [EVENT_TYPE]
- **Sprint:** [N]
- **Tool Calls:** [count] / [budget]
- **Zone:** [GREEN|YELLOW|RED|CRITICAL]
- **Event:** [description]
- **Files Touched:** [list]
```

Event types: `SESSION_START`, `SPRINT_COMPLETE`, `REST_START`, `REST_END`, `RATE_LIMIT`, `ZONE_CHANGE`, `SESSION_END`

---

## 6. Claude Code Integration

- This skill is loaded via the `.claude/commands/session-management/SKILL.md` entry in CLAUDE.md
- Sleep/rest uses `bash scripts/session-timer.sh N`
- After every ~20 tool calls, output a checkpoint line before continuing
- In this project, a "sprint" maps well to one Phase of the Block Tutor implementation plan
