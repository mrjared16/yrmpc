# LLM Agent Guidelines - yrmpc

**Project**: YouTube Music TUI Client (Rust + Ratatui)
**Updated**: 2025-12-27
**Status**: Core Playable - Daily Use

---

## Quick Start

```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```

---

## Architecture Overview

**Navigator** is the central UI controller (when `legacy_panes.enabled=false`).

**Layered Architecture**:
```
InteractiveListView -> SectionList -> ContentView -> Panes -> Navigator
```

**Feature Flag**: `legacy_panes.enabled` in config controls old vs new architecture.

**Backend**:
- `BackendDispatcher` routes commands to active backend
- Traits: `api::Playback`, `api::Queue`, `api::Discovery`
- `MusicBackend` trait is deprecated

---

## Task Management (backlog.md CLI)

> **CRITICAL**: This project uses `backlog` CLI for task management. **Do NOT edit task files directly.**

### View Tasks
```bash
backlog task list --plain           # List all tasks
backlog task 1 --plain              # View specific task
backlog search "queue" --plain      # Search tasks
```

### Work on a Task
```bash
# 1. Assign and start
backlog task edit <id> -s "In Progress" -a @agent

# 2. Add implementation plan
backlog task edit <id> --plan "1. Research\n2. Implement\n3. Test"

# 3. After coding, mark AC complete
backlog task edit <id> --check-ac 1 --check-ac 2

# 4. Add notes and complete
backlog task edit <id> --notes "Implemented X"
backlog task edit <id> -s Done
```

> **Full guide**: [BACKLOG_INSTRUCTIONS.md](BACKLOG_INSTRUCTIONS.md)

---

## Documentation Index

| Purpose | File |
|---------|------|
| **This file** | Entry point for LLM agents |
| **Project vision** | [docs/VISION.md](docs/VISION.md) |
| **User workflow guide** | [docs/USER_GUIDE.md](docs/USER_GUIDE.md) |
| **Backend refactor** | [docs/ADR-backend-refactor.md](docs/ADR-backend-refactor.md) |
| Task management | [BACKLOG_INSTRUCTIONS.md](BACKLOG_INSTRUCTIONS.md) |
| Project overview | [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| UI/UX spec | [docs/ui-ux-provised.md](docs/ui-ux-provised.md) |
| Rich List UI | [docs/ADR-rich-list-ui.md](docs/ADR-rich-list-ui.md) |
| YouTube API | [docs/YOUTUBE_API.md](docs/YOUTUBE_API.md) |
| Current status | [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) |

---

## Current State

| Feature | Status |
|---------|--------|
| Search (all types) | Done |
| Playback (MPV) | Done |
| Queue management | Done |
| Auto-advance | Done |
| Repeat (One/All) | Done |
| Shuffle | Done |
| MPRIS integration | Done |
| Daemon mode | Done |
| Rich List UI | Done |
| Navigator architecture | Done |

---

## Key Files

| Purpose | Path |
|---------|------|
| **Navigator (UI Controller)** | `rmpc/src/ui/panes/navigator.rs` |
| **Navigation Types** | `rmpc/src/ui/panes/navigator_types.rs` |
| **Backend Dispatcher** | `rmpc/src/backends/dispatcher.rs` |
| **Backend API Traits** | `rmpc/src/backends/api.rs` |
| Search Pane (V2) | `rmpc/src/ui/panes/search_pane_v2.rs` |
| Queue Pane (V2) | `rmpc/src/ui/panes/queue_pane_v2.rs` |
| Content View | `rmpc/src/ui/widgets/content_view.rs` |
| Rich List Widget | `rmpc/src/ui/widgets/item_list.rs` |
| YouTube API | `rmpc/src/backends/youtube/api.rs` |
| YouTube Protocol | `rmpc/src/backends/youtube/protocol.rs` |
| MPD Backend | `rmpc/src/backends/mpd/backend.rs` |
| Display Trait | `rmpc/src/domain/display.rs` |

### Backend Architecture (Updated 2025-12-27)
```
src/backends/
├── dispatcher.rs      # BackendDispatcher routes to active backend
├── api.rs             # Playback, Queue, Discovery traits
├── mpd/               # MPD backend + protocol/
├── mpv/               # Standalone MPV player
└── youtube/           # YouTube daemon (client, server, services)
```
See [docs/ADR-backend-refactor.md](docs/ADR-backend-refactor.md) for details.

---

## Session Workflow

### Starting a Session

1. **Check backlog**: `backlog task list --plain`
2. **Pick a task** or discuss with user
3. **Claim it**: `backlog task edit <id> -s "In Progress" -a @agent`
4. **Add plan**: `backlog task edit <id> --plan "..."`
5. **Get approval** before coding

### During Implementation

- Update AC as you complete: `backlog task edit <id> --check-ac 1`
- Append notes: `backlog task edit <id> --append-notes "Progress..."`

### Finishing

1. Check all AC: `backlog task <id> --plain`
2. Add final notes
3. Mark done: `backlog task edit <id> -s Done`

---

## Guidelines

- **Read vision first**: Understand project goals in [docs/VISION.md](docs/VISION.md)
- **Know user workflow**: Study [docs/USER_GUIDE.md](docs/USER_GUIDE.md) for daily usage patterns
- **Think first**: Use sequential thinking for complex problems
- **Research before fixing**: Find root cause, don't guess
- **TDD when possible**: Tests prove correctness
- **Ask questions**: Clarify assumptions with user
- **Document changes**: Update session context files
- **Expert thinking**: 
```
Think harder. Critique before responding.

You're a principal engineer (10+ yrs production streaming). Apply SOLID, prioritize maintainability, refactor proactively when spotting better designs.

**Each phase**: "Best approach? What breaks at scale?"  
**Show reasoning** when pivoting from initial solution.
```


---

## Critical Rules

### NEVER
- Edit backlog task files directly (use CLI only)
- Download entire playlists (stream only)
- Break vim-style keyboard navigation

### ALWAYS
- Use `--plain` flag when viewing backlog tasks
- Test with real YouTube content
- Update task AC as you complete them
- Keep user informed of blockers
- Read VISION.md and USER_GUIDE.md before starting any task
