class OperationalReleaseStatus {
  final DateTime generatedAt;
  final String overallState;
  final int confidenceScore;
  final String confidenceBasis;
  final List<ReleaseGate> gates;
  final List<ReadinessCategoryScore> readinessScores;
  final List<ReleaseBlocker> unresolvedBlockers;
  final EvidenceCompleteness evidenceCompleteness;
  final List<String> operationalNotes;

  const OperationalReleaseStatus({
    required this.generatedAt,
    required this.overallState,
    required this.confidenceScore,
    required this.confidenceBasis,
    required this.gates,
    required this.readinessScores,
    required this.unresolvedBlockers,
    required this.evidenceCompleteness,
    required this.operationalNotes,
  });

  factory OperationalReleaseStatus.fromJson(Map<String, dynamic> json) {
    final score = _map(json['releaseConfidenceScore']);
    final evidence = _map(json['evidence']);
    return OperationalReleaseStatus(
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      overallState: json['overallState']?.toString() ?? 'fail',
      confidenceScore: (score['value'] as num?)?.toInt() ?? 0,
      confidenceBasis: score['basis']?.toString() ?? '',
      gates:
          _list(json['gates'])
              .map((gate) => ReleaseGate.fromJson(_map(gate)))
              .toList(),
      readinessScores:
          _list(json['readinessScores'])
              .map((item) => ReadinessCategoryScore.fromJson(_map(item)))
              .toList(),
      unresolvedBlockers:
          _list(json['unresolvedBlockers'])
              .map((item) => ReleaseBlocker.fromJson(_map(item)))
              .toList(),
      evidenceCompleteness: EvidenceCompleteness.fromJson(
        _map(evidence['completeness']),
      ),
      operationalNotes:
          _list(json['operationalNotes']).map((item) => item.toString()).toList(),
    );
  }
}

class ReleaseGate {
  final String id;
  final String category;
  final String severity;
  final String state;
  final List<String> evidenceRequired;
  final List<ReleaseBlocker> issues;
  final List<String> notes;

  const ReleaseGate({
    required this.id,
    required this.category,
    required this.severity,
    required this.state,
    required this.evidenceRequired,
    required this.issues,
    required this.notes,
  });

  factory ReleaseGate.fromJson(Map<String, dynamic> json) {
    return ReleaseGate(
      id: json['id']?.toString() ?? 'gate',
      category: json['category']?.toString() ?? 'readiness',
      severity: json['severity']?.toString() ?? 'warning',
      state: json['state']?.toString() ?? 'blocked',
      evidenceRequired:
          _list(json['evidenceRequired']).map((item) => item.toString()).toList(),
      issues:
          _list(json['issues'])
              .map((item) => ReleaseBlocker.fromJson(_map(item)))
              .toList(),
      notes: _list(json['notes']).map((item) => item.toString()).toList(),
    );
  }
}

class ReadinessCategoryScore {
  final String category;
  final int score;
  final String state;

  const ReadinessCategoryScore({
    required this.category,
    required this.score,
    required this.state,
  });

  factory ReadinessCategoryScore.fromJson(Map<String, dynamic> json) {
    return ReadinessCategoryScore(
      category: json['category']?.toString() ?? 'readiness',
      score: (json['score'] as num?)?.toInt() ?? 0,
      state: json['state']?.toString() ?? 'fail',
    );
  }
}

class ReleaseBlocker {
  final String gateId;
  final String severity;
  final String code;
  final String message;

  const ReleaseBlocker({
    required this.gateId,
    required this.severity,
    required this.code,
    required this.message,
  });

  factory ReleaseBlocker.fromJson(Map<String, dynamic> json) {
    return ReleaseBlocker(
      gateId: json['gateId']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'warning',
      code: json['code']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? 'Sin detalle operacional.',
    );
  }
}

class EvidenceCompleteness {
  final double scenarioCoverage;
  final int verifiedArtifacts;
  final int checkedArtifacts;
  final List<String> missingScenarioTypes;

  const EvidenceCompleteness({
    required this.scenarioCoverage,
    required this.verifiedArtifacts,
    required this.checkedArtifacts,
    required this.missingScenarioTypes,
  });

  factory EvidenceCompleteness.fromJson(Map<String, dynamic> json) {
    return EvidenceCompleteness(
      scenarioCoverage: (json['scenarioCoverage'] as num?)?.toDouble() ?? 0,
      verifiedArtifacts: (json['verifiedArtifacts'] as num?)?.toInt() ?? 0,
      checkedArtifacts: (json['checkedArtifacts'] as num?)?.toInt() ?? 0,
      missingScenarioTypes:
          _list(json['missingScenarioTypes'])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];
