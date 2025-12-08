# LLM Agent Guidelines - yrmpc

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Use

---

## Quick Start
```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```

---

## Current State

| Feature | Status |
|---------|---------|
| Search (all types) | ✅ |
| Playback (MPV) | ✅ |
| Queue management | ✅ |
| MPRIS integration | ✅ |
| Daemon mode | ✅ |
| Autocomplete | ✅ |
| **Rich List UI** | ✅ |

---

## Next Priorities

| Priority | Task |
|----------|------|
| P0 | Queue Playing Highlight (R-QUEUE-1) |
| P1 | Queue View Revamp (R-QUEUE-2/3) |
| P1 | Artist/Playlist/Album Views (R-DETAIL) |
| P1 | High CPU idle |
| P2 | Grid View (see [grid-layout-design.md](docs/grid-layout-design.md)) |
| P2 | Prefetch (gapless playback) |
| P3 | API filtering |

> **Full spec:** [docs/ui-ux-provised.md](docs/ui-ux-provised.md)

---

## Key Files

| Purpose | File |
|---------|------|
| Search API | `player/youtube/api.rs` |
| Protocol | `player/youtube/protocol.rs` |
| Client | `player/youtube/client.rs` |
| Server | `player/youtube/server.rs` |
| SearchItem types | `domain/search/` |
| Config | `config/search.rs` |
| **Rich List Widget** | `ui/widgets/item_list.rs` |
| **Display Trait** | `domain/display.rs` |
| **Element Tree** | `ui/widgets/element.rs` |
| **Dir Navigation** | `ui/dirstack/dir.rs` |
| **DirStackItem Trait** | `ui/dirstack/mod.rs` |

---

## Read Order for New LLM

1. This file (`AGENTS.md`)
2. `LLM_ONBOARDING.md` - Research insights
3. `docs/ARCHITECTURE.md` - System design
4. `docs/FEATURES.md` - UX roadmap
5. `docs/YOUTUBE_API.md` - API reference
6. `docs/ADR-rich-list-ui.md` - Rich List UI architecture (if working on UI)

## Guidelines
- Leverage serena and sequential thinking to tackle complex tasks step by step. When you fix an issue, first think harder about it to find the root cause and produce supporting evidence, rather than just guessing. Additionally, when implementation is required, consider at least two potential solutions and analyze their pros and cons. Embrace Test-Driven Development (TDD) whenever possible.

## Plan and review
- Before you begin, MUST view files in .agent/sessions/context_session_x.md to get the full context (x being the id of the session we are operate, if file  doesn't exist, then create one).
- context_session_x.md should contain most of context of what we did, overall plan and agents will continously add context to the file.
- Whenever you have assumptions, you should ask clarifying questions to make better decisions.
- This plan should include:
    - A clear, detailed breakdown of the implementation steps
    - The reasoning behind your approach
    - A list of specific tasks
- Focus on a Minimum Viable Product (MVP) to avoid over-planning. Once the plan is ready, please ask me to review it. Do not proceed with implementation until I have approved the plan.

- After you finish the work, MUST update the .agent/sessions/context_session_x.md file to make sure others can get full context of what you did.
- Agents (if used) will do research about the implementation, but you will do the actual implementation; when passing task to agent, make sure you pass the context file, e.g. '.agent/sessions/context_session_x.md'. After each agent finish the work, make sure you read the related documentation they created to get full context of the plan before you start executing

## While implementing
As you work, keep the plan updated. After you complete a task, append a detailed description of the changes you've made to the plan. This ensures that the progress and next steps are clear and can be easily handed over to other engineers if needed.
