# Mobile Staging Deployment

Run staging builds with explicit API and map configuration:

```bash
flutter run --profile --dart-define=TRACKNARINO_DEV=false --dart-define=TRACKNARINO_API_URL=https://staging.example.com/api --dart-define=GOOGLE_MAPS_API_KEY=REPLACE_AT_BUILD_TIME
```

Device-lab runs should capture the app build, device model, OS version, scenario type, session ID, and correlation ID. Use Flutter profile mode and DevTools for performance and memory evidence. Do not record fake route playback or generated GPS traces.
