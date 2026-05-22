const RELEASE_GATES = Object.freeze([
  {
    id: 'deployment_blockers',
    category: 'deployment_readiness',
    severity: 'critical',
    evidenceRequired: ['environment_snapshot', 'healthcheck_snapshot'],
  },
  {
    id: 'dependency_vulnerability',
    category: 'deployment_readiness',
    severity: 'critical',
    evidenceRequired: ['dependency_audit'],
  },
  {
    id: 'missing_index',
    category: 'geospatial_readiness',
    severity: 'critical',
    evidenceRequired: ['mongo_index_snapshot'],
  },
  {
    id: 'redis_readiness',
    category: 'scaling_readiness',
    severity: 'critical',
    evidenceRequired: ['redis_ping_snapshot'],
  },
  {
    id: 'socket_io_scaling',
    category: 'realtime_stability',
    severity: 'critical',
    evidenceRequired: ['socket_scaling_snapshot', 'sticky_session_policy'],
  },
  {
    id: 'offline_replay_integrity',
    category: 'offline_recovery',
    severity: 'critical',
    evidenceRequired: ['offline_replay_recovery'],
  },
  {
    id: 'route_persistence_integrity',
    category: 'route_reliability',
    severity: 'critical',
    evidenceRequired: ['route_persistence_snapshot'],
  },
  {
    id: 'operational_regression',
    category: 'operational_observability',
    severity: 'warning',
    evidenceRequired: ['regression_baseline'],
  },
  {
    id: 'evidence_completeness',
    category: 'evidence_completeness',
    severity: 'critical',
    evidenceRequired: ['release_evidence_manifest'],
  },
]);

const READINESS_CATEGORIES = Object.freeze([
  'realtime_stability',
  'offline_recovery',
  'route_reliability',
  'provider_stability',
  'replay_integrity',
  'operational_observability',
  'deployment_readiness',
  'geospatial_readiness',
  'scaling_readiness',
  'evidence_completeness',
]);

module.exports = {
  RELEASE_GATES,
  READINESS_CATEGORIES,
};
