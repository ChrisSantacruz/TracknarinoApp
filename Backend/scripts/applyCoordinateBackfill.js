/**
 * Aplica coordenadas revisadas manualmente desde un JSON exportado/editado.
 * Requiere --apply para escribir en base de datos (dry-run por defecto).
 *
 * Formato esperado por ítem en opportunities[]:
 * { "id": "...", "origin": { name, address, coordinates: [lng, lat] }, "destination": { ... } }
 *
 * Uso:
 *   node scripts/applyCoordinateBackfill.js path/to/file.json
 *   node scripts/applyCoordinateBackfill.js path/to/file.json --apply
 */
const fs = require('fs');
const mongoose = require('mongoose');
const { connectMongo } = require('./lib/connectMongo');
const Oportunidad = require('../models/Oportunidad');
const AlertaSeguridad = require('../models/AlertaSeguridad');
const {
  normalizeGeoPoint,
  normalizeLatLngInput,
  evaluateOpportunityGeo,
  evaluateAlertGeo,
} = require('../utils/geoValidation');

async function applyOpportunity(item, dryRun) {
  if (!mongoose.Types.ObjectId.isValid(item.id)) {
    return { id: item.id, status: 'error', reason: 'invalid id' };
  }

  const origin = normalizeGeoPoint(item.origin);
  const destination = normalizeGeoPoint(item.destination);

  if (!origin || !destination) {
    return { id: item.id, status: 'skipped', reason: 'invalid origin/destination payload' };
  }

  const update = {
    origin,
    destination,
    origen: origin.name,
    destino: destination.name,
    direccionCargue: origin.address,
    direccionDescargue: destination.address,
    geoMigration: {
      status: 'resolved',
      source: 'manual',
      routable: true,
      missingFields: [],
      reviewedAt: new Date(),
      notes: item.notes || 'manual backfill',
    },
  };

  const evalCheck = evaluateOpportunityGeo(update);
  if (!evalCheck.routable) {
    return { id: item.id, status: 'skipped', reason: 'route plausibility failed' };
  }

  if (!dryRun) {
    await Oportunidad.findByIdAndUpdate(item.id, { $set: update }, { runValidators: true });
  }

  return { id: item.id, status: dryRun ? 'dry_run_ok' : 'applied' };
}

async function applyAlert(item, dryRun) {
  if (!mongoose.Types.ObjectId.isValid(item.id)) {
    return { id: item.id, status: 'error', reason: 'invalid id' };
  }

  const normalized = normalizeLatLngInput(item.coords || item.coordinates);
  if (!normalized) {
    return { id: item.id, status: 'skipped', reason: 'invalid coordinates' };
  }

  const update = {
    coords: { lat: normalized.lat, lng: normalized.lng },
    coordinates: normalized.coordinates,
    geoMigration: {
      status: 'resolved',
      source: 'manual',
      routable: true,
      missingFields: [],
      reviewedAt: new Date(),
      notes: item.notes || 'manual backfill',
    },
  };

  if (!evaluateAlertGeo(update).routable) {
    return { id: item.id, status: 'skipped', reason: 'alert geo invalid' };
  }

  if (!dryRun) {
    await AlertaSeguridad.findByIdAndUpdate(item.id, { $set: update }, { runValidators: true });
  }

  return { id: item.id, status: dryRun ? 'dry_run_ok' : 'applied' };
}

async function main() {
  const inputPath = process.argv[2];
  const applyFlag = process.argv.includes('--apply');

  if (!inputPath || !fs.existsSync(inputPath)) {
    console.error('Uso: node scripts/applyCoordinateBackfill.js <file.json> [--apply]');
    process.exit(1);
  }

  const payload = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const dryRun = !applyFlag;

  await connectMongo();
  console.log(dryRun ? 'MODO DRY-RUN (sin escritura)' : 'MODO APPLY (escritura activa)');

  const results = { opportunities: [], alerts: [] };

  for (const item of payload.opportunities || []) {
    results.opportunities.push(await applyOpportunity(item, dryRun));
  }

  for (const item of payload.alerts || []) {
    results.alerts.push(await applyAlert(item, dryRun));
  }

  console.log(JSON.stringify(results, null, 2));
  await mongoose.connection.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
