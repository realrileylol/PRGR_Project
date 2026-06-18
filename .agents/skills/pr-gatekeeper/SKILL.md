# PR Gatekeeper

Reviews pull requests against PRGR Launch Monitor repository standards and outputs a structured PASS/FAIL verdict with specific findings.

## When to Use

Invoke this skill when a pull request needs review before merge, or when the user asks to check whether a branch or set of changes meets project standards.

## Review Checklist

### 1. Single-Feature Scope

- The PR must address exactly one feature, fix, or concern.
- Flag any unrelated changes (drive-by refactors, formatting-only diffs in unrelated files, bundled features).
- Exception: trivial adjacent cleanup (e.g., fixing a typo on an adjacent line) is acceptable if noted.

### 2. Conventional Commit Title

The PR title (and ideally each commit message) must follow:

```
type(scope): description
```

Where `type` is one of: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`.

Examples of valid titles:
- `feat(radar): add OPS243-A rolling buffer capture`
- `fix(camera): correct portrait rotation for Camera 0`
- `refactor(calibration): extract ArUco detection into helper`
- `chore(build): update CMakeLists for Qt 6.6`

Flag titles that are vague (`update stuff`), missing the type prefix, or missing the scope.

### 3. Test Coverage

- **Logic changes in C++**: Must have corresponding automated tests (unit or integration). If no test framework is wired up yet, the PR must document exactly how the change was manually tested (steps, expected output, actual output).
- **Python radar driver changes**: Must have pytest coverage. Run `pytest` in the relevant directory and confirm tests pass.
- **QML-only changes**: Manual testing is acceptable, but the PR description must document what was tested and on what display resolution.

### 4. C++ Build Verification

- C++ changes must compile on the Raspberry Pi 5 target (aarch64, CMake, Qt 6, OpenCV 4).
- If a Windows dev-mode build configuration exists, changes must also pass that build.
- Check for: missing `#include` directives, use of platform-specific APIs without `#ifdef` guards, C++17 compliance.

### 5. Python Radar Driver Changes

- Must have pytest coverage for any new or modified functions.
- Confirm no hardcoded serial port paths (should use config or CLI args).
- Check baud rate constants match hardware specs (38400 for K-LD2, 3000000 for K-LD7, 115200 for OPS243-A unless configured otherwise).

### 6. QML / UI Changes

- Layout must be verified at 800x480 (the Pi's target display resolution).
- All touch targets must be >= 48x48 pixels.
- Check that any new `Q_PROPERTY` bindings have matching `NOTIFY` signals (silent binding failure otherwise).
- Camera 0 display must account for 90-degree CW rotation (portrait mode, 480x640).

### 7. Secrets and Paths

- No secrets, API keys, credentials, or tokens committed.
- No hardcoded absolute file paths (e.g., `/home/pi/...`). Use relative paths or configuration.
- No committed `.env` files, `credentials.json`, or similar.

### 8. Documentation

- If the PR changes a public API (new Q_INVOKABLE methods, new QML properties, new CLI flags, new Python module interfaces), the corresponding documentation must be updated.
- Changes to `HardcodedConstants.h` require explicit user approval (physical world values) -- flag these prominently.

## Procedure

1. Read the PR diff (all changed files).
2. Read the PR title and description.
3. Walk through each checklist item above, noting specific findings.
4. For each finding, classify as:
   - **PASS**: Requirement met.
   - **FAIL**: Requirement violated -- cite the specific file, line, and reason.
   - **WARN**: Not a hard failure but worth noting (e.g., missing test for a trivial change).
   - **N/A**: Requirement does not apply to this PR.
5. Produce a final verdict: **PASS** (all items pass or N/A), **FAIL** (any item fails), or **CONDITIONAL PASS** (only warnings, no failures).

## Output Format

```
## PR Gatekeeper Review

**PR**: <title>
**Verdict**: PASS | FAIL | CONDITIONAL PASS

### Findings

| # | Check                  | Result | Details                        |
|---|------------------------|--------|--------------------------------|
| 1 | Single-feature scope   | PASS   |                                |
| 2 | Conventional title     | FAIL   | Missing type prefix            |
| 3 | Test coverage          | WARN   | No automated tests, manual OK  |
| 4 | C++ build              | N/A    | No C++ changes                 |
| 5 | Python tests           | PASS   |                                |
| 6 | QML / UI               | N/A    | No QML changes                 |
| 7 | Secrets / paths        | PASS   |                                |
| 8 | Documentation          | PASS   |                                |

### Details

<expanded explanation for any FAIL or WARN items, with file paths and line numbers>
```
