# Push Notifications Report

Fecha: 2026-05-30

## Estado

Se reforzo FCM para tokens multiples, token refresh y limpieza de tokens invalidos.

## Backend

- `User.fcmTokens[]` guarda token, plataforma, ultima vista e invalidacion.
- `deviceToken` se conserva por compatibilidad.
- `POST /api/notificaciones/registrar-token` acepta `{ token, platform }`.
- `DELETE /api/notificaciones/token` elimina tokens.
- `fcmService` soporta `FIREBASE_SERVICE_ACCOUNT_JSON` o `config/firebase-key.json`.
- Tokens invalidos se marcan con `invalidatedAt`.

## Flutter

- `NotificationService` registra token inicial.
- Escucha `onTokenRefresh`.
- Maneja foreground, background tap y terminated initial message.

## Eventos Cubiertos

La infraestructura permite enviar:

- nueva oferta
- oferta aceptada
- viaje asignado
- alerta critica
- mensaje recibido
- llegada a destino

## Riesgo Pendiente

FCM solo envia realmente cuando hay credenciales Firebase Admin validas. Sin credenciales, el servicio devuelve `FCM_DISABLED` sin simular envios.
