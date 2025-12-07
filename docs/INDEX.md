# Documentation Index

## For New LLM
| Order | File | Purpose |
|-------|------|---------|
| 1 | `AGENTS.md` (root) | Quick reference, current state |
| 2 | `LLM_ONBOARDING.md` (root) | Research insights for Rich UI |
| 3 | `docs/ARCHITECTURE.md` | System design, SearchItem types |
| 4 | `docs/FEATURES.md` | UX roadmap, key bindings |
| 5 | `docs/YOUTUBE_API.md` | API reference, authentication |

## Documentation Map

| File | Content |
|------|---------|
| `ARCHITECTURE.md` | System design, SearchItem architecture |
| `YOUTUBE_API.md` | API reference, ID formats, authentication |
| `FEATURES.md` | UX roadmap, key bindings, detail views |
| `PROJECT_STATUS.md` | Current state and next priorities |
| `CODEBASE_MAP.md` | File navigation guide |
| `COMMON_TASKS.md` | How-to guides |
| `DEVELOPMENT.md` | Development setup |
| `USER_GUIDE.md` | End-user documentation |

## Current Status
- **Phase**: Core Complete ✅
- **Next**: Rich UI (thumbnail + 2-line layout)

## Key Directories

```
yrmpc/
├── AGENTS.md               # ⭐ New LLM start here
├── LLM_ONBOARDING.md       # Research insights
├── config/rmpc.ron         # Runtime config
├── docs/                   # This documentation
├── rmpc/                   # Main application (submodule)
│   ├── src/
│   │   ├── domain/search/  # SearchItem types
│   │   ├── player/youtube/ # YouTube backend
│   │   └── ui/panes/       # UI components
│   └── tests/
└── youtui/                 # ytmapi-rs (local patches)
```

Last updated: 2025-12-08
