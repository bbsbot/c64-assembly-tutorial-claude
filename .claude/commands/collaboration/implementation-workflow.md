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
1. Run static testing (see below)
2. Stage changes: `git add <files>`
3. Commit with descriptive message
4. Update plan document with status

---

## Static Testing (Required After Each Phase)

**Run these checks BEFORE committing:**

**IMPORTANT:** Save test output to `tmp/` for user review:
- `tmp/` is gitignored - ephemeral output only
- Summaries, reports, test logs go here
- User can review detailed output after conversation ends
- **ALWAYS use timestamped filenames**: `tmp/static-test-phase2-$(date +%Y%m%d-%H%M%S).txt`
- **NEVER overwrite previous reports** - timestamps prevent this

**CRITICAL - Minimize Permission Prompts:**
- Running 7 separate bash commands = 7 permission prompts = ANNOYING
- Solution: Write entire test as ONE bash script, execute ONCE
- Pattern: Create `tmp/run-static-tests.sh`, chmod +x, run once
- OR: Generate entire report in single heredoc, write once
- Goal: 1 test run = 1-2 permission prompts MAX (not 7+)

```bash
# 1. Clean build from scratch
rm -f build/main.prg build/main.sym
java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile

# 2. Verify assembly succeeded
# Expected output:
#   "Writing prg file: .../build/main.prg"
#   "Made N asserts, 0 failed"
#
# If any asserts fail: STOP, fix the issue

# 3. Move symbol file to build directory
mv src/main.sym build/main.sym

# 4. Check output files exist and are reasonable size
ls -lh build/
# Verify:
#   - main.prg exists and is >10K (not suspiciously small)
#   - main.sym exists

# 5. Verify memory constraints (check assembler output)
# Look for lines like:
#   "Codegen segment fits=true (true)"
#   "AsmView segment fits=true (true)"
# If any segment shows "false": STOP, you exceeded memory limits

# 6. Quick syntax/style check
# - No tabs in source files (KickAss prefers spaces)
# - All functions have comment headers
# - No hardcoded magic numbers (use constants)

# 7. Git sanity check
git status
# Verify:
#   - You're on a feature branch (not main)
#   - Only expected files are modified
#   - No accidentally staged binaries or temp files
```

**Pass Criteria:**
- ✅ Assembly completes with "0 failed"
- ✅ All segment fit checks are "true"
- ✅ main.prg exists and is reasonable size
- ✅ No unexpected files modified

**If ANY check fails:** Fix before committing.

**After all checks pass:** Write summary to timestamped file in tmp/

---

## How to Run Static Tests (Minimize Permission Prompts)

**❌ WRONG WAY (7+ permission prompts):**
```bash
# DON'T DO THIS - each echo/cat triggers a prompt
echo "Test 1" >> tmp/report.txt
run_test_1 >> tmp/report.txt
echo "Test 2" >> tmp/report.txt
run_test_2 >> tmp/report.txt
# ... 7 more times = 14+ prompts!
```

**✅ RIGHT WAY - Method 1: Single Test Script (2 prompts)**
```bash
# Prompt 1: Write the test script
cat > tmp/run-static-tests.sh <<'SCRIPT'
#!/bin/bash
REPORT="tmp/static-test-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "=== STATIC TEST REPORT ==="
  echo "Timestamp: $(date)"
  echo ""

  # Test 1: Clean build
  echo "[1/7] Clean build..."
  rm -f build/main.prg build/main.sym
  java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile 2>&1 | tail -5
  echo "Result: PASS"
  echo ""

  # Test 2-7: ... all tests here ...

  echo "=== SUMMARY: 7/7 PASSED ==="
} > "$REPORT"
echo "Report saved: $REPORT"
SCRIPT

chmod +x tmp/run-static-tests.sh

# Prompt 2: Run the script
bash tmp/run-static-tests.sh
```

**✅ RIGHT WAY - Method 2: Direct Script Execution (1 prompt)**
```bash
# Single bash call that does EVERYTHING
bash -c '
REPORT="tmp/static-test-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "=== STATIC TEST REPORT ==="
  echo "Test 1: Clean build..."
  rm -f build/*.prg build/*.sym
  java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile 2>&1 | tail -5

  echo "Test 2: Move symbols..."
  mv src/main.sym build/main.sym

  # ... all 7 tests inline ...

  echo "=== 7/7 PASSED ==="
} | tee "$REPORT"
echo ""
echo "Full report: $REPORT"
'
```

**Key Principles:**
- Combine all tests into ONE bash invocation
- Use `tee` to show output AND save to file
- Timestamp the filename automatically
- User sees summary, can review full report later
- **1 permission prompt instead of 7+**

---

## Output File Structure

Example: `tmp/static-test-phase2-20260221-113045.txt`

Contents:
```
=== STATIC TEST REPORT - Phase N ===
Timestamp: 2026-02-21 11:30:45
Branch: feature/assembly-view-toggle

[1/7] Clean build................ ✅ PASS
[2/7] Assert validation.......... ✅ PASS (0 failed)
[3/7] Symbol file................ ✅ PASS
[4/7] Output files............... ✅ PASS (26KB)
[5/7] Memory constraints......... ✅ PASS (10/10 segments)
[6/7] Code style................. ✅ PASS
[7/7] Git sanity................. ✅ PASS

=== SUMMARY: 7/7 PASSED ===

[Full build output]
... assembler output ...

[Next Steps]
- Continue to Phase 3
- Integration test when VICE available
```

---

## Test Output Best Practices

**DO save to tmp/:**
- ✅ Static test reports (timestamped!)
- ✅ Build logs (full assembler output)
- ✅ Memory maps / segment layouts
- ✅ Performance measurements
- ✅ Debug traces

**DON'T save to tmp/:**
- ❌ Source code or patches
- ❌ Binary files (.prg, .d64)
- ❌ Permanent documentation
- ❌ Anything that should be versioned

**Filename Requirements:**
- ✅ ALWAYS timestamp: `static-test-YYYYMMDD-HHMMSS.txt`
- ✅ Descriptive prefix: `static-test-phase2-...`, `build-log-...`, `memory-map-...`
- ❌ NEVER generic: `test.txt`, `output.txt`, `report.txt`
- ❌ NEVER overwrite previous reports

**When to create reports:**
- After completing each phase
- After fixing a bug (before/after comparison)
- When user asks "did it work?" or "show me the results"
- Before committing (proves testing was done)

**How many permission prompts:**
- Target: 1-2 prompts for entire test suite
- Actual: Use single bash script or inline heredoc
- Avoid: Multiple bash calls (7+ prompts = annoying!)

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

## Auto-Approved Operations (User Permissions)

**Tier 1: Read-Only (Always Auto-Approved)**
- `ls`, `pwd`, `cd`, `find`, `file`, `stat`, `git status`, `git log`, `git diff`, `git branch`
- `Read`, `Glob`, `Grep` tools
- `java -jar bin/KickAss.jar` (assembly - creates build artifacts only)

**Tier 2: Safe Development (Auto-Approved on Feature Branches)**
- `git checkout -b feature/*` (create feature branches)
- `git add <specific files>` (staging changes)
- `git commit` (local commits)
- `git stash` / `git stash pop`
- `mkdir -p build`, `mkdir -p bin`
- `mv src/*.sym build/*.sym` (moving build artifacts)
- `Edit` to `src/*.asm` (code changes)
- `Write` to `docs/PLAN_*.md`, `build/*`

**Always Ask First:**
- `git checkout main`, `git merge`, `git push`
- `rm -rf`, `git reset --hard`, `git clean -f`
- Destructive operations

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
