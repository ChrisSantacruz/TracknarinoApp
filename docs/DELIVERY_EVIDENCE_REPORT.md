# Delivery Evidence Report

Fecha: 2026-05-30

## Estado

Se agrego evidencia de entrega embebida en `Oportunidad`.

## Campos

- `photos`
- `observations`
- `deliveredAt`
- `location.lat`
- `location.lng`
- `signatureName`

## Endpoints

- `POST /api/trips/:tripId/delivery-evidence`
- `GET /api/trips/:tripId/delivery-evidence`

## Seguridad

Solo el propietario de la carga o el camionero asignado pueden registrar o consultar evidencia.

## Nota Operativa

No se agrego servicio externo. Las fotos se almacenan como referencias string. El backend mantiene `express.json({ limit: '1mb' })`, por lo que imagenes pesadas deben subirse por flujo dedicado en una fase posterior si se requiere binario.
