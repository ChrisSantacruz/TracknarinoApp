const polyline = require('@mapbox/polyline');
const crypto = require('crypto');
const { requestRouteFromProvider } = require('./routingProviderPolicy');
const { calculateGeometryHash, calculateRouteBbox } = require('./routeGeometryService');

/**
 * Servicio para calcular rutas usando el proveedor configurado.
 * Mantiene el contrato histórico de /api/ors/ruta y agrega diagnósticos seguros.
 */

/**
 * Obtiene la ruta óptima entre dos puntos usando OSRM
 * @param {Array} origen - [longitud, latitud] del punto de origen
 * @param {Array} destino - [longitud, latitud] del punto de destino
 * @returns {Object} Información de la ruta: coordinates, distancia, duración
 */
async function obtenerRutaORS(origen, destino, options = {}) {
  const correlationId = options.correlationId || crypto.randomUUID();
  try {
    // Validar coordenadas
    if (!Array.isArray(origen) || origen.length !== 2) {
      throw new Error('Origen debe ser un array [lng, lat]');
    }
    if (!Array.isArray(destino) || destino.length !== 2) {
      throw new Error('Destino debe ser un array [lng, lat]');
    }

    const providerResult = await requestRouteFromProvider({ origen, destino, correlationId });
    const { response, provider, diagnostics } = providerResult;

    if (!response.data) {
      throw new Error('OSRM no devolvió datos');
    }

    if (response.data.code !== 'Ok') {
      throw new Error(`OSRM error: ${response.data.code}`);
    }

    if (!response.data.routes || response.data.routes.length === 0) {
      throw new Error('No se encontró una ruta válida en OSRM');
    }

    const route = response.data.routes[0];
    
    // Decodificar la geometría polyline a coordenadas [lng, lat]
    const decodedCoordinates = polyline.decode(route.geometry);
    
    // OSRM devuelve [lat, lng], convertir a [lng, lat] para consistencia
    const coordinates_lnglat = decodedCoordinates.map(coord => [coord[1], coord[0]]);

    const resultado = {
      coordinates: coordinates_lnglat,
      distancia: (route.distance / 1000).toFixed(2), // Convertir metros a km
      duracion: Math.round(route.duration / 60), // Convertir segundos a minutos
      numeroDetalles: coordinates_lnglat.length, // Número de puntos en la ruta
      provider,
      geometryHash: calculateGeometryHash(coordinates_lnglat),
      routeSummary: {
        pointCount: coordinates_lnglat.length,
        bbox: calculateRouteBbox(coordinates_lnglat),
      },
      diagnostics,
      correlationId,
    };

    return resultado;

  } catch (error) {
    return {
      error: 'No se pudo obtener una ruta real desde OSRM',
      provider: error.provider,
      providerHealth: error.providerHealth,
      correlationId,
    };
  }
}

module.exports = {
  obtenerRutaORS,
};
