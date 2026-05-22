/**
 * Exporta registros sin coordenadas resueltas para recuperación manual.
 * No modifica coordenadas.
 *
 * Uso: node scripts/exportUnresolvedCoordinates.js [output.json]
 */
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { connectMongo } = require('./lib/connectMongo');
const Oportunidad = require('../models/Oportunidad');
const AlertaSeguridad = require('../models/AlertaSeguridad');
const { evaluateOpportunityGeo, evaluateAlertGeo } = require('../utils/geoValidation');

async function main() {
  const outputPath = process.argv[2]
    || path.join(__dirname, 'output', `unresolved-coordinates-${Date.now()}.json`);

  await connectMongo();

  const unresolvedOpportunities = [];
  const oportunidades = await Oportunidad.find({
    $or: [
      { 'geoMigration.status': { $in: ['unresolved', 'pending', 'manual_review'] } },
      { 'origin.coordinates': { $exists: false } },
      { 'destination.coordinates': { $exists: false } },
    ],
  });

  for (const opp of oportunidades) {
    const evalResult = evaluateOpportunityGeo(opp);
    if (evalResult.status === 'resolved' && evalResult.routable) continue;

    unresolvedOpportunities.push({
      collection: 'oportunidades',
      id: opp._id.toString(),
      titulo: opp.titulo,
      origen: opp.origen,
      destino: opp.destino,
      direccionCargue: opp.direccionCargue,
      direccionDescargue: opp.direccionDescargue,
      geoMigration: opp.geoMigration,
      missingFields: evalResult.missingFields,
      manualRecoveryTemplate: {
        origin: {
          name: opp.origen || '',
          address: opp.direccionCargue || '',
          coordinates: null,
        },
        destination: {
          name: opp.destino || '',
          address: opp.direccionDescargue || '',
          coordinates: null,
        },
      },
    });
  }

  const unresolvedAlerts = [];
  const alertas = await AlertaSeguridad.find({
    $or: [
      { 'geoMigration.status': { $in: ['unresolved', 'pending'] } },
      { coordinates: { $exists: false } },
    ],
  });

  for (const alerta of alertas) {
    const evalResult = evaluateAlertGeo(alerta);
    if (evalResult.status === 'resolved') continue;

    unresolvedAlerts.push({
      collection: 'alertas',
      id: alerta._id.toString(),
      tipo: alerta.tipo,
      descripcion: alerta.descripcion,
      coords: alerta.coords,
      geoMigration: alerta.geoMigration,
      missingFields: evalResult.missingFields,
      manualRecoveryTemplate: {
        coordinates: null,
        coords: { lat: null, lng: null },
      },
    });
  }

  const report = {
    exportedAt: new Date().toISOString(),
    instructions: 'Completar coordinates manualmente. NO adivinar desde nombres de ciudad.',
    counts: {
      opportunities: unresolvedOpportunities.length,
      alerts: unresolvedAlerts.length,
    },
    opportunities: unresolvedOpportunities,
    alerts: unresolvedAlerts,
  };

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2), 'utf8');

  console.log(`Exportado: ${outputPath}`);
  console.log(JSON.stringify(report.counts, null, 2));

  await mongoose.connection.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
