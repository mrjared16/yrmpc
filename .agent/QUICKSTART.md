# Quick Start: Resume Backend Abstraction Work

**Last Updated**: 2025-11-21 18:55  
**Current Errors**: 79  
**Phase**: 1C - Finishing compilation fixes

## 🚀 Immediate Next Steps (Start Here!)

### 1. Verify Current State
```bash
cd <PROJECT_ROOT>/rmpc
cargo build --release 2>&1 | grep "error\[E" | wc -l
# Should show: 79 errors
```

### 2. Add Missing Methods
Location: `rmpc/src/player/client.rs`

Use Serena:
```python
mcp0_find_symbol(
    name_path_pattern="get_status",
    relative_path="rmpc/src/player/client.rs"
)
# Find line number, then:

mcp0_insert_after_symbol(
    name_path="get_status",
    relative_path="rmpc/src/player/client.rs",
    body="""
    pub fn pause_toggle(&mut self) -> Result<()> {
        match self {
            Client::Mpd(b) => b.client.pause_toggle().map_err(Into::into),
            Client::Mpv(_) => Ok(()),
        }
    }

    pub fn move_in_queue(&mut self, from: u32, to: u32) -> Result<()> {
        match self {
            Client::Mpd(b) => b.client.move_in_queue(from, to).map_err(Into::into),
            Client::Mpv(_) => Ok(()),
        }
    }
    """
)
```

**Expected Result**: Errors drop from 79 → ~75

### 3. Fix Field Access Errors

Find them:
```bash
cargo build --release 2>&1 | grep "E0609" | grep "field \`0\`"
```

Common pattern:
```rust
// WRONG
let outputs = client.outputs()?;
for output in outputs.0 { ... }

// RIGHT (if wrapper type)
let Outputs(outputs) = client.outputs()?;
for output in outputs { ... }

// OR (if direct Vec)
let outputs = client.outputs()?;
for output in outputs { ... }
```

Use search:
```python
mcp0_search_for_pattern(
    substring_pattern=r"\.0\.into_iter\(\)",
    relative_path="rmpc/src"
)
```

### 4. Fix Closure Types

Location: `rmpc/src/ui/browser.rs`

Find/replace pattern:
```bash
# Search
mcp0_search_for_pattern(
    substring_pattern="FnOnce.*Client<'",
    relative_path="rmpc/src/ui"
)

# Change from:
impl FnOnce(&mut Client<'_>) -> Result<Vec<Song>>

# Change to:
impl FnOnce(&mut player::Client<'_>) -> Result<Vec<Song>>
```

### 5. Verify Progress
```bash
cargo build --release 2>&1 | grep "error\[E" | wc -l
# Track progress: 79 → 75 → 60 → ...
```

## 📚 Key Documentation

| File | Purpose |
|------|---------|
| `task.md` | Checklist (mark items as you complete) |
| `implementation_plan.md` | Full 6-phase architecture plan |
| `.agent/technical_context.md` | Code patterns, examples |
| Memory `current_session_state.md` | Session state, last action |

## 🔍 Finding Things

### Find where a method is called:
```python
mcp0_search_for_pattern(
    substring_pattern="\.pause_toggle\(",
    relative_path="rmpc/src"
)
```

### Find method definition:
```python
mcp0_find_symbol(
    name_path_pattern="pause_toggle",
    relative_path="rmpc/src"
)
```

### Find trait implementation:
```python
mcp0_search_for_pattern(
    substring_pattern="impl MpdClient for",
    relative_path="rmpc/src"
)
```

## ⚠️ Common Pitfalls

### 1. Using grep instead of Serena
```bash
# ❌ Don't: grep -r "method_name" src/
# ✅ Do: mcp0_search_for_pattern
```

### 2. Editing without understanding
```bash
# ❌ Don't: Change code just to fix error
# ✅ Do: Read technical_context.md for pattern
```

### 3. Not updating docs
```bash
# ❌ Don't: Fix 10 errors, forget to update task.md
# ✅ Do: Update after each logical chunk
```

## 🎯 Success Metrics

- [ ] Errors: 79 → 0
- [ ] `cargo build --release` succeeds
- [ ] `cargo clippy -- -D warnings` passes
- [ ] `cargo test` passes (existing tests)

## 🗺️ The Big Picture

**Current Phase**: Phase 1 - Compilation fixes
**Goal**: Get to 0 errors with current delegation approach
**Why**: Clean slate before architecture refactor

**Next Phase**: Phase 2 - Adapter pattern refactor
**Goal**: Make backends adapt to domain types
**Why**: Enable YouTube backend without MPD

**End Goal**: Run rmpc with YouTube Music, no MPD needed
**Timeline**: ~15-20 hours total, ~3 hours remaining in Phase 1

## 🔄 Update Workflow

After completing a sub-task:

1. **Mark in task.md**:
   ```markdown
   - [x] Add pause_toggle method
   ```

2. **Update current_session_state.md**:
   ```markdown
   ## Last Action Taken
   Added pause_toggle and move_in_queue methods
   
   ## Next Action to Take
   Fix field access errors for .0 on Vec types
   ```

3. **Run build**:
   ```bash
   cargo build --release 2>&1 | grep "error\[E" | wc -l
   ```

4. **Commit** (if using git):
   ```bash
   git add -A
   git commit -m "feat: add pause_toggle and move_in_queue methods"
   ``````

## 🆘 If Stuck

1. Check `technical_context.md` for similar example
2. Search existing code for pattern:
   ```python
   mcp0_search_for_pattern(
       substring_pattern="similar_pattern",
       relative_path="rmpc/src"
   )
   ```
3. Read error message carefully
4. Check if method exists in MPD client:
   ```python
   mcp0_find_symbol(
       name_path_pattern="method_name",
       relative_path="rmpc/src/mpd"
   )
   ```

## 🚂 Staying On Track

**You're on track if:**
- Errors are decreasing steadily
- You're following task.md checklist
- Changes match patterns in technical_context.md
- Documentation stays updated

**You're off track if:**
- Errors increase or stay same after multiple changes
- You're adding features not in task.md
- You haven't updated docs in 30+ minutes
- You're fixing same error type repeatedly

## 📞 Context for User

If user asks "where are we?":
> We're in Phase 1 of 6, finishing compilation fixes. Currently at 79 errors down from 159. 
> Next immediate task is adding 2 missing methods (pause_toggle, move_in_queue), then fixing 
> field access patterns. After Phase 1, we'll refactor to adapter pattern to enable YouTube 
> Music backend without MPD. Full plan in implementation_plan.md.

## 🎬 Start Command

```bash
# Copy-paste to begin:
cd <PROJECT_ROOT>/rmpc && \
cargo build --release 2>&1 | tee /tmp/build.log && \
grep "error\[E" /tmp/build.log | wc -l && \
echo "Ready to add pause_toggle and move_in_queue methods"
```

**Good luck! 🚀**
