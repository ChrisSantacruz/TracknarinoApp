# Google Auth Implementation Plan

Fecha: 2026-05-30

Estado: plan técnico previo a implementación.

## Diagnóstico del Archivo Existente

Archivo auditado:

`Backend/Google/client_secret_941456577148-ovde77s6k81sjd05prd4o9itm99p8ivh.apps.googleusercontent.com.json`

Contenido relevante:

```json
{
  "installed": {
    "client_id": "941456577148-ovde77s6k81sjd05prd4o9itm99p8ivh.apps.googleusercontent.com",
    "project_id": "silken-math-498000-g3",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
  }
}
```

Conclusión:

- Es un cliente OAuth tipo `installed`.
- No corresponde a un cliente OAuth Web.
- No corresponde específicamente a Android ni iOS.
- No debe tratarse como secreto backend.
- No debe hardcodearse en Flutter.
- Debe reemplazarse por configuración por plataforma y variables de entorno.

## Principio de Seguridad

TrackNariño no debe usar el archivo JSON como fuente de credenciales en producción. El backend debe aceptar un `id_token` emitido por Google, validar firma y audiencia contra client IDs permitidos, crear/encontrar el usuario y emitir el JWT propio de TrackNariño.

El frontend nunca debe enviar un rol confiable sin validación. El rol elegido tras Google debe guardarse en backend con reglas de transición.

## Dependencias Propuestas

### Flutter

Agregar, previa aprobación:

```yaml
google_sign_in: <latest compatible>
```

La documentación actual del paquete `google_sign_in` indica inicializar Google Sign-In una sola vez con `clientId` y/o `serverClientId`, escuchar `authenticationEvents` y usar `authenticate()` para iniciar el flujo interactivo.

### Backend

Agregar, previa aprobación:

```json
"google-auth-library": "<latest>"
```

La documentación oficial de `google-auth-library` para Node.js usa `OAuth2Client.verifyIdToken({ idToken, audience })` para validar firma y audiencia antes de confiar en `email`, `sub`, `name` o `picture`.

## Variables de Entorno

### Backend `.env`

Agregar a `.env.example` cuando se implemente:

```env
GOOGLE_CLIENT_IDS=android-client-id.apps.googleusercontent.com,ios-client-id.apps.googleusercontent.com,web-client-id.apps.googleusercontent.com
GOOGLE_ALLOWED_HOSTED_DOMAIN=
```

Opcional si se decide usar auth code para flujos web/server:

```env
GOOGLE_WEB_CLIENT_ID=web-client-id.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_SECRET=
```

Regla: `GOOGLE_WEB_CLIENT_SECRET` solo aplica a OAuth Web. No aplica al archivo `installed` auditado.

### Flutter `--dart-define`

```bash
--dart-define=GOOGLE_WEB_CLIENT_ID=...
--dart-define=GOOGLE_ANDROID_SERVER_CLIENT_ID=...
--dart-define=GOOGLE_IOS_CLIENT_ID=...
```

No deben existir client IDs escritos directamente en código Dart.

## Configuración por Plataforma

### Android

Requiere un OAuth Client de tipo Android en Google Cloud:

- Package name real de la app.
- SHA-1/SHA-256 de debug y release.
- `google-services.json` si se usa Firebase/Google Services.

Estado actual:

- `AndroidManifest.xml` no tiene configuración específica de Google Sign-In.
- El nombre visible aún es `trackarino_app`.
- Se debe verificar `applicationId` en Gradle antes de crear el client ID Android.

Recomendación:

1. Crear OAuth Android client con package definitivo.
2. Configurar Firebase si se mantiene FCM.
3. Usar `serverClientId` apuntando al Web client ID si el plugin/plataforma lo requiere para obtener tokens válidos para backend.

### iOS

Requiere OAuth Client de tipo iOS:

- Bundle ID real.
- URL scheme reverso del client ID si el paquete lo requiere.
- Configuración en `Info.plist`.

Estado actual:

- `Info.plist` no contiene URL schemes de Google.
- `CFBundleDisplayName` dice `Trackarino App`.

Recomendación:

1. Definir bundle ID definitivo.
2. Crear OAuth iOS client.
3. Agregar URL scheme y configuración requerida.
4. Mantener client IDs por `--dart-define` o configuración generada segura.

### Web

Requiere OAuth Client de tipo Web:

- Orígenes autorizados: dominio web/staging/local.
- Redirect URIs si se usa flujo redirect.

Estado actual:

- Flutter Web inicializa Firebase con `--dart-define`.
- Si faltan defines, puede fallar bootstrap.

Recomendación:

1. Crear OAuth Web client.
2. Configurar `GOOGLE_WEB_CLIENT_ID`.
3. Validar `id_token` en backend con audiencia web.

## Flujo Propuesto

1. Usuario toca `Continuar con Google`.
2. Flutter inicializa `GoogleSignIn` con client IDs por plataforma.
3. Flutter ejecuta `authenticate()`.
4. Flutter obtiene `id_token` y perfil básico disponible:
   - Nombre
   - Correo
   - Foto
5. Flutter envía al backend:

```json
{
  "idToken": "...",
  "platform": "android|ios|web"
}
```

6. Backend valida:
   - Firma Google.
   - `aud` dentro de `GOOGLE_CLIENT_IDS`.
   - `email_verified === true`.
   - Dominio permitido si se configura.
7. Backend busca usuario por `googleSub` o `correo`.
8. Si no existe, crea usuario con:
   - `nombre`
   - `correo`
   - `fotoPerfil`
   - `googleSub`
   - `tipoUsuario` pendiente o `rolPendiente`
9. Backend emite JWT TrackNariño.
10. Flutter detecta si falta rol operativo.
11. Flutter muestra:

```text
¿Cómo usarás TrackNariño?

- Camionero
- Contratista
- Cliente
```

12. Flutter envía selección al backend.
13. Backend guarda el rol con validaciones.
14. Flutter entra directamente a la app.

## Cambios Backend Propuestos

### Modelo `User`

Agregar campos:

```js
authProvider: { type: String, enum: ['password', 'google'], default: 'password' }
googleSub: { type: String, unique: true, sparse: true }
fotoPerfil: { type: String, default: '' }
rolConfigurado: { type: Boolean, default: false }
```

Actualizar enum:

```js
tipoUsuario: ['usuario', 'camionero', 'contratista', 'cliente']
```

No eliminar `contraseña` inmediatamente. Para usuarios Google, debe dejar de ser requerida si `authProvider === 'google'`.

### Rutas

Agregar:

```http
POST /api/auth/google
PUT /api/auth/seleccionar-rol
```

Mantener:

```http
POST /api/auth/login
POST /api/auth/register
GET /api/auth/perfil
```

No romper APIs existentes.

### Validaciones

- No aceptar roles fuera de enum.
- No permitir que un usuario cambie de rol libremente si ya tiene operación asociada.
- No confiar en datos del frontend si contradicen el token de Google.
- Si el correo ya existe con password, vincular Google solo con política explícita.

## Cambios Flutter Propuestos

### Servicios

Crear o extender `AuthService`:

```dart
Future<AuthResult> loginWithGoogle();
Future<void> seleccionarRol(TipoUsuario rol);
```

Agregar configuración:

```dart
static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
static const googleAndroidServerClientId = String.fromEnvironment('GOOGLE_ANDROID_SERVER_CLIENT_ID');
static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
```

### Pantallas

- Reemplazar placeholder en login por botón real.
- Agregar pantalla `RoleSelectionScreen`.
- Actualizar `AuthWrapper` para permitir usuario autenticado sin rol configurado.
- Agregar navegación para `cliente`.

## Riesgos

| Severidad | Riesgo | Mitigación |
|---|---|---|
| CRÍTICO | Usar client JSON `installed` como secreto backend | No usarlo; configurar client IDs por env |
| CRÍTICO | Aceptar tokens sin validar audiencia | Usar `verifyIdToken` con `GOOGLE_CLIENT_IDS` |
| ALTO | Crear usuarios duplicados por correo | Índice único y estrategia de vinculación |
| ALTO | Flutter Web sin defines | Validar config al inicio con errores claros |
| ALTO | Rol elegido desde cliente sin autorización | Endpoint dedicado y validación backend |
| MEDIO | Usuarios existentes con password | Mantener compatibilidad y documentar vinculación |

## Criterios de Aceptación

- Login Google funciona en Android con client ID correcto.
- Login Google funciona en iOS con bundle ID correcto.
- Login Google funciona en Web si se habilita Flutter Web.
- Backend valida `id_token` y nunca confía en datos no verificados.
- Usuario nuevo entra sin formulario largo.
- Usuario selecciona `Camionero`, `Contratista` o `Cliente`.
- Rol queda persistido.
- JWT TrackNariño conserva compatibilidad con middleware actual.
- No se hardcodean credenciales.
- No se elimina SyncEngine, RealtimeService ni PollingController.
