# Realtime Chat Report

Fecha: 2026-05-30

## Estado

Se agrego chat persistido con Socket.IO existente. No se usa Firebase Chat.

## Modelo

Nuevo modelo `ChatMessage`:

- `trip`
- `sender`
- `senderRole`
- `message`
- `deliveredTo`
- `readBy`
- `createdAt`

## REST

- `GET /api/trips/:tripId/chat`
- `POST /api/trips/:tripId/chat`
- `PUT /api/trips/:tripId/chat/read`

## Socket.IO

Eventos agregados:

- `chat:join`
- `chat:message`
- `chat:message_created`
- `chat:delivered`
- `chat:read`

Rooms agregados:

- `client:<clienteId>`
- `chat:<tripId>`

## Seguridad

Antes de unirse a `trip` o `chat`, el backend valida que el usuario sea propietario cliente/contratista o camionero asignado.

## Compatibilidad

No se removieron eventos existentes de tracking, trip, alertas, rutas, auditoria ni telemetria.
