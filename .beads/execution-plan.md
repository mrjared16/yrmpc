# Execution Plan: Documentation Restructure

## Epic: yrmpc-t0v - Revamp ARCHITECTURE.md

### Batch 1 (Parallel - No Dependencies)
| Bead | Title | Worker | Status |
|------|-------|--------|--------|
| yrmpc-vix | Slim ARCHITECTURE.md to routing-only | document-writer | pending |
| yrmpc-zyq | Create docs/arch/youtube-integration.md | document-writer | pending |
| yrmpc-1q1 | Create docs/arch/action-system.md | document-writer | pending |
| yrmpc-1bw | Create docs/arch/ui-navigation.md | document-writer | pending |
| yrmpc-54x | Create docs/features/playback.md | document-writer | pending |

### Batch 2 (Depends on Batch 1)
| Bead | Title | Worker | Blocked By |
|------|-------|--------|------------|
| yrmpc-5wi | Create docs/features/search.md | document-writer | yrmpc-zyq |
| yrmpc-p71 | Update docs/INDEX.md | document-writer | yrmpc-vix |

### Template (all docs)
- Purpose (1-2 sentences)
- When to Read (symptoms/tasks)
- Architecture Overview (component hierarchy diagram)
- Data Flow (step-by-step diagram)
- Key Files (3-5 max)
- Debugging Checklist (symptom → layer → file)
- See Also (3-6 links)

### Size Limits
- Landing docs: ≤150 lines
- Primitive docs: 150-300 lines
- Feature docs: 100-250 lines
