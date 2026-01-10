# Open Problems

- Existing server design still uses a shared `Receiver<String>` for both Idle waits and internal processing (competing consumers). This task avoided touching that path by adding a dedicated `InternalEvent` channel, but the original string channel contention remains as technical debt.
