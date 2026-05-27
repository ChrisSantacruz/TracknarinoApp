# Fix Navigation

Audit and fix TrackNariño navigation flows.

Analyze:
- Login and role-based routing
- Camionero flows
- Contratista flows
- Admin flows
- Back button behavior
- Deep links or route arguments if present
- State restoration after refresh/restart
- Navigation after API success or failure
- Error and empty states in route transitions

Fix:
- Broken transitions
- Wrong role destinations
- Screens reachable without required state
- Duplicate navigation code
- Missing loading and error handling around transitions
- UI state lost during route changes

Rules:
- Do not add fake routes or placeholder screens
- Keep route names and arguments predictable
- Preserve real backend-connected flows
- Explain root cause before changing navigation logic
