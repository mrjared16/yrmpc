# Documentation Index

## Quick Start (New LLM)
1. [`AGENTS.md`](./AGENTS.md) - START HERE: Mission brief and critical constraints
2. [`docs/SEARCH_IMPLEMENTATION_GUIDE.md`](#) - Your implementation task (TO BE CREATED)
3. [`walkthrough.md`](../brain/bbde7c30-4df2-489b-906d-08abb9e73c2b/walkthrough.md) - Recent session work

## User Guides
- [`YOUTUBE_SETUP_GUIDE.md`](../brain/bbde7c30-4df2-489b-906d-08abb9e73c2b/YOUTUBE_SETUP_GUIDE.md) - End-user setup instructions
- [`BUILD_AND_RUN.md`](./BUILD_AND_RUN.md) - Build and run instructions
- `README.md` - Project overview

## Architecture
- [`STREAMING_READINESS.md`](./STREAMING_READINESS.md) - Streaming architecture details
- `docs/DAEMON_ARCHITECTURE.md` - Systemd daemon design (TO BE CREATED)
- `docs/PROTOCOL.md` - IPC protocol specification (TO BE CREATED)

## Developer Guides
- `docs/TESTING.md` - How to test (TO BE CREATED)
- `docs/ADDING_FEATURES.md` - Feature development guide (TO BE CREATED)
- `config/rmpc.ron` - Configuration file example

## Current Status
- **Phase**: Search UI Implementation
- **Blocker**: No search panel in TUI
- **Recent Work**: Daemon architecture complete (see walkthrough.md)

## File Organization

### Project Root
```
yrmpc/
├── AGENTS.md                 ⭐ Start here
├── README.md                 📘 Project overview
├── BUILD_AND_RUN.md          🔨 Build instructions
├── STREAMING_READINESS.md    🎵 Architecture
├── config/
│   └── rmpc.ron              ⚙️  Config example
├── docs/
│   ├── INDEX.md              📑 This file
│   ├── SEARCH_IMPLEMENTATION_GUIDE.md  🔴 TO CREATE
│   ├── DAEMON_ARCHITECTURE.md          🔴 TO CREATE
│   └── PROTOCOL.md                     🔴 TO CREATE
├── rmpc/
│   ├── src/
│   │   ├── lib.rs            📚 Library crate
│   │   ├── bin/rmpcd.rs      🔧 Daemon binary
│   │   ├── player/youtube/   🎵 YouTube backend
│   │   └── ui/panes/search/  🔍 Search UI (YOUR TASK)
│   └── tests/
└── setup/
    ├── rmpcd.service         ⚙️  Systemd service
    ├── rmpcd-install         📥 Install script
    └── rmpcd-uninstall       🗑️  Uninstall script
```

### Artifacts (Session Work)
```
.gemini/antigravity/brain/<conversation-id>/
├── walkthrough.md            📝 Recent session log
├── task.md                   ☑️  Task checklist
├── implementation_plan.md    📋 Daemon plan (complete)
└── YOUTUBE_SETUP_GUIDE.md    📘 User guide
```

## Documentation Priorities

### Must Create Next
1. **`docs/SEARCH_IMPLEMENTATION_GUIDE.md`** - Step-by-step for search UI
   - API call implementation
   - UI panel creation
   - Keyboard binding
   - E2E testing

2. **`docs/DAEMON_ARCHITECTURE.md`** - Daemon design docs
   - Why systemd?
   - Socket communication
   - Process lifecycle
   - Troubleshooting

3. **`docs/PROTOCOL.md`** - IPC protocol spec
   - Command enum
   - Response enum
   - Serialization format
   - Error handling

### Lower Priority
- `docs/TESTING.md` - Testing guide (once search works)
- `docs/ADDING_FEATURES.md` - Feature development (future)
- API documentation (rustdoc)

## Search Path by Topic

### "How do I set up YouTube Music?"
→ [`YOUTUBE_SETUP_GUIDE.md`](../brain/bbde7c30-4df2-489b-906d-08abb9e73c2b/YOUTUBE_SETUP_GUIDE.md)

### "What's the current status?"
→ [`walkthrough.md`](../brain/bbde7c30-4df2-489b-906d-08abb9e73c2b/walkthrough.md)

### "What should I work on?"
→ [`AGENTS.md`](./AGENTS.md) → Search UI implementation

### "How does the daemon work?"
→ `docs/DAEMON_ARCHITECTURE.md` (TO BE CREATED)

### "What's the protocol?"
→ `docs/PROTOCOL.md` (TO BE CREATED)

### "How do I test?"
→ `docs/TESTING.md` (TO BE CREATED)

## Contributing

Before starting work:
1. Read `AGENTS.md` - Critical constraints
2. Check `walkthrough.md` - Recent changes
3. Review relevant docs above
4. Don't touch daemon code (it works)

## Maintenance

This index should be updated when:
- New documentation is created
- Project phase changes
- Architecture evolves
- Major milestones reached

Last updated: 2025-12-06 (Daemon architecture complete)
