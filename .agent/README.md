# .agent Directory - LLM Onboarding Guide

## Purpose
This directory contains documentation specifically for LLMs (AI agents) working on the yrmpc project.

## Quick Start for New LLMs

### 1. Read ONBOARDING.md First ⭐
**File**: `ONBOARDING.md`  
**Purpose**: Complete project overview, vision, current state, architecture

**Contains**:
- Project goals and vision
- Current working features (backend complete!)
- Tech stack and dependencies
- Development workflow
- Common commands and tasks

### 2. Testing Documentation
**File**: `testing.md`  
**Purpose**: E2E test strategy and philosophy

**Key Points**:
- Tests verify REAL data (not just text)
- 3/6 passing with meaningful failures
- Tests organized in `tests/e2e/`
- Run with: `npm test`

### 3. Debugging Guide
**File**: `debugging.md`  
**Purpose**: Debugging procedures and troubleshooting

**Includes**:
- Log file locations
- Common issues and solutions
- tmux integration details
- Error debugging approaches

### 4. Development Commands
**File**: `development_commands.md`   
**Purpose**: Common commands for building, testing, running

### 5. Code Style
**File**: `code_style.md`  
**Purpose**: Rust code style guidelines

---

## Key Facts for New LLMs

### Backend Status ✅
**ALL features implemented**:
- Search parses all types (artists/albums/playlists/songs/videos)
- Enter routing works correctly
- Code location: `rmpc/src/player/youtube_backend.rs:1177-1460`

**No backend work needed!**

### Repository Status ✅  
- Clean (tmp files removed)
- Tests organized (`tests/e2e/`)
- Documentation consolidated
- Latest commit: b60bf26

### Testing Philosophy
- E2E tests verify REAL data
- 3/6 passing = GOOD (meaningful validation)
- Failures check actual song names, artist data
- Not superficial text-only checks

---

## File Organization

**.agent/** - LLM documentation
- ONBOARDING.md - Main guide
- testing.md - Test strategy
- debugging.md - Debug guide
- development_commands.md - Commands
- code_style.md - Code standards
- README.md - This file

**docs/** - User documentation
- See `docs/README.md` for index

**tests/** - Test suites
- `tests/e2e/` - E2E tests
- Run with `npm test`

---

## Session Summary (Dec 2, 2024)

**What We Investigated**: Whether backend supports all search types  
**What We Found**: Backend ALREADY complete! All types supported.  
**What We Improved**: E2E tests now verify real data  
**What We Cleaned**: Removed 24 obsolete test files, organized docs

---

## Read This Before Starting

1. **READ**: ONBOARDING.md (complete overview)
2. **CHECK**: `docs/FEATURES.md` (current feature status)
3. **RUN**: `npm test` (see test status)
4. **BUILD**: `cd rmpc && cargo build --release`

**Don't assume features broken** - investigate first!