# Client Role Report

Fecha: 2026-05-30

## Estado

Se agrego el rol operativo `cliente` manteniendo compatibilidad con `camionero`, `contratista` y el estado transitorio `usuario`.

## Backend

- `User.tipoUsuario` ahora acepta `cliente`.
- `User.rolConfigurado` permite onboarding posterior a Google Auth.
- `Oportunidad` soporta `ownerType`, `ownerId`, `createdBy` y `createdByRole`.
- Filtros de oportunidades usan ownership y conservan `contratista` para datos legacy.
- Historial agrega `GET /api/historial/cliente`.

## Flutter

- `AuthWrapper` enruta `cliente` a `ClienteHomeScreen`.
- `ClienteHomeScreen` consume oportunidades reales del backend.
- Cliente puede crear carga reutilizando el flujo real de crear oportunidad.
- Cliente puede abrir ofertas reales y aceptar/rechazar.

## Permisos

Cliente puede crear cargas, ver sus cargas, ver ofertas, aceptar/rechazar ofertas, consultar historial, acceder al chat/tracking autorizado y calificar viajes entregados.

Cliente no puede tomar viajes, iniciar conduccion, administrar vehiculos ni gestionar flota.
