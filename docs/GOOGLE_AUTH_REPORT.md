# Google Auth Report

Fecha: 2026-05-30

## Estado

Se implemento autenticacion Google Sign-In sin Firebase Auth, con verificacion backend.

## Auditoria de Credencial

El archivo `Backend/Google/client_secret_941456577148-ovde77s6k81sjd05prd4o9itm99p8ivh.apps.googleusercontent.com.json` es OAuth `installed`. No es secreto web de backend y no debe hardcodearse en Flutter.

## Backend

- Nuevo endpoint `POST /api/auth/google`.
- Nuevo endpoint `PUT /api/auth/role`.
- `google-auth-library` valida `idToken` con `verifyIdToken`.
- Audiencias permitidas vienen de `GOOGLE_CLIENT_IDS`.
- `GOOGLE_OAUTH_CLIENT_CONFIG` apunta al JSON OAuth local y el backend puede leer su `client_id` como respaldo.
- Se exige `email_verified === true`.
- Se guarda `authProvider`, `googleSub`, `fotoPerfil` y `rolConfigurado`.

## Flutter

- Se agrego `google_sign_in`.
- La app usa `google_sign_in: ^6.2.1`.
- `LoginScreen` muestra `Continuar con Google`.
- `AuthService.signInWithGoogle()` envia `idToken` al backend.
- `RoleSelectionScreen` guarda `camionero`, `contratista` o `cliente`.

## Variables

Backend:

```env
GOOGLE_CLIENT_IDS=
GOOGLE_OAUTH_CLIENT_CONFIG=
GOOGLE_ALLOWED_HOSTED_DOMAIN=
```

Flutter:

```env
GOOGLE_WEB_CLIENT_ID=
GOOGLE_ANDROID_SERVER_CLIENT_ID=
GOOGLE_IOS_CLIENT_ID=
```

## Riesgo Pendiente

Google Auth requiere client IDs reales por plataforma configurados en Google Cloud para validar en dispositivo fisico.
