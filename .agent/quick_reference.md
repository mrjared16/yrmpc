# ⚡ Quick Reference: Common Fixes

## 🔧 Fix Templates (Copy-Paste Ready)

### Template 1: Add Missing Method to player::Client
```rust
pub fn METHOD_NAME(&mut self, /* params */) -> Result</* return type */> {
    match self {
        Client::Mpd(b) => b.client.METHOD_NAME(/* args */).map_err(Into::into),
        Client::Mpv(_) => Ok(/* default value */),
    }
}
```

### Template 2: Add Extension Trait Method
```rust
pub fn ext_method(&mut self, /* params */) -> Result</* return type */> {
    match self {
        Client::Mpd(b) => {
            use crate::shared::mpd_client_ext::MpdClientExt;
            b.client.ext_method(/* args */).map_err(Into::into)
        },
        Client::Mpv(_) => Ok(/* default */),
    }
}
```

### Template 3: Fix Closure Type
```rust
// FIND:
|client: &mut crate::mpd::client::Client<'_>|

// REPLACE WITH:
|client: &mut crate::player::Client<'_>|
```

### Template 4: Fix Return Type Wrapper
```rust
// If expecting Option<Vec<T>> but getting Vec<T>:

// FIND:
client.method()?.unwrap_or_default()

// REPLACE WITH:
client.method()?
```

## 📋 Specific Known Fixes

### sticker (ctx.rs:155)
```rust
// Add to player::Client
pub fn sticker(&mut self, uri: &str, key: &str) -> Result<String> {
    match self {
        Client::Mpd(b) => b.client.sticker(uri, key).map_err(Into::into),
        Client::Mpv(_) => Err(anyhow::anyhow!("Stickers not supported")),
    }
}
```

### fetch_song_stickers (event_loop.rs:677, ctx.rs:172)
```rust
pub fn fetch_song_stickers(&mut self, uris: Vec<String>) 
    -> Result<HashMap<String, HashMap<String, String>>> 
{
    match self {
        Client::Mpd(b) => {
            use crate::shared::mpd_client_ext::MpdClientExt;
            b.client.fetch_song_stickers(uris).map_err(Into::into)
        },
        Client::Mpv(_) => Ok(HashMap::new()),
    }
}
```

### read_response (player/client.rs:357)
```rust
pub fn read_response(&mut self) -> Result<()> {
    match self {
        Client::Mpd(b) => b.client.read_response().map_err(Into::into),
        Client::Mpv(_) => Ok(()),
    }
}
```

### send_move_output (player/client.rs:416)
```rust
pub fn move_output(&mut self, output_name: &str) -> Result<()> {
    match self {
        Client::Mpd(b) => b.client.send_move_output(output_name).map_err(Into::into),
        Client::Mpv(_) => Ok(()),
    }
}
```

### send_toggle_output (player/client.rs:430)
```rust
pub fn toggle_output(&mut self, id: u32) -> Result<()> {
    match self {
        Client::Mpd(b) => b.client.send_toggle_output(id).map_err(Into::into),
        Client::Mpv(_) => Ok(()),
    }
}
```

### enqueue_multiple (shared/mpd_client_ext.rs:42)
```rust
pub fn enqueue_multiple(
    &mut self,
    items: Vec<Enqueue>,
    autoplay_idx: Option<usize>,
    position: Option<QueuePosition>,
    replace: bool,
) -> Result<()> {
    match self {
        Client::Mpd(b) => {
            use crate::shared::mpd_client_ext::MpdClientExt;
            b.client.enqueue_multiple(items, autoplay_idx, position, replace)
                .map_err(Into::into)
        },
        Client::Mpv(_) => Ok(()),
    }
}
```

## 🔍 Search Commands

### Find all missing methods
```bash
cd <PROJECT_ROOT>/rmpc
cargo build --release 2>&1 | grep "no method named" | sed 's/.*`\(.*\)`.*/\1/' | sort | uniq
```

### Find closures needing type fixes
```bash
grep -rn "mpd::client::Client<'_>" src/ | grep -v "//.*mpd::client"
```

### Find extension trait issues
```bash
cargo build --release 2>&1 | grep "trait bounds were not satisfied" -A2
```

### Check specific file errors
```bash
cargo build --release 2>&1 | grep "src/core/work.rs" -A3
```

## 📝 Workflow

### Step-by-Step Process

1. **Get error list**
```bash
cargo build --release 2>&1 | tee /tmp/errors.txt
grep "error\[E" /tmp/errors.txt | wc -l  # Count
```

2. **Group by category**
```bash
# Missing methods
grep "no method named" /tmp/errors.txt > /tmp/missing_methods.txt

# Closure types
grep "type mismatch in closure" /tmp/errors.txt > /tmp/closure_types.txt

# Trait bounds
grep "trait bounds" /tmp/errors.txt > /tmp/trait_bounds.txt
```

3. **Fix one category**
   - Pick Template 1, 2, or 3
   - Apply to all instances
   - Save changes

4. **Verify progress**
```bash
cargo build --release 2>&1 | grep "error\[E" | wc -l
```

5. **Repeat**

## 🎯 Priority Order

Fix in this order for maximum error reduction:

1. **High Impact**: Missing simple methods (Template 1)
   - Fixes ~20-30 errors quickly
   - Examples: `sticker`, `read_response`, `send_*`

2. **Medium Impact**: Extension trait methods (Template 2)
   - Fixes ~20-30 errors
   - Needs import: `use crate::shared::mpd_client_ext::MpdClientExt;`

3. **Medium Impact**: Closure types (Template 3)
   - Fixes ~40-50 errors
   - Search and replace

4. **Low Impact**: Return type wrappers (Template 4)
   - Fixes ~20 errors
   - Case-by-case basis

## ⚠️ Common Mistakes

### ❌ DON'T DO THIS:
```rust
// Adding method to wrong struct
impl MpdBackend {  // ❌ Wrong!
    pub fn new_method() { }
}

// Wrong client type
pub fn method(client: &mut mpd::client::Client) { }  // ❌ Use player::Client

// Forgetting .map_err
b.client.method()  // ❌ Type error

// Not handling MPV case
match self {
    Client::Mpd(b) => b.client.method(),
    // ❌ Missing MPV arm!
}
```

### ✅ DO THIS:
```rust
// Add to player::Client
impl<'name> Client<'name> {  // ✅ Correct!
    pub fn new_method(&mut self) -> Result<()> {
        match self {
            Client::Mpd(b) => b.client.method().map_err(Into::into),  // ✅
            Client::Mpv(_) => Ok(()),  // ✅ Handle MPV
        }
    }
}
```

## 📊 Error Count Checkpoints

Track progress:
```
Start:  159 errors
After missing methods:     ~130 errors (-29)
After extension traits:    ~100 errors (-30)
After closure types:       ~50 errors (-50)
After return types:        ~20 errors (-30)
After misc:                0 errors (-20) 🎉
```

## 🚀 Batch Edit Script

For repetitive fixes, use this pattern:
```bash
# Example: Fix all closures in one go
find src/ -name "*.rs" -exec sed -i 's/mpd::client::Client/player::Client/g' {} \;

# Then verify
cargo build --release 2>&1 | grep "error\[E" | wc -l
```

---

**Remember**: Most fixes follow the same 3 patterns. Don't overthink it! 🧠
