# Improve Architecture

Perform a complete backend refactor.

Goals:
- Fix architecture
- Fix endpoints
- Remove duplicated logic
- Fix authentication
- Validate requests
- Add centralized error handling
- Improve MongoDB performance
- Fix broken responses
- Add scalable services
- Add logging
- Add retry-safe operations

Requirements:
- Keep compatibility with Flutter app
- Do not break API contracts unnecessarily
- Explain every major backend issue found
- Refactor professionally

Architecture target:
- Routes should only define HTTP entry points
- Controllers should handle request/response orchestration
- Services should contain business logic
- Repositories should isolate MongoDB access
- Middleware should handle auth, roles, validation, and errors
- Shared utilities should avoid duplicated logic
