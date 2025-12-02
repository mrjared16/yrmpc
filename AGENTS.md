# 🤖 LLM Entry Point - yrmpc Project

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Status**: Backend complete, E2E tests improved, ready for next phase

---

## 🚀 Quick Start for New LLMs

### 1. Read Onboarding Docs (In Order)
1. **`.agent/ONBOARDING.md`** ⭐ - Complete project overview, current state
2. **`docs/PROJECT_STATUS.md`** - What's working vs what's planned
3. **`docs/FEATURES.md`** - Feature status and backend locations
4. **`.agent/testing.md`** - E2E test philosophy

### 2. Current Status (Dec 2, 2024)
✅ **Backend**: ALL search types supported (artists/albums/playlists/songs/videos)  
✅ **Tests**: 3/6 E2E tests passing with real data validation  
✅ **Repo**: Clean, organized, tmp files removed  
❌ **Next**: Manual testing needed, improve E2E test queries

**Key Finding**: Backend already works! No code changes needed.

---

## ⚙️ Required Tool Usage

### Use Sequential Thinking for Complex Problems
**Tool**: `mcp0_sequentialthinking`  
**When**: Multi-step analysis, debugging, architecture decisions

```
Example: Investigating why tests fail
→ Use sequential thinking to break down problem
→ Analyze logs systematically
→ Form hypothesis, verify, iterate
```

### Use Serena for Codebase Work
**Tools**: `mcp1_*` (find_symbol, search_for_pattern, etc.)  
**Why**: Large Rust codebase, precise navigation needed

**Key Serena Tools**:
- `mcp1_find_symbol` - Find classes, functions, methods by name
- `mcp1_search_for_pattern` - Regex search in files
- `mcp1_get_symbols_overview` - Understand file structure
- `mcp1_replace_symbol_body` - Edit code precisely

**Example**:
```typescript
// Find backend search implementation
mcp1_find_symbol("search", "rmpc/src/player/youtube_backend.rs")

// Search for HTTP error handling
mcp1_search_for_pattern("HTTP 400")
```

### Use ast-grep for Code Patterns
**When**: Finding similar code patterns, refactoring

**Example**: Find all error handling patterns
```bash
ast-grep --pattern 'if let Err($err) = $expr { $$$ }'
```

---

## 📂 Repository Structure

```
yrmpc/
├── .agent/               # LLM onboarding docs (read first!)
│   ├── ONBOARDING.md     # Main guide ⭐
│   ├── README.md         # Navigation
│   ├── testing.md        # E2E philosophy
│   └── debugging.md      # Debug guide
├── docs/                 # User documentation
│   ├── PROJECT_STATUS.md # Current vs planned
│   ├── FEATURES.md       # Feature locations
│   └── ARCHITECTURE.md   # System design
├── rmpc/                 # Main Rust codebase (submodule)
│   └── src/
│       ├── player/
│       │   └── youtube_backend.rs  # Backend (lines 1177-1460)
│       └── ui/panes/search/mod.rs  # Search UI
└── tests/e2e/            # E2E test suite
    └── rmpc-tui-test.spec.ts  # Run: npm test
```

---

## 🎯 Current WIP Tasks

### Ready to Work On
1. **Manual Testing** - Verify UI shows diverse search results
2. **E2E Test Improvements** - Better search queries for diverse results
3. **Documentation** - Update any outdated info

### NOT Needed
❌ Backend changes (already complete!)  
❌ Search implementation fixes (works!)  
❌ Enter handler rewrites (correct!)

---

## 🧠 Workflow for Complex Tasks

1. **Think Sequentially** (`mcp0_sequentialthinking`)
   - Break down problem
   - Form hypothesis
   - Verify step-by-step

2. **Navigate with Serena** (`mcp1_find_symbol`, etc.)
   - Don't guess file locations
   - Use symbol search to find code
   - Get overview before editing

3. **Search Patterns** (ast-grep, `grep_search`)
   - Find similar code
   - Understand patterns
   - Consistent refactoring

4. **Test Thoroughly**
   - Run `npm test` for E2E tests
   - Check `cargo test` for unit tests
   - Manual testing when needed

---

## 💡 Key Insights from Last Session

**What We Thought**: Backend broken, features don't work  
**What We Found**: Backend complete, all types supported!  
**Lesson**: Investigate before assuming. Use logs + sequential thinking.

**Test Philosophy**:
- OLD: Check for generic text → always passes → meaningless
- NEW: Check for real data → meaningful failures → useful

**Tools Matter**:
- Sequential thinking prevents rushing to wrong conclusions
- Serena prevents file navigation errors
- Proper tools = better code quality

---

## 📖 Before You Start Coding

1. ✅ Read `.agent/ONBOARDING.md` completely
2. ✅ Check `docs/FEATURES.md` for current state
3. ✅ Run `npm test` to see test status
4. ✅ Use sequential thinking for complex problems
5. ✅ Use Serena for codebase navigation
6. ✅ Ask questions if unclear

**Don't assume, investigate!** 🔍
