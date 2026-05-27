# Fix State

Audit and fix Flutter state management in TrackNariño.

Analyze:
- Provider architecture
- Service lifetimes
- Loading, success, empty, and error states
- Auth state
- Active trip state
- GPS tracking state
- Alert state
- Offline queue and sync state
- Navigation-dependent state
- Rebuild performance

Fix:
- Race conditions
- Stale UI
- Lost state after navigation
- Duplicated state across screens
- Async errors not surfaced to the user
- Unnecessary rebuilds
- Missing disposal of controllers, streams, timers, or subscriptions

Rules:
- Keep state separate from UI rendering
- Keep API logic in services or repositories
- Do not hide errors silently
- Do not introduce global mutable state without justification
