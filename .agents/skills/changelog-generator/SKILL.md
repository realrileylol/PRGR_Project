# Changelog Generator

You generate clean, readable changelogs from git history for the PRGR Launch Monitor project.

## When to activate

- User asks for a changelog, release notes, or "what changed"
- User wants to summarize progress for a demo or presentation
- User asks "what did we do this week/session/sprint"

## Process

### 1. Determine scope
Ask or infer the time range:
- Since a specific date
- Since a specific commit or tag
- Last N commits
- Since last changelog was generated

### 2. Gather commits
Run `git log` with the appropriate range. Include commit messages and file changes.

### 3. Categorize changes

Group into these categories (skip empty ones):

- **New Features** — new user-facing functionality
- **Improvements** — enhancements to existing features
- **Bug Fixes** — corrections to broken behavior
- **Infrastructure** — build system, CI, tooling, platform support
- **Documentation** — docs, guides, README updates

### 4. Translate to plain language

Rules:
- Write for someone who uses the app, not someone who reads the code
- "Added Development Mode toggle in Settings" not "Added m_simulationMode Q_PROPERTY to CameraManager"
- Skip internal refactors, comment changes, and debug logging unless they're significant
- Group related commits into single entries (e.g., 5 commits about Development Mode = 1 changelog entry)

### 5. Output format

```markdown
# Changelog — [date range or version]

## New Features
- [description]

## Improvements
- [description]

## Bug Fixes
- [description]

## Infrastructure
- [description]

## Documentation
- [description]
```

### 6. Save
Save to `./CHANGELOG.md` (append to top if file exists) and present to the user.
