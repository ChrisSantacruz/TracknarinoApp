/**
 * Audita coordenadas en oportunidades y alertas.
 * No inventa coordenadas. Solo marca estado de migración.
 *
 * Uso: node scripts/auditCoordinates.js
 */
const path = require('path');
const mongoose = require('mongoose');
const { connectMongo } = require('./lib/connectMongo');
const Oportunidad = require('../models/Oportunidad');
const AlertaSeguridad = require('../models/AlertaSeguridad');
const UbicacionActual = require('../models/UbicacionActual');
const Ubicacion = require('../models/Ubicacion');
const {
  evaluateOpportunityGeo,
  evaluateAlertGeo,
  normalizeCoordinatePair,
} = require('../utils/geoValidation');

async function auditOpportunities() {
  const oportunidades = await Oportunidad.find({});
  const summary = { total: 0, resolved: 0, unresolved: 0, pending: 0, updated: 0 };

  for (const opp of oportunidades) {
    summary.total += 1;
    const evalResult = evaluateOpportunityGeo(opp);
    if (!opp.geoMigration) opp.geoMigration = {};
    opp.geoMigration.status = evalResult.status;
    opp.geoMigration.missingFields = evalResult.missingFields;
    opp.geoMigration.routable = evalResult.routable;
    if (!opp.geoMigration.source) opp.geoMigration.source = 'legacy';
    opp.geoMigration.reviewedAt = new Date();
    await opp.save();
    summary[evalResult.status] = (summary[evalResult.status] || 0) + 1;
    summary.updated += 1;
  }

  return summary;
}

async function auditAlerts() {
  const alertas = await AlertaSeguridad.find({});
  const summary = { total: 0, resolved: 0, unresolved: 0, pending: 0, updated: 0 };

  for (const alerta of alertas) {
    summary.total += 1;
    let evalResult = evaluateAlertGeo(alerta);

    if (evalResult.status !== 'resolved' && alerta.coords?.lat != null && alerta.coords?.lng != null) {
      const backfill = normalizeCoordinatePair([alerta.coords.lng, alerta.coords.lat]);
      if (backfill) {
        alerta.coordinates = backfill.coordinates;
        evalResult = evaluateAlertGeo(alerta);
        if (!alerta.geoMigration) alerta.geoMigration = {};
        alerta.geoMigration.source = 'script';
        alerta.geoMigration.notes = 'coordinates backfilled from coords';
      }
    }

    if (!alerta.geoMigration) alerta.geoMigration = {};
    alerta.geoMigration.status = evalResult.status;
    alerta.geoMigration.missingFields = evalResult.missingFields;
    alerta.geoMigration.routable = evalResult.routable;
    if (!alerta.geoMigration.source) alerta.geoMigration.source = 'legacy';
    alerta.geoMigration.reviewedAt = new Date();
    await alerta.save();
    summary[evalResult.status] = (summary[evalResult.status] || 0) + 1;
    summary.updated += 1;
  }

  return summary;
}

async function auditLatestLocations() {
  const camioneros = await Ubicacion.distinct('camionero');
  let synced = 0;
  let skipped = 0;

  for (const camioneroId of camioneros) {
    const exists = await UbicacionActual.exists({ camionero: camioneroId });
    if (exists) {
      skipped += 1;
      continue;
    }

    const latest = await Ubicacion.findOne({ camionero: camioneroId })
      .sort({ timestamp: -1 });

    if (!latest) continue;

    await UbicacionActual.findOneAndUpdate(
      { camionero: camioneroId },
      { $set: latest.toObject() },
      { upsert: true, runValidators: true },
    );
    synced += 1;
  }

  return { camionerosWithHistory: camioneros.length, synced, skipped };
}

async function main() {
  const uri = await connectMongo();
  console.log(`Conectado: ${uri}\n`);

  const oppSummary = await auditOpportunities();
  const alertSummary = await auditAlerts();
  const latestSummary = await auditLatestLocations();

  console.log('=== Oportunidades ===');
  console.log(JSON.stringify(oppSummary, null, 2));
  console.log('\n=== Alertas ===');
  console.log(JSON.stringify(alertSummary, null, 2));
  console.log('\n=== UbicacionActual sync desde historial ===');
  console.log(JSON.stringify(latestSummary, null, 2));

  await mongoose.connection.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
