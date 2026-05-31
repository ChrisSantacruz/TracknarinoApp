# Offer System Report

Fecha: 2026-05-30

## Estado

Se implemento negociacion persistida basada en ofertas.

## Modelo

Nuevo modelo `Offer`:

- `oportunidad`
- `camionero`
- `owner`
- `ownerType`
- `precio`
- `comentario`
- `estado`
- `respondedAt`

## Endpoints

- `POST /api/oportunidades/:id/offers`
- `GET /api/oportunidades/:id/offers`
- `PUT /api/oportunidades/offers/:offerId/accept`
- `PUT /api/oportunidades/offers/:offerId/reject`

## Compatibilidad

Las rutas legacy de `/:id/oferta` se mantienen. `Oportunidad.negociacion` queda como resumen compatible para pantallas existentes; la fuente de verdad nueva es `Offer`.

## Realtime y Push

Aceptar o rechazar oferta emite:

- `offer:created`
- `offer:accepted`
- `offer:rejected`

Tambien intenta enviar FCM al actor correspondiente si hay token valido.
