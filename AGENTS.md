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

# AGENTS.md - Antigravity Project Context

## 🚀 Mission: Antigravity
**Goal:** Build a "Weightless," high-performance YouTube Music TUI client.
**Philosophy:** Optimistic UI, Instant Interactions, "Invisible" Backend.
**Base:** Forked from `mierak/rmpc` (Rust TUI).

## 🏗️ Architecture: The "Antigravity" Pivot
We are transforming `rmpc` from a generic MPD client into a specialized YouTube Music client.

### Core Components
1.  **UI Engine (`rmpc`):**
    *   **Keep:** The robust TUI engine, pane system (`src/ui/panes`), and configuration (`config.ron`).
    *   **Why:** Best-in-class layout system (recursive splits) and event loop.

2.  **Backend (`mpv`):**
    *   **New:** Replacing MPD with `mpv` subprocess controlled via JSON IPC.
    *   **Why:** Gapless playback, superior buffering, instant start, native format support.
    *   **Integration:** `MpvClient` simulates MPD's `idle` loop to keep `rmpc`'s UI in sync.

3.  **Brain (`ytmapi-rs`):**
    *   **New:** Porting logic from `youtui` to handle YouTube Music API.
    *   **Why:** Handles search suggestions, metadata, and "Watch Playlist" generation.

## 🗺️ Roadmap
- **Phase 1:** Baseline Verification (Completed - Mopidy was too slow).
- **Phase 2:** The Pivot (Current) - Strip MPD, Inject `ytmapi-rs`, Add `mpv`.
- **Phase 3:** UI "Ultrathink" - Implement Home, Artist, Search, Player panes.
- **Phase 4:** "Weightless" Features - Image cache, Radio daemon.

## 📂 Key Directories
- `.agent/`: Context files for agent handover.
- `rmpc/`: The main codebase (forked).
- `youtui/`: Reference codebase (for porting logic).

## 💡 Current State
- **Active Phase:** Phase 2.3 - Backend Abstraction Implementation
- **Current Session ID:** 298f0669-5475-431c-bece-d7d1d82ff263
- **Status:** Fixing compilation errors (140/159 remaining)
- **Next Agent**: Read `.agent/handout.md` for complete context

## 📚 Documentation Structure

### For New Agents (START HERE)
1. **`.agent/handout.md`** - Main briefing document with current state
2. **`.agent/technical_context.md`** - Architecture and type system details
3. **`.agent/quick_reference.md`** - Copy-paste fix templates
4. **`.agent/context_session_current.md`** - This session's timeline

### For Project Context
- **`/home/phucdnt/.gemini/antigravity/brain/.../task.md`** - Task tracking
- **`/home/phucdnt/.gemini/antigravity/brain/.../implementation_plan.md`** - Strategic plan

## 🎯 Immediate Action for New Agent

```bash
# 1. Read handout
cat /home/phucdnt/workspace/projects/yrmpc/.agent/handout.md

# 2. Check error count
cd /home/phucdnt/workspace/projects/yrmpc/rmpc
cargo build --release 2>&1 | grep "error\[E" | wc -l

# 3. Start fixing (see quick_reference.md for templates)
```