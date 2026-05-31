# TrackNariño

Sistema integral para la gestión, seguimiento y seguridad del transporte de carga en el departamento de Nariño, Colombia.

## Autores

- Christian Santacruz
- Luis Inguilan

## Resumen Del Proyecto

TrackNariño es una plataforma tecnológica desarrollada como proyecto de tesis para mejorar la operación logística regional mediante una aplicación móvil y un backend operacional. El sistema conecta a contratistas, clientes y camioneros en un mismo ecosistema, permitiendo publicar oportunidades de carga, negociar precios, aceptar viajes, calcular rutas, hacer seguimiento GPS en tiempo real, reportar alertas de seguridad, operar con conectividad intermitente y visualizar evidencia operativa del transporte.

El proyecto no se limita a registrar cargas. Su propósito es representar un flujo logístico completo: desde la publicación de una oportunidad hasta el inicio, monitoreo, atención de incidentes, finalización, comunicación de llegada, calificación y análisis operativo del viaje.

## Problema

El transporte de carga en Nariño enfrenta problemas operativos frecuentes:

- Baja visibilidad sobre la ubicación real de los vehículos durante los trayectos.
- Comunicación fragmentada entre contratistas, clientes y camioneros.
- Dificultad para reaccionar ante incidentes de seguridad vial, bloqueos, derrumbes, protestas, robos o mal estado de vía.
- Dependencia de llamadas o mensajes manuales para confirmar avances del viaje.
- Pérdida de información cuando el camionero atraviesa zonas con baja conectividad.
- Falta de trazabilidad técnica sobre rutas, eventos, alertas, sincronización y estado del viaje.
- Procesos poco estandarizados para aceptar cargas, negociar precios y confirmar entregas.

En una región con carreteras complejas, variabilidad climática, zonas rurales y conectividad irregular, la operación logística necesita herramientas que mantengan continuidad incluso cuando la red falla.

## Solución Implementada

TrackNariño implementa una plataforma logística móvil con arquitectura offline-first, tiempo real y trazabilidad operacional. La solución permite que cada actor del sistema tenga una experiencia específica:

- El contratista publica cargas, revisa ofertas, acepta camioneros, monitorea flota y consulta alertas.
- El camionero visualiza oportunidades, negocia o acepta cargas, inicia rutas, comparte GPS, reporta incidentes y completa viajes.
- El cliente consulta viajes asociados, seguimiento, evidencia de entrega y estado de la carga.
- El sistema mantiene sincronización local, cola offline, eventos realtime, auditoría de rutas, telemetría y diagnósticos operacionales.

Además, el proyecto incorpora un modo de simulación operacional para demostración de tesis. Este modo permite ejecutar el ciclo completo de un viaje sin requerir camioneros reales, usando la misma arquitectura de rutas, tracking, alertas, realtime, cola offline y sincronización.

## Objetivo General

Desarrollar una plataforma móvil y backend para gestionar, monitorear y mejorar la seguridad del transporte de carga en Nariño, integrando publicación de oportunidades, seguimiento GPS, rutas operativas, alertas, comunicación en tiempo real, operación offline y trazabilidad de eventos.

## Objetivos Específicos

- Diseñar una arquitectura cliente-servidor para soportar usuarios con roles diferenciados.
- Implementar autenticación segura con JWT, Google Sign-In y configuración de roles.
- Permitir la publicación, negociación, aceptación e inicio de oportunidades logísticas.
- Integrar mapas, cálculo de rutas y persistencia de geometría de ruta.
- Registrar ubicación GPS del camionero y transmitirla en tiempo real.
- Implementar alertas de seguridad georreferenciadas visibles en los mapas operativos.
- Garantizar funcionamiento en condiciones de conectividad inestable mediante cola offline.
- Incorporar Socket.IO para eventos en tiempo real de tracking, alertas y cambios de estado.
- Agregar trazabilidad, telemetría, auditoría de rutas y centro de diagnósticos.
- Crear un modo de simulación operacional para demostrar el ecosistema completo durante la sustentación.

## Alcance Funcional

TrackNariño cubre los siguientes módulos:

- Autenticación y roles.
- Gestión de usuarios camionero, contratista y cliente.
- Publicación de oportunidades de transporte.
- Negociación de precios y ofertas.
- Aceptación e inicio de viajes.
- Seguimiento GPS en vivo.
- Mapas operativos con rutas, marcadores, alertas y estado del vehículo.
- Persistencia local de rutas.
- Alertas de seguridad.
- Notificaciones push.
- Chat y comunicación operativa.
- Evidencia de entrega.
- Calificaciones y reputación.
- Tracking compartido.
- Cola offline y sincronización.
- Diagnósticos operacionales.
- Auditoría y telemetría de rutas.
- Modo de simulación para demostración.

## Roles Del Sistema

### Camionero

El camionero puede consultar cargas disponibles, enviar ofertas, aceptar oportunidades, iniciar viajes, navegar la ruta, reportar ubicación, crear alertas, operar en zonas sin conexión, recuperar sincronización y finalizar la operación.

### Contratista

El contratista puede crear oportunidades, revisar ofertas, asignar cargas, monitorear ubicación de camioneros, visualizar alertas, consultar estado de viajes, revisar trazabilidad y gestionar su operación logística.

### Cliente

El cliente puede participar como propietario de cargas, consultar el estado de sus viajes, acceder a seguimiento, evidencia, calificaciones y actualizaciones operativas.

### Sesión De Simulación

La sesión `SIMULATION_DRIVER` permite demostrar un camionero temporal sin crear un usuario permanente en base de datos. La simulación no elimina oportunidades reales del mercado y ejecuta el ciclo de viaje usando la infraestructura existente.

## Arquitectura General

El proyecto está dividido en dos componentes principales:

```text
TracknarinoApp/
├── Backend/          API REST, Socket.IO, MongoDB, servicios operacionales
├── trackarino_app/   Aplicación Flutter móvil/multiplataforma
└── docs/             Reportes técnicos por fase, validación y arquitectura
```

### Backend

El backend está construido con Node.js, Express y MongoDB. Expone API REST para autenticación, oportunidades, ubicación, alertas, rutas, calificaciones, notificaciones, chat, evidencia, tracking compartido y diagnósticos. También inicializa Socket.IO para comunicación en tiempo real.

Componentes principales:

- `routes/`: definición de endpoints.
- `controllers/`: lógica HTTP y orquestación de casos de uso.
- `services/`: servicios de negocio, eventos, rutas, tracking, métricas y telemetría.
- `models/`: modelos Mongoose.
- `middleware/`: autenticación, autorización por rol, validación y manejo de errores.
- `scripts/`: validación, carga operacional, device lab y diagnósticos.

### Aplicación Flutter

La aplicación móvil está construida con Flutter y Provider. Integra mapas, GPS, almacenamiento seguro, base local Drift/SQLite, notificaciones, Socket.IO, servicios REST y UI operacional.

Componentes principales:

- `screens/`: pantallas por rol y flujo.
- `services/`: comunicación con backend, ubicación, auth, alertas, rutas y tracking.
- `state/`: estado global de sesión, alertas y viaje activo.
- `offline/`: cola local, SyncEngine, repositorio Drift y conectividad.
- `routing/`: inteligencia operacional de ruta.
- `simulation/`: control de movimiento simulado.
- `widgets/operational/`: componentes visuales premium y de mapa.

## Flujo Operativo Principal

1. El usuario inicia sesión o configura su rol.
2. El contratista o cliente publica una oportunidad de carga.
3. El camionero consulta oportunidades disponibles.
4. El camionero envía una oferta o acepta la carga.
5. El viaje pasa a estado asignado o aceptado.
6. El camionero abre la ruta y el sistema calcula geometría real.
7. Al iniciar viaje, se activa el seguimiento GPS.
8. Las ubicaciones se guardan en cola offline y se sincronizan con backend.
9. El backend persiste la ubicación y emite eventos Socket.IO.
10. Los mapas de contratista, cliente, camionero y tracking compartido reaccionan al cambio.
11. Si ocurre un incidente, se crea una alerta georreferenciada.
12. Si se pierde conexión, los eventos quedan pendientes localmente.
13. Al recuperar señal, SyncEngine reenvía posiciones, alertas y acciones pendientes.
14. Al finalizar, el sistema registra entrega, evidencia, calificación y trazabilidad.

## Modo De Simulación Operacional

El modo de simulación fue incorporado para sustentar el proyecto sin depender de camioneros reales durante la demostración. No es una aplicación separada ni un mock aislado: usa el mismo flujo de viaje y los mismos servicios críticos del sistema.

Características:

- Entrada desde login con `ENTRAR EN MODO SIMULACIÓN`.
- Sesión temporal `SIMULATION_DRIVER`.
- No crea usuario permanente en base de datos.
- No elimina ni asigna globalmente la oportunidad real.
- Crea una instancia local de viaje simulado.
- Usa geometría real de ruta.
- Mueve el vehículo punto por punto sobre la ruta.
- Permite seleccionar velocidad de simulación.
- Emite ubicación mediante `LocationService`, `SyncEngine` y backend de tracking.
- Permite detener viaje, seleccionar motivo, crear alertas y recuperar señal.
- Simula pérdida de conexión manteniendo progresión interna y cola offline.
- Reproduce la cola al recuperar señal.
- Permite desviación y recálculo de ruta.
- Muestra resumen profesional al completar el viaje.
- Abre WhatsApp con mensaje de llegada.

Este modo permite presentar en vivo el ecosistema completo: marketplace, ruta, GPS, realtime, alertas, offline-first, sincronización, tracking y experiencia de usuario.

## Rutas Y Mapas

TrackNariño utiliza mapas interactivos y cálculo de rutas para representar el movimiento operativo del vehículo. El sistema maneja:

- Cálculo de ruta entre origen y destino.
- Persistencia local de ruta.
- Visualización de polilínea.
- Marcadores de vehículo, destino, alertas y servicios.
- Estado de salud de ruta.
- Detección de desviaciones.
- Recomendación y ejecución de recálculo.
- Capas visuales para segmentos degradados y rutas alternativas.

La inteligencia de ruta evalúa proximidad del vehículo al corredor, alertas cercanas, conectividad y estado de la ruta para generar mensajes operativos.

## Offline-First Y Sincronización

Uno de los pilares técnicos del proyecto es la operación con conectividad inestable. La aplicación no depende de estar siempre conectada para conservar datos críticos.

El `SyncEngine` permite:

- Guardar posiciones GPS localmente.
- Guardar alertas pendientes.
- Encolar acciones de viaje.
- Evitar duplicados mediante `clientEventId`.
- Reintentar operaciones fallidas.
- Mantener orden FIFO para GPS.
- Priorizar alertas y acciones críticas.
- Reproducir la cola cuando la conexión vuelve.
- Exponer estado de sincronización al usuario.

Esto es esencial para rutas rurales o zonas de baja cobertura en Nariño.

## Tiempo Real

El sistema usa Socket.IO para emitir eventos persistidos desde el backend hacia las aplicaciones conectadas. Los eventos principales son:

- `tracking:location_updated`
- `trip:state_changed`
- `alert:created`
- `connection:state`

El backend emite eventos después de persistir los datos, evitando que realtime sea la única fuente de verdad. La app mantiene fallback mediante polling cuando el socket no está disponible.

## Alertas De Seguridad

Las alertas permiten reportar incidentes sobre la ruta:

- Accidente.
- Bloqueo.
- Derrumbe.
- Robo.
- Protesta.
- Mal estado de vía.
- Clima.
- Otros incidentes.

Cada alerta contiene tipo, descripción, coordenadas, timestamp y estado de sincronización. Las alertas se integran con mapas, feed de alertas, rutas y realtime.

## Evidencia, Calificaciones Y Reputación

El sistema contempla funcionalidades complementarias para cerrar el ciclo logístico:

- Evidencia de entrega.
- Observaciones y datos de finalización.
- Calificación del conductor.
- Calificación del viaje.
- Reputación operacional.
- Historial de viajes.

Estas funcionalidades ayudan a construir confianza entre actores de la plataforma.

## Seguridad

TrackNariño maneja información sensible como identidad, ubicación GPS, rutas y cargas. Por eso se implementan prácticas de seguridad:

- Autenticación con JWT.
- Autorización por rol.
- Google Sign-In.
- Almacenamiento seguro de token en Flutter.
- Middlewares de validación.
- Sanitización de respuestas.
- Helmet y CORS en backend.
- Rate limiting.
- No exposición intencional de secretos.
- Validación de coordenadas y payloads críticos.

## Observabilidad Y Diagnóstico

El sistema incluye servicios y reportes para revisar salud operacional:

- Logs estructurados en Flutter y backend.
- Métricas de realtime.
- Diagnóstico de conectividad.
- Inspector de replay offline.
- Reportes de validación por fases.
- Pruebas de carga operacional.
- Device lab y evidencia técnica.
- Auditoría y telemetría de rutas.

La carpeta `docs/` contiene reportes técnicos de implementación, confiabilidad, roles, tracking compartido, calificaciones, chat, notificaciones, simulación y estabilización.

## Tecnologías Utilizadas

### Backend

- Node.js.
- Express.
- MongoDB.
- Mongoose.
- Socket.IO.
- JWT.
- Firebase Admin.
- Redis adapter opcional para Socket.IO.
- Helmet.
- CORS.
- Express Rate Limit.
- Axios.

### Aplicación Flutter

- Flutter.
- Dart.
- Provider.
- Flutter Map.
- Google Maps Flutter.
- Geolocator.
- Socket.IO Client.
- Drift / SQLite.
- Flutter Secure Storage.
- Firebase Core.
- Firebase Messaging.
- Flutter Local Notifications.
- Google Sign-In.
- URL Launcher.
- HTTP / Dio.

## Instalación

### Requisitos

- Node.js compatible con el backend.
- MongoDB local o remoto.
- Flutter SDK.
- Android Studio, emulador Android o dispositivo físico.
- Cuenta y configuración Firebase si se prueban notificaciones.
- Variables de entorno para JWT, MongoDB, Google/Firebase y proveedores externos.

### Backend

```bash
cd Backend
npm install
```

Crear un archivo `.env` basado en la configuración requerida:

```env
PORT=4000
MONGO_URI=mongodb://localhost:27017/tracknarino
JWT_SECRET=change_me
JWT_EXPIRES_IN=1d
```

Ejecutar en desarrollo:

```bash
npm run dev
```

Ejecutar en modo normal:

```bash
npm start
```

El backend queda disponible por defecto en:

```text
http://localhost:4000
```

### Aplicación Flutter

```bash
cd trackarino_app
flutter pub get
```

Ejecutar:

```bash
flutter run
```

Para Android Emulator, la app usa por defecto:

```text
http://10.0.2.2:4000/api
```

Para web o escritorio en desarrollo:

```text
http://localhost:4000/api
```

## Comandos De Validación

Backend:

```bash
cd Backend
npm run lint
npm test
```

Flutter:

```bash
cd trackarino_app
flutter analyze
flutter test
```

Scripts operacionales:

```bash
cd Backend
npm run capture:diagnostics
npm run load:operations
npm run device-lab:bundle
npm run validate:evidence
npm run verify:staging-failures
```

## Estructura De Documentación

Algunos documentos relevantes:

- `docs/OPERATIONAL-RELIABILITY.md`
- `docs/SHARED_TRACKING_REPORT.md`
- `docs/RATING_SYSTEM_REPORT.md`
- `docs/PUSH_NOTIFICATIONS_REPORT.md`
- `docs/REALTIME_CHAT_REPORT.md`
- `docs/OFFER_SYSTEM_REPORT.md`
- `docs/CLIENT_ROLE_REPORT.md`
- `docs/PHASE-13-SIMULATION-MODE-REPORT.md`
- `docs/DEVICE-LAB-VALIDATION.md`
- `docs/STAGING-DEPLOYMENT.md`

## Aporte Académico

TrackNariño aporta una solución aplicada a un problema regional concreto. Desde la perspectiva académica, el proyecto integra desarrollo móvil, backend, bases de datos, tiempo real, geolocalización, arquitectura offline-first, seguridad, experiencia de usuario y validación operacional.

El valor principal está en demostrar que un sistema logístico regional puede ser diseñado con criterios de confiabilidad similares a plataformas profesionales: persistencia antes de emisión realtime, sincronización tolerante a fallos, trazabilidad de rutas, separación por roles y experiencia móvil centrada en mapas.

## Limitaciones Actuales

- La sincronización en segundo plano depende de que el proceso de la app esté activo.
- Algunas capacidades de producción, como despliegue multi-nodo con Redis y monitoreo externo completo, requieren configuración de infraestructura.
- La simulación operacional actual está orientada a demostración de tesis y debe endurecerse con persistencia completa de instancias simuladas si se usa en producción o entrenamiento formal.
- La carga de imágenes en alertas no está completamente soportada en backend.
- La validación en condiciones reales de carretera requiere pruebas de campo o device lab ampliado.

## Futuras Mejoras

- Persistir `simulationTripInstance` en backend para entrenamientos y auditoría completa.
- Mejorar tracking compartido desde UI móvil.
- Incorporar analítica avanzada de tiempos, rutas y riesgo.
- Integrar proveedores de mapas/rutas redundantes.
- Añadir panel web administrativo.
- Implementar background sync nativo.
- Fortalecer despliegue con Redis, observabilidad externa y monitoreo continuo.
- Agregar pruebas end-to-end del ciclo logístico completo.

## Licencia Y Uso

Este proyecto fue desarrollado con fines académicos y demostrativos para tesis. Su uso, distribución o despliegue productivo debe ser autorizado por sus autores y acompañado de una revisión de seguridad, infraestructura y protección de datos.

## Créditos

Proyecto desarrollado por:

- Christian Santacruz
- Luis Inguilan

TrackNariño representa una propuesta tecnológica para modernizar la logística de carga en Nariño, fortaleciendo visibilidad, seguridad, trazabilidad y continuidad operativa.