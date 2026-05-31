# TrackNariño Product Audit

Fecha: 2026-05-30

Alcance auditado:

- Flutter app: `trackarino_app`
- Backend Node.js/Express: `Backend`
- MongoDB/Mongoose
- Socket.IO realtime
- Rutas, login, registro, roles, oportunidades, viajes, alertas, perfil, navegación, UX/UI y arquitectura

Este documento es una auditoría previa a implementación. No aprueba cambios por sí mismo.

## Resumen Ejecutivo

TrackNariño tiene una base técnica superior a un MVP simple: autenticación JWT, backend modular, MongoDB, tracking GPS, Socket.IO autenticado, SyncEngine offline-first, PollingController, RealtimeService, mapas, alertas de seguridad y capa operativa de rutas. La dirección del producto es correcta para logística regional con baja conectividad.

El problema principal es que el producto todavía está diseñado alrededor de dos actores (`camionero` y `contratista`) y no alrededor de una cadena logística completa. Falta el rol `cliente`, faltan permisos por propietario de carga, hay flujos visualmente presentes pero incompletos, y existen contratos rotos entre Flutter y backend.

Prioridad inmediata: cerrar brechas de seguridad, corregir contratos API rotos, documentar roles, implementar Google Auth correctamente, introducir `CLIENTE` sin romper APIs existentes y rediseñar oportunidades con ownership claro.

## Funcionalidades Existentes

### Backend

| Severidad | Funcionalidad | Estado |
|---|---|---|
| BAJO | API Express con rutas por dominio | Implementada en `Backend/server.js` y `Backend/routes` |
| BAJO | Autenticación JWT por Bearer token | Implementada en `authRoutes.js` y `authMiddleware.js` |
| BAJO | Registro/login con contraseña | Implementado para `camionero` y `contratista` |
| BAJO | Modelos MongoDB/Mongoose | Implementados para User, Oportunidad, Ubicacion, Alertas, Vehiculos, Calificaciones y rutas operativas |
| BAJO | Oportunidades/cargas | Implementadas con estados, negociación y asignación |
| BAJO | Tracking GPS | Implementado con ubicación actual e historial |
| BAJO | Socket.IO autenticado | Implementado con rooms por contratista, camionero, viaje y ruta |
| BAJO | Alertas de seguridad | Implementadas con persistencia, dedupe y eventos realtime |
| BAJO | ORS/OSRM routing proxy | Implementado por backend |
| BAJO | Capa operativa de rutas | Implementada en `/api/routing` y servicios asociados |
| BAJO | Rate limiting, Helmet y payload limit | Implementados |

### Flutter

| Severidad | Funcionalidad | Estado |
|---|---|---|
| BAJO | App Flutter con Provider | Implementada |
| BAJO | Login/registro tradicional | Implementado |
| BAJO | Home por rol camionero/contratista | Implementado |
| BAJO | Mapa camionero | Implementado |
| BAJO | Seguimiento flota contratista | Implementado |
| BAJO | Oportunidades para camionero | Implementadas |
| BAJO | Crear oportunidad para contratista | Implementado |
| BAJO | Perfil camionero/contratista | Implementado |
| BAJO | SyncEngine offline-first | Implementado y no debe eliminarse |
| BAJO | RealtimeService Socket.IO | Implementado y no debe eliminarse |
| BAJO | PollingController fallback | Implementado y no debe eliminarse |
| BAJO | Firebase Messaging/local notifications | Parcialmente implementado |

## Funcionalidades Incompletas

| Severidad | Área | Hallazgo | Impacto |
|---|---|---|---|
| CRÍTICO | Producción Flutter | `TRACKNARINO_DEV` por defecto queda en `true` | Builds release pueden apuntar a localhost si no se pasan flags |
| CRÍTICO | Roles | No existe `CLIENTE` en backend ni Flutter | La plataforma no representa al dueño real de la carga |
| CRÍTICO | Google Auth | UI muestra Google pero no autentica | Fricción alta y flujo pedido no existe |
| ALTO | Registro | Registro largo obliga datos antes de entrar | Contradice el flujo profesional solicitado |
| ALTO | FCM | Token de dispositivo no se registra end-to-end | Push dirigido no funciona de forma confiable |
| ALTO | Recuperación contraseña | Pantalla existe pero botón está deshabilitado | Flujo visual incompleto |
| ALTO | Perfil | Avatares son locales y no persistidos | UX engañosa |
| ALTO | Sync UX | `SyncCenterScreen` existe pero es inaccesible | Usuarios no pueden resolver cola offline |
| ALTO | Diagnósticos | `OperationalDiagnosticsScreen` existe pero es inaccesible | Operación no puede usar herramientas ya construidas |
| MEDIO | Oportunidades | Ownership solo modela `contratista` | No diferencia carga creada por cliente vs contratista |
| MEDIO | Disponibilidad | Estado camionero queda local | Backend y app pueden divergir |
| MEDIO | Estado aprobación | `estadoAprobacion` existe pero no bloquea operación | Usuarios pendientes podrían operar |
| MEDIO | Historial GPS | No hay política TTL/archivado explícita | Crecimiento indefinido de datos |

## Funcionalidades Rotas

| Severidad | Área | Hallazgo | Evidencia |
|---|---|---|---|
| CRÍTICO | Alertas | Listado global expone alertas a cualquier usuario autenticado | `GET /api/alertas/listar` y `/recientes` no filtran por ownership/rol |
| ALTO | Flutter/backend | Flutter intenta actualizar device token vía `PUT /api/users/:id` pero backend usa `/api/notificaciones/registrar-token` | Contrato roto |
| ALTO | Alertas | Flutter define confirmar/compartir alerta, backend no expone endpoints | Contrato roto |
| ALTO | Notificaciones | Backend filtra camioneros por campo `disponible`, pero `User` no lo define | FCM de nuevas cargas puede no enviar |
| ALTO | Google Auth | Archivo disponible es OAuth `installed`, no cliente web backend | No debe usarse como secreto servidor |
| MEDIO | Crear oportunidad | Backend permite camionero en ruta crear oportunidad pero la guarda como `contratista` | Modelo de dominio inconsistente |
| MEDIO | Registro camionero | Fecha expedición/licencia puede mapearse incorrectamente desde Flutter | Datos regulatorios débiles |

## Funcionalidades Duplicadas

| Severidad | Área | Duplicidad | Riesgo |
|---|---|---|---|
| MEDIO | Auth | `/api/auth/perfil` y `/api/users/perfil` | Contratos paralelos |
| MEDIO | Auth legacy | `/api/users/login`, `/registro`, `/actualizar-pago` devuelven 410 | Mantener solo como compatibilidad documentada |
| MEDIO | Oportunidades | `/` y `/disponibles` usan comportamiento equivalente | Confusión de API |
| MEDIO | Ofertas | Varias rutas para aceptar oferta | Mayor superficie de bugs |
| MEDIO | Vehículos | `User.camion` y colección `Vehiculo` | Doble fuente de verdad |
| MEDIO | Alertas | `POST /crear` y `POST /` | Contrato duplicado |
| BAJO | Flutter | Métodos duplicados en `OportunidadService` | Mantenimiento más costoso |
| BAJO | Flutter | Helpers de compatibilidad repetidos | Deuda menor |

## Pantallas Innecesarias o Inaccesibles

| Severidad | Pantalla/Widget | Estado | Decisión recomendada |
|---|---|---|---|
| ALTO | `SyncCenterScreen` | Inaccesible | Enlazar desde perfil/banner, no eliminar |
| ALTO | `OperationalDiagnosticsScreen` | Inaccesible | Enlazar solo para rol operativo/admin futuro |
| MEDIO | `ForgotPasswordScreen` | Incompleta | Implementar endpoint o ocultar hasta tener backend |
| MEDIO | Google placeholder | Decorativo | Reemplazar por botón real |
| MEDIO | Confirmar/compartir alerta | Métodos sin UI | Implementar backend+UI o retirar del service |
| BAJO | `device_lab` | Solo test/lab | Mantener fuera de navegación productiva |

## Problemas UX

| Severidad | Hallazgo | Recomendación |
|---|---|---|
| CRÍTICO | Registro largo antes de probar la app | Cambiar a Google-first + selección de rol |
| ALTO | Google aparece pero no hace nada | Implementar flujo real o no mostrar |
| ALTO | Alerta creada muestra éxito aunque solo quedó en cola | Mensaje debe distinguir "guardada para sincronizar" vs "publicada" |
| ALTO | Usuario no ve estado de SyncEngine | Mostrar banner/centro de sincronización |
| MEDIO | Estados vacíos no distinguen error, sin GPS o sin datos | Estados vacíos específicos por causa |
| MEDIO | Disponibilidad local puede mentir | Persistir y reflejar backend |
| MEDIO | Recuperación contraseña crea expectativa falsa | Implementar o retirar temporalmente |
| BAJO | Coordenadas Pasto repetidas como default | Centralizar fallback geográfico |

## Problemas UI

| Severidad | Hallazgo | Recomendación |
|---|---|---|
| MEDIO | Pantallas premium mezcladas con placeholders funcionales | Priorizar consistencia entre UI y capacidad real |
| MEDIO | Bottom nav por rol no contempla `CLIENTE` | Diseñar navegación separada para cliente |
| MEDIO | Varios mapas vivos dentro de `IndexedStack` | Pausar streams/timers por tab visible |
| BAJO | Nombre visible `Trackarino App` | Normalizar a TrackNariño/TrackNarino según marca final |
| BAJO | Avatares locales generan falsa persistencia | Persistir imagen o retirar edición |

## Problemas de Navegación

| Severidad | Hallazgo | Recomendación |
|---|---|---|
| CRÍTICO | Flutter solo enruta `camionero` y `contratista` | Agregar `cliente` antes de habilitar rol en backend |
| ALTO | No hay router declarativo ni matriz de rutas | Documentar rutas actuales antes de migrar |
| ALTO | Pantallas operativas inaccesibles | Añadir entradas controladas por rol |
| MEDIO | Navegación imperativa dispersa | Mantener por ahora, pero crear mapa de rutas para QA |
| MEDIO | AuthWrapper invalida cualquier nuevo rol | Actualizar bootstrap de sesión al agregar `CLIENTE` |

## Problemas de Seguridad

| Severidad | Hallazgo | Recomendación |
|---|---|---|
| CRÍTICO | Alertas globales visibles por usuarios autenticados | Filtrar por rol, zona, viaje asociado o permisos |
| CRÍTICO | OAuth client JSON dentro del repo | No usar como secreto; mover configuración a variables de entorno y rotar si aplica |
| ALTO | Endpoints `/api/operations/readiness` y `/release-gates` públicos | Proteger o limitar exposición en producción |
| ALTO | `deviceToken` expuesto por rutas admin a contratistas | No devolver tokens al frontend |
| ALTO | CORS acepta requests sin `Origin` | Mantener solo si es necesario para móvil y documentarlo |
| ALTO | Readme con JWT de ejemplo | Retirar tokens reales o realistas |
| MEDIO | `estadoAprobacion` no se valida | Bloquear acciones críticas a usuarios no aprobados |
| MEDIO | Calificaciones sin autorización fina | Verificar relación entre usuarios |
| MEDIO | FCM simulado puede loguear tokens | Evitar logging de tokens |

## Problemas de Rendimiento

| Severidad | Hallazgo | Recomendación |
|---|---|---|
| ALTO | Historial GPS sin TTL/retención | Definir política de retención y agregados |
| MEDIO | Alertas sin paginación robusta | Agregar paginación/filtros |
| MEDIO | Query extra por punto GPS para publicar eventos | Cachear o pasar contexto cuando sea seguro |
| MEDIO | `IndexedStack` mantiene mapas/timers | Pausar procesamiento por pestaña |
| MEDIO | Timer de viaje corre aunque usuario esté en otra tab | Activar según visibilidad |
| MEDIO | Listeners FCM pueden acumularse en re-login | Controlar ciclo de vida |
| BAJO | Dedupe realtime y polling anti-overlap existen | Mantener RealtimeService y PollingController |

## Funcionalidades Faltantes para Plataforma Profesional

| Severidad | Funcionalidad | Motivo |
|---|---|---|
| CRÍTICO | Rol `CLIENTE` | Dueño de carga no existe como actor |
| CRÍTICO | Ownership de oportunidad/carga | Sin propietario no hay permisos profesionales |
| CRÍTICO | Google Auth real | Reduce fricción y mejora confianza |
| CRÍTICO | Proof of Delivery | Entrega sin evidencia no es auditable |
| ALTO | Chat realtime | Coordinación operativa |
| ALTO | Push notifications end-to-end | Operación móvil depende de alertas |
| ALTO | Evidencia fotográfica | Prueba de cargue/descargue |
| ALTO | Firma digital | Confirmación de entrega |
| ALTO | Verificación identidad/documentos | Seguridad y cumplimiento |
| ALTO | Dashboard operacional | Control de cargas, flota, incidencias |
| ALTO | Historial GPS consultable | Auditoría y soporte |
| MEDIO | QR de recepción | Reduce disputas en entrega |
| MEDIO | Seguimiento compartido | Cliente externo puede ver avance |
| MEDIO | Reputación/calificaciones completas | Confianza marketplace |
| MEDIO | Gestión documental vehicular | SOAT, licencia, tecnomecánica |
| MEDIO | Geocercas | Llegadas/salidas automáticas |
| MEDIO | Reportes PDF | Tesis, operación y clientes |
| MEDIO | Facturación/pagos/liquidaciones | Monetización |
| BAJO | Convoyes | Útil después de estabilizar viajes simples |
| BAJO | IA operativa | Posterior a datos confiables |

## Plan de Implementación Propuesto

### Fase 0: Seguridad y contratos rotos

1. Proteger alertas, operations endpoints y exposición de device tokens.
2. Corregir contrato FCM Flutter/backend.
3. Alinear endpoints de alertas o retirar métodos muertos.
4. Documentar contratos legacy que no se eliminarán.

### Fase 1: Google Auth y registro sin fricción

1. Agregar dependencias aprobadas: `google_sign_in` en Flutter y `google-auth-library` en backend.
2. Configurar client IDs por variables de entorno.
3. Backend valida `id_token` con audiencia permitida y emite JWT propio.
4. Flutter obtiene nombre, correo y foto.
5. Si el usuario no tiene rol operativo, mostrar selección "¿Cómo usarás TrackNariño?".

### Fase 2: Rol `CLIENTE`

1. Extender enum backend a `cliente`.
2. Agregar `AuthWrapper` y navegación Flutter para cliente.
3. Agregar permisos por rol sin romper `camionero`/`contratista`.
4. Documentar restricciones.

### Fase 3: Oportunidades con propietario

1. Agregar owner explícito y `ownerType`: `cliente` o `contratista`.
2. Mantener `contratista` existente como compatibilidad operacional.
3. Filtrar oportunidades por origen: Todas, Clientes, Contratistas.
4. Mostrar "Creado por: Cliente/Contratista".

### Fase 4: UX operacional

1. Enlazar Sync Center.
2. Enlazar diagnósticos con rol correcto.
3. Corregir estados vacíos y mensajes offline.
4. Pausar timers/listeners por visibilidad.

## Decisión Pendiente

No se debe implementar todo en una sola intervención. La siguiente fase aprobable recomendada es:

**Fase 0 + Fase 1 mínima:** seguridad/contratos críticos + Google Auth + selección de rol.
