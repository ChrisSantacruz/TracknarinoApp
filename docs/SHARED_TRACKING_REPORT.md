# Shared Tracking Report

Fecha: 2026-05-30

## Estado

Se agrego seguimiento publico compartido de solo lectura.

## Endpoints

- `POST /api/trips/:tripId/share`
- `DELETE /api/trips/:tripId/share`
- `GET /api/tracking/shared/:trackingId`

## Datos Publicos

La respuesta publica incluye:

- `trackingId`
- titulo
- estado
- origen
- destino
- ubicacion actual del camionero asignado
- ultima actualizacion

## Seguridad

La ruta publica no requiere login, pero solo funciona si `sharedTrackingEnabled` esta activo. El `trackingId` se genera con bytes aleatorios y no expone IDs internos en el link.

## Compatibilidad

El tracking publico lee `UbicacionActual`; no modifica `RealtimeService`, `Route Persistence`, `Route Audit` ni `Route Telemetry`.
