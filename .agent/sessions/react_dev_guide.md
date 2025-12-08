# rmpc UI Architecture for React.js Developers

> A guide mapping React.js concepts to ratatui/rmpc patterns.

---

## Concept Mapping

| React.js | rmpc/ratatui | Example |
|----------|--------------|---------|
| `<App>` root | `Ui` struct | Top container |
| `<Routes>` / Tabs | `TabScreen` | Navigation |
| Page component | `impl Pane` trait | SearchPane, QueuePane |
| Reusable component | Widget struct | Button, Input, Browser |
| `props` | Struct fields + `&Ctx` | Data passed to render |
| `useState` | Mutable struct fields | Local component state |
| `useContext` | `&Ctx` parameter | Global app context |
| **`children` / JSX composition** | **`PropertyKindOrText::Group`** | **Already exists!** |
| `styled-components` | `Style` struct | Colors, modifiers |
| Flexbox / Grid | `Layout::horizontal/vertical` | Constraint-based |

---

## The Pane Trait (Like React Component)

```rust
pub trait Pane {
    // Like render() in React
    fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) -> Result<()>;
    
    // Like componentDidMount
    fn before_show(&mut self, ctx: &Ctx) -> Result<()>;
    
    // Like componentWillUnmount
    fn on_hide(&mut self, ctx: &Ctx) -> Result<()>;
    
    // Like event handlers
    fn handle_action(&mut self, event: &mut KeyEvent, ctx: &mut Ctx) -> Result<()>;
    fn on_event(&mut self, event: &mut UiEvent, is_visible: bool, ctx: &Ctx) -> Result<()>;
}
```

---

## Hidden Gem: Declarative Composition Exists!

rmpc already has JSX-like composition via `PropertyKindOrText`:

```rust
enum PropertyKindOrText<T> {
    Text(String),              // Static: "Hello"
    Property(T),               // Dynamic: {artist}
    Group(Vec<Property>),      // Composition: <>{a}{b}</>
    Transform(Transform),      // Transforms: truncate, replace
}
```

**Config example (RON format):**
```ron
format: (
    kind: Group([
        (kind: Property(Title), style: Bold),
        (kind: Text(" · ")),
        (kind: Property(Artist), style: Dim),
    ])
)
```

This IS declarative like React! But **only outputs TEXT**.

---

## The GAP: No Unified Element Type

In React, everything is a React Element:
```jsx
<div>           // DOM element
<Component />   // Custom component
{children}      // Nested elements
"text"          // Text node
```

In rmpc, different things have different types:
- `Span`, `Line`, `ListItem` → TEXT
- `AsyncImage` → IMAGE (renders differently!)
- `Layout` → CONTAINER

**No way to compose images with text in the same abstraction.**

---

## Future Direction: RenderElement (React-Inspired)

```rust
enum RenderElement {
    Text(StyledText),
    Image { url: String, placeholder: char },
    Row(Vec<RenderElement>),
    Column(Vec<RenderElement>),
    Icon { symbol: char, color: Color },
    Spacer,
}
```

This would enable:
```rust
RenderElement::Row(vec![
    RenderElement::Image { url: thumbnail },
    RenderElement::Column(vec![
        RenderElement::Text(title),
        RenderElement::Text(artist.dim()),
    ]),
])
```

---

## MVP vs Future

| Phase | Approach |
|-------|----------|
| **MVP (Now)** | `ListItemDisplay` trait + `ItemListWidget` with hardcoded layout |
| **Future** | `RenderElement` enum for config-driven composition |

The MVP architecture ALLOWS future evolution without rewrite.

---

## Layout System

Like CSS Flexbox but simpler:

```rust
let [left, center, right] = Layout::horizontal([
    Constraint::Length(4),      // Fixed 4 cells
    Constraint::Min(0),         // Fill remaining (flex: 1)
    Constraint::Length(6),      // Fixed 6 cells
]).areas(rect);
```

Nest layouts for complex UIs:
```rust
let [header, body, footer] = Layout::vertical([...]).areas(rect);
let [sidebar, main] = Layout::horizontal([...]).areas(body);
```

---

## Key Differences from React

| React | ratatui |
|-------|---------|
| Virtual DOM reconciliation | Full re-render every frame (16ms) |
| Declarative JSX | Imperative `frame.render_widget()` |
| Async rendering | Synchronous per-frame |
| Component tree | Flat pane list + widgets |
| CSS cascade | Explicit style per element |
