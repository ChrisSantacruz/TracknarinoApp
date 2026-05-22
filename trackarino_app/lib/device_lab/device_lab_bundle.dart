import 'dart:convert';

import 'device_lab_capture_profile.dart';

class DeviceLabDiagnosticsBundle {
  final DeviceLabCaptureProfile profile;
  final DateTime generatedAt;
  final List<DeviceLabTimelineEvent> timeline;
  final Map<String, Object?> diagnostics;

  const DeviceLabDiagnosticsBundle({
    required this.profile,
    required this.generatedAt,
    required this.timeline,
    this.diagnostics = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'profile': profile.toJson(),
      'timeline': timeline.map((event) => event.toJson()).toList(),
      'diagnostics': diagnostics,
      'replayReady': true,
      'replayPolicy':
          'Timeline stitching is supported from captured events only; map playback interpolation is intentionally absent.',
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
