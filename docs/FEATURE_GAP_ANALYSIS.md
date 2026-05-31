# Feature Gap Analysis

Fecha: 2026-05-30

Referencias analizadas como categoría de producto: Uber Freight, InDrive Cargo, MUV, Tookan, Onfleet, Locus, Motive y Samsara.

No se recomienda copiar interfaces. La referencia válida es funcional: marketplace, despacho, tracking, prueba de entrega, telemática, cumplimiento, soporte y monetización.

## Criterios

- Valor: impacto en operación, confianza, tesis y escalabilidad.
- Complejidad: esfuerzo técnico, impacto de arquitectura y dependencias externas.
- Prioridad: P0 inmediata, P1 alta, P2 media, P3 futura.

## Gaps Principales

| Funcionalidad | Valor | Complejidad | Prioridad | Recomendación |
|---|---:|---:|---:|---|
| Rol `CLIENTE` | Muy alto | Media | P0 | Implementar como actor dueño de carga, separado de contratista |
| Registro Google-first | Muy alto | Media | P0 | Reducir fricción y completar perfil por etapas |
| Ownership de oportunidad | Muy alto | Media | P0 | Agregar propietario y origen `cliente`/`contratista` |
| Proof of Delivery | Muy alto | Media | P0 | Firma, foto, timestamp, geotag y confirmación |
| Notificaciones push reales | Muy alto | Media | P0 | Corregir FCM end-to-end antes de chat o pagos |
| Seguridad por recurso | Muy alto | Media | P0 | Filtrar alertas, viajes, ubicación y documentos por permisos |
| Chat en tiempo real | Alto | Media | P1 | Construir sobre Socket.IO con persistencia Mongo |
| Evidencia fotográfica | Alto | Media | P1 | Subida segura, compresión y relación con viaje |
| Firma digital de entrega | Alto | Media | P1 | Captura local + hash + metadata |
| QR de recepción | Medio-alto | Media | P1 | Validar entrega por receptor sin formularios largos |
| Seguimiento compartido | Alto | Media | P1 | Link temporal con permisos limitados |
| Historial GPS operativo | Alto | Media-alta | P1 | Consulta paginada, retención y replay de viaje |
| Gestión documental | Alto | Media-alta | P1 | Licencia, SOAT, tecnomecánica, RUT/NIT y vencimientos |
| Verificación identidad | Alto | Alta | P1 | Empezar manual/admin; automatización después |
| Calificaciones completas | Medio-alto | Media | P1 | Calificar viaje, no solo usuario aislado |
| Reputación | Medio-alto | Media-alta | P1 | Score por puntualidad, cumplimiento y cancelaciones |
| Gestión de vehículos | Alto | Media | P1 | Resolver duplicidad `User.camion` vs `Vehiculo` |
| Gestión de conductores | Alto | Media | P1 | Contratista administra conductores afiliados |
| Dashboard operacional | Muy alto | Alta | P1 | Vista dispatcher: cargas, flota, alertas, SLA |
| Geocercas | Medio-alto | Alta | P2 | Llegada/salida automática en cargue/descargue |
| Reportes PDF | Medio | Media | P2 | Viaje, entrega, alertas, trazabilidad |
| Facturación | Alto | Alta | P2 | Modelar tarifa, comprobantes y estado de pago |
| Pagos | Alto | Alta | P2 | Requiere pasarela, conciliación y riesgos legales |
| Liquidaciones | Alto | Alta | P2 | Después de facturación y pagos |
| Estadísticas | Medio-alto | Media | P2 | Métricas por rol y operación |
| Centro de soporte | Medio-alto | Media | P2 | Incidencias por viaje, mensajes y evidencias |
| Convoyes | Medio | Alta | P3 | Útil para rutas de riesgo, no para MVP inmediato |
| IA asistencia operativa | Medio | Alta | P3 | Solo después de tener datos confiables |

## Evaluación Específica Solicitada

### Chat en tiempo real

Estado: faltante.

Valor: alto. Permite coordinar cargue, demoras, incidentes y entrega. Debe persistirse en backend; Socket.IO solo debe transportar eventos.

Recomendación: P1. Implementar por viaje con permisos: cliente, contratista, camionero asignado y soporte.

### Notificaciones push

Estado: parcial/roto.

Valor: muy alto. Existe Firebase Messaging, pero el token no se registra correctamente end-to-end.

Recomendación: P0. Corregir antes de crear más eventos.

### Firma digital de entrega

Estado: faltante.

Valor: muy alto. Cierra el ciclo contractual.

Recomendación: P0/P1. Asociar a estado `entregada` y guardar metadata.

### Evidencia fotográfica

Estado: faltante en operación; hay `image_picker` para avatares locales.

Valor: alto.

Recomendación: P1. No usar mock ni almacenamiento local como fuente final.

### QR de recepción

Estado: faltante.

Valor: medio-alto.

Recomendación: P1. Útil para cliente/receptor al confirmar entrega.

### Seguimiento compartido

Estado: faltante.

Valor: alto.

Recomendación: P1. Link temporal, sin exponer datos privados del conductor.

### Historial GPS

Estado: parcial.

Valor: alto.

Recomendación: P1. Ya hay datos; falta experiencia profesional de consulta, retención y replay.

### Gestión documental

Estado: muy parcial.

Valor: alto.

Recomendación: P1. Convertir campos sueltos en documentos verificables.

### Verificación de identidad

Estado: faltante.

Valor: alto.

Recomendación: P1. Primero flujo manual/admin; después automatización.

### Calificaciones y reputación

Estado: parcial.

Valor: medio-alto.

Recomendación: P1. Calificar por viaje y alimentar score público limitado.

### Gestión de vehículos y conductores

Estado: parcial/duplicado.

Valor: alto.

Recomendación: P1. Unificar modelo y permisos.

### Convoyes

Estado: faltante.

Valor: medio.

Recomendación: P3. No priorizar antes de estabilizar viajes individuales.

### Geocercas

Estado: faltante.

Valor: medio-alto.

Recomendación: P2. Requiere buen tracking y reglas de eventos.

### Prueba de entrega

Estado: faltante.

Valor: muy alto.

Recomendación: P0/P1. Debe incluir firma, foto, ubicación y validación.

### Centro de soporte

Estado: faltante.

Valor: medio-alto.

Recomendación: P2. Incidencias por viaje con evidencia.

### Reportes PDF

Estado: faltante.

Valor: medio.

Recomendación: P2. Importante para tesis y operación B2B.

### Dashboard operacional

Estado: parcial por pantallas de seguimiento y diagnósticos inaccesibles.

Valor: muy alto.

Recomendación: P1. Debe ser rol `admin`/`operador`, no contratista global.

### Facturación, pagos y liquidaciones

Estado: faltante. Solo hay método de pago básico.

Valor: alto.

Recomendación: P2. No implementar sin modelo financiero y responsabilidades legales.

### Estadísticas

Estado: parcial en diagnósticos operativos, no producto.

Valor: medio-alto.

Recomendación: P2. Métricas por rol: cumplimiento, ingresos, viajes, alertas, tiempos.

### IA para asistencia operativa

Estado: faltante.

Valor: medio.

Recomendación: P3. No priorizar hasta tener datos limpios, permisos y logs confiables.

## Roadmap Recomendado

### P0: Tesis y producción mínima

1. Seguridad de alertas y endpoints operativos.
2. Google Auth.
3. Rol `CLIENTE`.
4. Ownership de oportunidades.
5. Notificaciones push reales.
6. Proof of Delivery mínimo.

### P1: Plataforma profesional

1. Chat por viaje.
2. Evidencias y documentos.
3. Dashboard operacional.
4. Historial GPS/replay.
5. Calificaciones/reputación.
6. Gestión de vehículos/conductores.

### P2: Monetización y operación avanzada

1. Facturación.
2. Pagos.
3. Liquidaciones.
4. Reportes PDF.
5. Geocercas.
6. Soporte.

### P3: Diferenciadores futuros

1. Convoyes.
2. Optimización avanzada.
3. IA operativa.
4. Telemática estilo Motive/Samsara.
