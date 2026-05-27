# Optimize Maps

Refactor the routing and maps system completely.

Current issues:
- Routes become inefficient
- Obstacles are ignored
- Dynamic rerouting fails

Implement:
- Smart rerouting
- Obstacle-aware routes
- Real-time recalculation
- Better GPS tracking
- Safe route prioritization
- Traffic-aware logic
- Route recovery after signal loss

Optimize for Colombian road conditions and unstable connectivity.

Before editing:
1. Trace current map data flow
2. Identify route source and recalculation triggers
3. Check GPS update handling
4. Check backend incident/obstacle data contracts
5. Explain the root cause of stale or inefficient routes
