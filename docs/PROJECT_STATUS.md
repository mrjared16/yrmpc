# Project Status

**Last Updated**: 2025-12-27
**Status**: Core Playable - Daily Use Ready

---

## Architecture Status

| Component | Status | Notes |
|-----------|--------|-------|
| **Navigator** | ✅ Complete | Central UI controller, pane routing |
| **ContentView** | ✅ Complete | Stack management for drilling |
| **InteractiveListView** | ✅ Complete | Selection, marks, find mode |
| **BackendDispatcher** | ✅ Complete | Routes to MPD/YouTube |
| **api::Playback/Queue/Discovery** | ✅ Complete | SOLID trait segregation |
| Legacy Panes | ⚠️ Deprecated | Still available via config flag |

---

## Feature Status

| Feature | Status |
|---------|--------|
| Search (all types) | ✅ Complete |
| Playback (MPV) | ✅ Complete |
| Queue management | ✅ Complete |
| Auto-advance | ✅ Complete |
| Repeat (Off/One/All) | ✅ Complete |
| Shuffle (with history) | ✅ Complete |
| MPRIS integration | ✅ Complete |
| Daemon mode | ✅ Complete |
| Rich List UI | ✅ Complete |
| Navigator architecture | ✅ Complete |
| Artist Detail View | 📋 Planned (task-4) |
| Album Detail View | 📋 Planned (task-4) |
| Now Playing View | 📋 Planned (task-7) |
| Grid Layout | 📋 Planned (task-10) |

---

## Backlog Summary

| Status | Count |
|--------|-------|
| **Done** | 27 |
| **To Do** | 7 |
| **In Progress** | 0 |

### Remaining Tasks

| ID | Priority | Title |
|----|----------|-------|
| task-4 | HIGH | Artist Album Detail View |
| task-7 | MEDIUM | Now Playing View |
| task-10 | LOW | Grid View Implementation |
| task-medium.1 | MEDIUM | Toggleable Saved Playlists Sidebar |
| task-medium.2 | MEDIUM | PlaylistItemOps Trait |
| task-low.1 | LOW | Pane-Local Config for Column Widths |
| task-high.3 | HIGH | Fix QueueModal Interaction Bugs |

---

## Quick Commands

```bash
# Build and run
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron

# Check backlog
backlog task list --plain

# Run tests
cd rmpc && cargo test --lib
```

---

## Recent Milestones

| Date | Milestone |
|------|-----------|
| Dec 27 | Navigator integration complete, docs synced |
| Dec 23 | Backend refactor complete (api traits) |
| Dec 22 | File reorganization (src/backends/) |
| Dec 21 | Extractor refactor (composable traits) |
| Dec 17 | CPU fix (0% idle), search fix |
| Dec 16 | Hybrid queue, repeat/shuffle modes |
| Dec 14 | MPV as source of truth redesign |

---

## Documentation

See [CLAUDE.md](../CLAUDE.md) for the canonical entry point.
