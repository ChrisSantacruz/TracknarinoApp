# Rating System Report

Fecha: 2026-05-30

## Estado

Se agrego reputacion por viaje y se mantuvo compatibilidad con `Calificacion`.

## Modelo

Nuevo modelo `Rating`:

- `trip`
- `rater`
- `ratedUser`
- `raterRole`
- `ratedRole`
- `stars`
- `comment`

## Endpoint

- `POST /api/trips/:tripId/ratings`
- `GET /api/users/:id/reputation`

## Reglas

- Solo se califican viajes `entregada`.
- Escala de 1 a 5.
- Comentario opcional.
- No se permite autocalificacion.
- Un usuario solo puede calificar una vez al mismo usuario por viaje.

## Agregados

El promedio y total se actualizan en `User.reputation` y `User.calificacion` para compatibilidad con UI existente.
