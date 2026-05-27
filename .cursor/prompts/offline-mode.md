# Offline Mode

Implement a true offline-first architecture.

Requirements:
- Store pending alerts locally
- Queue failed requests
- Sync automatically on reconnection
- Persist GPS tracking offline
- Prevent data loss
- Add local cache database
- Add retry system
- Handle intermittent signal

Critical:
Security alerts must NEVER be lost even if internet fails.

Before editing:
1. Audit current API services and alert flow
2. Identify local persistence options already used by the project
3. Define queue format and duplicate prevention strategy
4. Define reconnection and retry behavior
5. Preserve backend API compatibility

After editing:
- Verify alert persistence across app restart
- Verify failed requests retry safely
- Verify the UI communicates sync state clearly
