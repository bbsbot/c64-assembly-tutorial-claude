# Skill: Implementation Workflow

## Purpose
Prevents common mistakes when starting new features or implementing plans. This skill ensures proper documentation, git hygiene, and incremental progress tracking.

## The Cardinal Rule
**NEVER start coding immediately when given a plan or feature request.**

---

## Pre-Implementation Checklist

When the user provides a plan (inline, attached, or via plan mode), follow these steps **in order**:

### 1. ✅ Save the Plan Document

**If plan is provided inline:**
```bash
# Save to docs/PLAN_<feature-name>.md
Write the complete plan to docs/PLAN_<feature-name>.md
```

**If plan references a previous session:**
```bash
# Verify the plan file exists
Read docs/PLAN_<feature-name>.md
# If missing: STOP and ask user for the plan
```

**Plan must include:**
- Feature description and context
- Implementation phases
- Files to be modified/created
- Testing criteria
- Success criteria

### 2. ✅ Create Feature Branch

**NEVER work on main branch for new features.**

```bash
# Check current branch
git branch
# If on main, create feature branch
git checkout -b feature/<feature-name>
# Verify you're on the feature branch
git branch
```

**Branch naming conventions:**
- `feature/<name>` - new functionality
- `bugfix/<name>` - fixing a bug
- `refactor/<name>` - code restructuring
- `docs/<name>` - documentation only

### 3. ✅ Baseline Verification

Before making ANY changes:

```bash
# Assemble current code
java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile

# Verify 0 errors
# Expected: "Made N asserts, 0 failed"

# Check git status
git status
# Expected: "nothing to commit, working tree clean"
```

**If baseline fails:** Fix existing issues before starting new work.

### 4. ✅ NOW You Can Code

Implement in **small, testable phases**:
- Phase 1: Foundation (data structures, constants)
- Phase 2: Core logic
- Phase 3: UI integration
- Phase 4+: Polish, testing, optimization

**After each phase:**
1. Assemble and verify
2. Test manually (if VICE available)
3. Commit with descriptive message
4. Update plan document with status

---

## Commit Message Format

```
<TYPE>: <Short description (max 50 chars)>

<Detailed explanation of what changed and why>

Changes:
- file1.asm: <what changed>
- file2.asm: <what changed>

Testing:
- <how you verified it works>

Relates to: docs/PLAN_<feature-name>.md
Phase: <N> of <Total>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Types:**
- `FEAT` - new feature
- `FIX` - bug fix
- `REFACTOR` - code restructuring (no behavior change)
- `DOCS` - documentation only
- `TEST` - test additions/changes
- `CHORE` - tooling, build, dependencies

---

## Red Flags - STOP Immediately If:

❌ **User gives you a plan, you start coding without saving it**
→ Stop. Save the plan first.

❌ **`git branch` shows you're on `main`**
→ Stop. Create feature branch.

❌ **You're modifying files without a plan document**
→ Stop. Create or locate the plan.

❌ **You "reference" a plan file that doesn't exist**
→ Stop. You're hallucinating. Save the real plan.

❌ **You modified 5+ files without committing**
→ Stop. Commit smaller increments.

❌ **Assembly fails after your changes**
→ Stop. Fix errors before proceeding.

---

## Example Workflow

**User says:** "Implement the following plan: [long plan]"

**Correct response:**
1. Write plan to `docs/PLAN_feature_name.md`
2. `git checkout -b feature/feature-name`
3. Verify baseline assembles
4. Implement Phase 1 only
5. Assemble and verify
6. Commit Phase 1
7. Report progress, ask to continue

**Incorrect response:**
1. ❌ Start editing constants.asm immediately
2. ❌ Make changes across 5 files
3. ❌ Work on main branch
4. ❌ No plan document saved

---

## Recovery from Mistakes

**If you realize you started coding without saving the plan:**
1. STOP immediately
2. `git stash` (save your work)
3. Save the plan document
4. Create feature branch
5. `git stash pop` (restore your work)
6. Commit properly

**If you realize you're on main branch:**
1. STOP immediately
2. `git stash` (if you have changes)
3. `git checkout -b feature/<name>`
4. `git stash pop`
5. Commit to feature branch

---

## Integration with Session Management

From `skills/session-management/SKILL.md`:
- Save plan document: **1 tool call** (Write)
- Create branch + verify: **2 tool calls** (Bash)
- Baseline check: **1 tool call** (Bash)

**Total overhead: ~4 tool calls** - well worth it to avoid disasters.

---

## When to Skip This Workflow

**You MAY skip this checklist for:**
- Trivial typo fixes (1-line changes)
- Documentation updates only
- User explicitly says "quick fix, stay on main"

**You MUST use this checklist for:**
- Any multi-file feature
- New functionality
- Refactoring
- Anything with a plan document

---

## Success Criteria

This workflow is working if:
- ✅ Every feature has a plan document committed before code changes
- ✅ `main` branch stays stable and clean
- ✅ Feature branches are properly named
- ✅ Commits are small, tested, and descriptive
- ✅ User doesn't have to "yell" to get you to follow process

---

## Notes for Claude

- This skill exists because of a critical incident where a plan was provided inline, but not saved, and work began on main branch
- The user's trust depends on consistent process adherence
- When in doubt, ask: "Should I save this as a plan document first?"
- "Move fast and break things" is NOT the C64 way - we value correctness and process
