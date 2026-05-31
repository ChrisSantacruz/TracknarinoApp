# Phase 1 + Phase 2 + Phase 4 Implementation Plan

Fecha: 2026-05-30

Estado: auditoria previa obligatoria antes de implementacion funcional.

## Alcance

Este plan cubre la incorporacion de Google Auth, onboarding por rol, nuevo rol `cliente`, ownership de oportunidades, ofertas reales, chat en tiempo real, FCM, calificaciones, evidencia de entrega, tracking publico compartido e historial por rol.

El cambio debe preservar compatibilidad hacia atras con:

- `SyncEngine`
- `RealtimeService`
- `PollingController` y fallback polling existente
- contratos Socket.IO actuales
- cola offline
- persistencia de ruta
- auditoria de ruta
- telemetria de ruta

## Hallazgos de Auditoria

### Google OAuth

El archivo `Backend/Google/client_secret_941456577148-ovde77s6k81sjd05prd4o9itm99p8ivh.apps.googleusercontent.com.json` es una credencial OAuth de tipo `installed`. No es un secreto backend de tipo web y no debe copiarse al cliente Flutter ni tratarse como `GOOGLE_WEB_CLIENT_SECRET`.

La implementacion correcta para mobile es:

1. Flutter obtiene un `idToken` mediante Google Sign-In configurado por plataforma.
2. Backend valida el `idToken` con Google, verificando firma, expiracion, issuer y audiencia.
3. Backend crea o encuentra el usuario por `googleSub` y/o correo verificado.
4. Backend emite JWT propio de TrackNariño.

Variables necesarias:

```env
GOOGLE_CLIENT_IDS=android-client-id.apps.googleusercontent.com,ios-client-id.apps.googleusercontent.com,web-client-id.apps.googleusercontent.com
GOOGLE_ALLOWED_HOSTED_DOMAIN=
```

Flutter debe recibir client IDs mediante `--dart-define` o configuracion nativa, nunca secretos:

```env
GOOGLE_WEB_CLIENT_ID=
GOOGLE_ANDROID_SERVER_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

### Backend Actual

El backend es Node.js + Express + MongoDB + JWT. Las rutas principales estan montadas en `server.js`.

Estado actual relevante:

- `User.tipoUsuario` solo permite `usuario`, `camionero`, `contratista`.
- `User.contraseña` es obligatoria, lo cual bloquea usuarios Google.
- `Oportunidad` requiere `contratista`, por lo que no soporta ownership de cliente.
- `Oportunidad.negociacion` existe como objeto unico, no como lista de ofertas comparables.
- `Calificacion` existe, pero solo modela `camionero` y `contratista`; no esta ligada a viaje ni reputacion agregada confiable.
- FCM existe de forma basica con `deviceToken`, pero simula envio cuando faltan credenciales y no limpia tokens invalidos.
- Socket.IO ya tiene autenticacion JWT, rooms `contractor`, `camionero`, `trip`, `route`, `alerts` y eventos `tracking:location_updated`, `trip:state_changed`, `alert:created`, `route:state_changed`, `route:audit_event`.

### Flutter Actual

Estado actual relevante:

- `AuthService` solo acepta roles `camionero` y `contratista`.
- `AuthWrapper` enruta solo a `CamioneroHomeScreen` y `ContratistaHomeScreen`.
- `LoginScreen` conserva formularios de correo/password y un placeholder de Google.
- `NotificationService` inicializa FCM y foreground messages, pero no registra token refresh ni initial message terminado.
- `RealtimeService` ya maneja reconexion, rooms basicos y streams para tracking, viaje y alertas.

## Arquitectura Propuesta

### Principios

- Persistencia primero, emision Socket.IO despues.
- JWT transporta rol como optimizacion; MongoDB sigue siendo fuente de verdad.
- `cliente` se agrega sin eliminar `contratista` ni endpoints historicos.
- `contratista` legacy se mantiene como alias de owner para oportunidades antiguas.
- Las nuevas capacidades se agregan en servicios/controladores especificos para no agrandar controladores existentes.
- No se introduce Firebase Chat. Chat usa MongoDB + Socket.IO existente.

### Flujo de Autenticacion

1. Pantalla inicial: boton principal `Continuar con Google`.
2. Flutter ejecuta Google Sign-In.
3. Flutter envia `idToken` a `POST /api/auth/google`.
4. Backend valida token con audiencias permitidas.
5. Backend crea usuario si no existe:
   - `nombre`
   - `correo`
   - `fotoPerfil`
   - `authProvider: google`
   - `googleSub`
   - `tipoUsuario: usuario`
   - `rolConfigurado: false`
6. Flutter detecta `rolConfigurado: false` y muestra onboarding.
7. Usuario elige `camionero`, `contratista` o `cliente`.
8. Flutter llama `PUT /api/auth/role`.
9. Backend valida transicion y actualiza rol.
10. Flutter entra automaticamente al dashboard correspondiente.

### Roles y Permisos

Nuevo enum:

```text
usuario
camionero
contratista
cliente
```

`usuario` queda como estado transitorio sin permisos operativos.

`cliente` puede crear cargas, publicar oportunidades, ver ofertas, aceptar/rechazar ofertas, ver viaje, camionero asignado, ubicacion realtime autorizada, alertas relacionadas, historial y calificar.

`cliente` no puede tomar viajes, conducir, gestionar vehiculos ni administrar flota.

## Modelos Nuevos o Modificados

### `User`

Campos nuevos:

```js
authProvider: 'password' | 'google'
googleSub: String
fotoPerfil: String
rolConfigurado: Boolean
reputation: {
  promedio: Number,
  total: Number,
  totalViajes: Number,
  totalContrataciones: Number,
  totalOperaciones: Number
}
fcmTokens: [{
  token: String,
  platform: String,
  lastSeenAt: Date,
  invalidatedAt: Date
}]
```

Compatibilidad:

- Mantener `deviceToken` por compatibilidad.
- `contraseña` solo obligatoria cuando `authProvider === 'password'`.

### `Oportunidad`

Campos nuevos:

```js
ownerType: 'CLIENTE' | 'CONTRATISTA'
ownerId: ObjectId<User>
createdBy: ObjectId<User>
createdByRole: 'cliente' | 'contratista'
trackingId: String
sharedTrackingEnabled: Boolean
deliveryEvidence: {
  photos: [String],
  observations: String,
  deliveredAt: Date,
  location: {
    lat: Number,
    lng: Number
  },
  signatureName: String
}
```

Compatibilidad:

- `contratista` permanece requerido para documentos legacy solo mientras se migra.
- Para oportunidades creadas por cliente, `contratista` puede apuntar al owner cliente temporalmente solo si se relaja `required` o se ajustan controladores antiguos. La ruta recomendada es hacer `contratista` no requerido y actualizar queries.
- Listados antiguos que filtran por `contratista` deben ampliar filtro a `ownerId`.

### `Offer`

Modelo nuevo para negociacion real:

```js
oportunidad: ObjectId<Oportunidad>
camionero: ObjectId<User>
owner: ObjectId<User>
ownerType: 'CLIENTE' | 'CONTRATISTA'
precio: Number
comentario: String
estado: 'pendiente' | 'aceptada' | 'rechazada' | 'retirada'
respondedAt: Date
createdAt: Date
updatedAt: Date
```

Compatibilidad:

- `Oportunidad.negociacion` puede seguir existiendo como resumen de la ultima oferta para pantallas actuales.
- La fuente de verdad nueva es `Offer`.

### `ChatMessage`

Modelo nuevo:

```js
trip: ObjectId<Oportunidad>
sender: ObjectId<User>
senderRole: 'cliente' | 'contratista' | 'camionero'
message: String
deliveredTo: [{ user: ObjectId<User>, deliveredAt: Date }]
readBy: [{ user: ObjectId<User>, readAt: Date }]
createdAt: Date
```

### `Rating`

Reemplazo funcional de `Calificacion` o evolucion compatible:

```js
trip: ObjectId<Oportunidad>
rater: ObjectId<User>
ratedUser: ObjectId<User>
raterRole: String
ratedRole: 'cliente' | 'contratista' | 'camionero'
stars: Number
comment: String
createdAt: Date
```

Regla: una calificacion por `trip + rater + ratedUser`.

## Endpoints Nuevos

### Auth

- `POST /api/auth/google`
- `PUT /api/auth/role`

### Oportunidades

- `GET /api/oportunidades?ownerType=CLIENTE|CONTRATISTA|all`
- `GET /api/oportunidades/:id`
- `POST /api/oportunidades/:id/offers`
- `GET /api/oportunidades/:id/offers`
- `PUT /api/offers/:offerId/accept`
- `PUT /api/offers/:offerId/reject`

Las rutas legacy `/oferta` se mantienen y delegan al nuevo servicio de ofertas.

### Chat

- `GET /api/trips/:tripId/chat`
- `POST /api/trips/:tripId/chat`
- `PUT /api/trips/:tripId/chat/read`

### Notificaciones

- `POST /api/notificaciones/registrar-token`
- `DELETE /api/notificaciones/token`

`registrar-token` debe seguir aceptando `{ token }` para compatibilidad y aceptar `{ token, platform }` para el flujo nuevo.

### Calificaciones

- `POST /api/trips/:tripId/ratings`
- `GET /api/users/:userId/reputation`

### Evidencia

- `POST /api/trips/:tripId/delivery-evidence`
- `GET /api/trips/:tripId/delivery-evidence`

### Tracking Compartido

- `POST /api/trips/:tripId/share`
- `DELETE /api/trips/:tripId/share`
- `GET /api/tracking/shared/:trackingId`

La ruta publica no requiere login y solo devuelve datos de solo lectura.

## Sockets Nuevos

Eventos existentes se conservan.

Eventos agregados:

```text
chat:join
chat:message
chat:message_created
chat:delivered
chat:read
offer:created
offer:accepted
offer:rejected
```

Rooms agregados:

```text
client:<clienteId>
chat:<tripId>
```

Reglas:

- `cliente` puede unirse a `trip:<id>` y `chat:<id>` si es owner o esta relacionado con el viaje.
- `contratista` conserva `contractor:<id>`.
- `camionero` conserva `camionero:<id>`.
- Los eventos de tracking deben emitir tambien a `client:<id>` cuando el owner sea cliente.

## Migraciones Necesarias

1. Usuarios:
   - Agregar campos Google y reputacion con defaults.
   - Marcar usuarios existentes como `authProvider: password`, `rolConfigurado: true`.
2. Oportunidades:
   - Para documentos con `contratista`, setear `ownerType: CONTRATISTA`, `ownerId: contratista`, `createdBy: contratista`, `createdByRole: contratista`.
   - Generar `trackingId` solo cuando se habilite compartir viaje.
3. Ofertas:
   - Migrar `negociacion` activa a `Offer` cuando exista `negociacion.camionero`.
4. Calificaciones:
   - Mantener coleccion `calificaciones` legacy y crear indices para el modelo nuevo.
5. FCM:
   - Copiar `deviceToken` a `fcmTokens[0]` cuando exista.

## Riesgos

- Google Auth no se puede validar completamente sin client IDs reales de Android/iOS/Web configurados en Google Cloud.
- FCM no sera funcional en entornos sin `firebase-key.json` o credenciales por variable de entorno.
- El contrato actual de oportunidades asume `contratista` requerido; cambiarlo sin actualizar filtros rompe dashboards.
- La negociacion actual permite una sola oferta; pasar a multiples ofertas requiere ajustar UI de contratista/cliente para comparar.
- Tracking publico debe minimizar datos para no exponer PII ni informacion operacional sensible.
- Evidencia con fotos requiere flujo dedicado de subida. Con `express.json({ limit: '1mb' })`, no conviene enviar base64 pesado por JSON.
- El chat debe persistir antes de emitir; si se emite antes de guardar, se rompe confiabilidad en reconexion.

## Orden de Implementacion

1. Backend base compatible:
   - `User` con `cliente`, Google fields, reputacion y tokens FCM.
   - Auth Google + seleccion de rol.
   - Middleware de ownership.
2. Oportunidades y ofertas:
   - `ownerType`, `ownerId`, filtros.
   - Modelo `Offer`.
   - Rutas nuevas y adaptadores legacy.
3. Realtime:
   - Rooms `client` y `chat`.
   - Eventos de oferta y chat.
   - Extender fanout de tracking/trip sin romper nombres actuales.
4. Cliente Flutter:
   - Login Google.
   - Onboarding de rol.
   - Dashboard cliente.
   - Servicios para ofertas, chat, tracking compartido, evidencia y calificaciones.
5. Push:
   - Token refresh, initial message, foreground/background.
   - Limpieza de tokens invalidos en backend.
6. Validacion:
   - `node --check` en archivos modificados.
   - `flutter analyze`.
   - `flutter test`.

## Criterios de Aceptacion

- Una cuenta Google nueva entra a onboarding y queda con rol operativo.
- `cliente` puede crear oportunidad y ver "Publicado por Cliente".
- `contratista` conserva sus oportunidades antiguas.
- `camionero` puede ofertar precio con comentario.
- Owner cliente/contratista puede aceptar o rechazar ofertas.
- Aceptar oferta crea/asigna viaje y dispara Socket.IO + FCM.
- Chat persiste historial y emite mensajes por Socket.IO.
- Tracking realtime funciona para cliente, contratista y camionero autorizados.
- Link `/tracking/shared/{trackingId}` es publico, solo lectura y sin datos sensibles innecesarios.
- No se rompen eventos Socket.IO existentes ni flujo offline de acciones de viaje.
