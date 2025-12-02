# Code Style Guide

## Rust Code Style

### General Principles
- Use `rustfmt` for consistent formatting
- Prefer clear, descriptive variable names
- Use `Result<T>` for error handling with `anyhow`
- Add logging for debugging and monitoring

### Error Handling
```rust
use anyhow::{Result, anyhow, bail};

// Preferred pattern
fn example() -> Result<()> {
    let data = fetch_data()?;
    if data.is_empty() {
        bail!("Data cannot be empty");
    }
    process_data(data)
}
```

### Logging
```rust
use log::{debug, info, warn, error};

debug!("Processing item: {}", item);
info!("Operation completed successfully");
warn!("Unexpected condition: {}", condition);
error!("Operation failed: {:?}", error);
```

## Python Code Style

### General Principles
- Use 4-space indentation
- Follow PEP 8 guidelines
- Use type hints for function signatures
- Add docstrings for functions

### Error Handling
```python
import logging
from typing import Optional, List

def process_data(data: str) -> Optional[str]:
    """Process input data and return result."""
    try:
        if not data.strip():
            logging.warning("Empty data provided")
            return None
        
        return data.strip().upper()
    except Exception as e:
        logging.error("Failed to process data: %s", e)
        return None
```

### Logging
```python
import logging

logger = logging.getLogger(__name__)

logger.debug("Processing item: %s", item)
logger.info("Operation completed successfully")
logger.warning("Unexpected condition: %s", condition)
logger.error("Operation failed: %s", error)
```

## Test Code Style

### Structure
- Use descriptive test names
- Arrange-Act-Assert pattern
- Test both success and failure cases
- Use clear assertions

### Example
```python
def test_search_functionality():
    """Test that search returns expected results."""
    # Arrange
    query = "test query"
    expected_results = ["result1", "result2"]
    
    # Act
    actual_results = search(query)
    
    # Assert
    assert actual_results == expected_results
    assert len(actual_results) > 0
```

## Documentation Style

### Markdown
- Use clear headings with `#`, `##`, `###`
- Use code blocks with language specifiers
- Use bullet points for lists
- Add tables for structured information

### Example
```markdown
## Feature Overview

### Usage
```python
result = feature_function(param1, param2)
```

### Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| param1    | str   | First parameter |
| param2    | int   | Second parameter |

### Notes
- Important considerations
- Edge cases to handle
```