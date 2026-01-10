# Decisions

- Kept the existing string-based Idle event channel (`Sender<String>`) untouched for client/TUI refresh behavior.
- Introduced a separate `Sender<InternalEvent>` channel for service→orchestrator routing to avoid coupling internal state events to the Idle subsystem.
- Orchestrator event processor only TRACE-logs events for now (no behavior), per plan Task 1 requirements.
