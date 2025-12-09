# LLM Agent Guidelines - yrmpc

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Updated**: 2025-12-10  
**Status**: ✅ Core Playable - Daily Use

---

## 🚀 Quick Start

```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```

---

## 📋 Task Management (backlog.md CLI)

> ⚠️ **CRITICAL**: This project uses `backlog` CLI for task management. **Do NOT edit task files directly.**

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

## 📖 Documentation Index

| Purpose | File |
|---------|------|
| **This file** | Entry point for LLM agents |
| Task management | [BACKLOG_INSTRUCTIONS.md](BACKLOG_INSTRUCTIONS.md) |
| Project overview | [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| UI/UX spec | [docs/ui-ux-provised.md](docs/ui-ux-provised.md) |
| Rich List UI | [docs/ADR-rich-list-ui.md](docs/ADR-rich-list-ui.md) |
| YouTube API | [docs/YOUTUBE_API.md](docs/YOUTUBE_API.md) |
| Current status | [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) |

---

## 🎯 Current State

| Feature | Status |
|---------|--------|
| Search (all types) | ✅ |
| Playback (MPV) | ✅ |
| Queue management | ✅ |
| MPRIS integration | ✅ |
| Daemon mode | ✅ |
| Rich List UI | ✅ |

---

## 📁 Key Files

| Purpose | Path |
|---------|------|
| YouTube API | `rmpc/src/player/youtube/api.rs` |
| Protocol | `rmpc/src/player/youtube/protocol.rs` |
| Rich List Widget | `rmpc/src/ui/widgets/item_list.rs` |
| Display Trait | `rmpc/src/domain/display.rs` |
| Search Pane | `rmpc/src/ui/panes/search/mod.rs` |
| Queue Pane | `rmpc/src/ui/panes/queue.rs` |

---

## ⚡ Session Workflow

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

## 🧠 Guidelines

- **Think first**: Use sequential thinking for complex problems
- **Research before fixing**: Find root cause, don't guess
- **TDD when possible**: Tests prove correctness
- **Ask questions**: Clarify assumptions with user
- **Document changes**: Update session context files

---

## ⚠️ Critical Rules

### NEVER
- Edit backlog task files directly (use CLI only)
- Download entire playlists (stream only)
- Break vim-style keyboard navigation

### ALWAYS
- Use `--plain` flag when viewing backlog tasks
- Test with real YouTube content
- Update task AC as you complete them
- Keep user informed of blockers
