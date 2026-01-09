# Docs Consolidation Plan

## Scope (CORRECTED)

**Target**: Only root `docs/*.md` files (31 files, ~9,339 lines)
**Keep AS-IS**: `arch/`, `features/`, `backends/`, `capabilities/` subdirectories

## Current State

- 31 root docs files (~9,339 lines)
- Subdirs already organized (not in scope)

## Target State

~5-7 root files + existing subdirs:

```
docs/
├── INDEX.md              # Router
├── ARCHITECTURE.md       # Overview
├── VISION.md             # Goals  
├── USER_GUIDE.md         # User-facing
├── YOUTUBE_API.md        # API reference
├── arch/                 # KEEP AS-IS
├── features/             # KEEP AS-IS
├── capabilities/         # KEEP AS-IS
└── backends/             # KEEP AS-IS
```

---

## Milestone 1: Delete Pure Historical (6 files, ~2,200 lines)

### Files to Delete
- `ARCHITECTURE_OLD.md` (999 lines) - superseded
- `REFACTORING_BEFORE_AFTER.md` (507 lines) - historical snapshot
- `DEVELOPMENT_HISTORY.md` (199 lines) - historical
- `PROJECT_STATUS.md` - stale status
- `ISSUE_FIX_PLAN.md` (261 lines) - completed
- `session-2025-12-08-rich-list-fixes.md` - session artifact

### Verification (Oracle reviews against source code)
After deletion, invoke Oracle to verify:
1. No remaining docs reference deleted files
2. INDEX.md links are still valid
3. No loss of critical architectural decisions

---

## Milestone 2: Distill ADRs → arch/ (8 files, ~3,200 lines)

### Files to Process
| ADR | Lines | Distill To |
|-----|-------|------------|
| `ADR-backend-refactor.md` | 703 | arch/action-system.md |
| `ADR-interactive-layout-system.md` | 559 | arch/section-model.md |
| `ADR-navigator-design.md` | - | arch/ui-navigation.md |
| `ADR-query-result-state-updates.md` | - | arch/action-system.md |
| `ADR-queue-trait-redesign.md` | 341 | features/queue.md |
| `ADR-rich-list-ui.md` | - | arch/ui-navigation.md |
| `ADR-section-as-container.md` | 319 | arch/section-model.md |
| `ADR-unified-view-architecture.md` | 292 | arch/ui-navigation.md |

### Process
1. Read ADR, extract key decisions (2-5 bullets)
2. Add "Rationale" section to target arch/*.md
3. Delete ADR file
4. Update INDEX.md (remove ADR links)

### Verification (Oracle reviews against source code)
After distillation, invoke Oracle to verify:
1. Distilled decisions match actual code implementation
2. No deprecated patterns (MusicBackend) referenced as current
3. Code paths in arch/*.md exist in rmpc/src/

---

## Milestone 3: Consolidate Remaining (~7 files, ~2,200 lines)

### Files to Decide
| File | Lines | Decision |
|------|-------|----------|
| `FEATURES.md` | 406 | DELETE (content in features/) |
| `README.md` | - | DELETE (redundant with INDEX.md) |
| `CODEBASE_MAP.md` | - | DELETE (content in ARCHITECTURE.md) |
| `CONSOLIDATION_BEST_PRACTICES.md` | 644 | DELETE (one-time guide) |
| `CONSOLIDATION_QUICK_START.md` | - | DELETE (one-time guide) |
| `DEVELOPMENT.md` | 260 | MERGE useful parts → AGENTS.md, delete |
| `COMMON_TASKS.md` | 295 | MERGE useful parts → AGENTS.md, delete |
| `BACKEND_DEVELOPMENT.md` | 203 | MERGE → backends/youtube/README.md or delete |
| `MPD_SERVICE.md` | 378 | KEEP or move to backends/mpd/ |
| `ui-ux-provised.md` | 466 | DELETE (superseded by arch/) |
| `TECHNICAL_INSIGHTS.md` | 235 | MERGE useful → MEMORY.md, delete |
| `grid-layout-design.md` | - | DELETE (completed design) |

### Verification (Oracle reviews against source code)
Final verification:
1. All remaining docs accurate to current codebase
2. No dead links in INDEX.md
3. No orphan references to deleted files
4. ~5-7 root files achieved

---

## Success Criteria

- [ ] ~5-7 root files in docs/ (down from 31)
- [ ] ~1,500-2,000 lines in root docs (down from 9,339)
- [ ] All subdirs (arch/, features/, etc.) unchanged
- [ ] Zero dead links
- [ ] Oracle verifies docs match source code after each milestone
- [ ] Key ADR decisions preserved in arch/*.md Rationale sections

---

## Beads

- Epic: `yrmpc-6g2` - Docs Consolidation
- M1: `yrmpc-b74` - Delete Historical
- M2: `yrmpc-5h6` - Distill ADRs  
- M3: `yrmpc-7lr` - Consolidate Remaining

Dependencies: M1 → M2 → M3
