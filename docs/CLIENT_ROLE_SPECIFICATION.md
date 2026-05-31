# Client Role Specification

Fecha: 2026-05-30

Estado: especificación funcional previa a implementación.

## Definición

`CLIENTE` es el usuario que necesita transportar una carga y quiere supervisar el proceso. Puede ser persona natural, comercio, empresa o receptor/emisor autorizado.

No es conductor.

No es operador de flota.

No es administrador.

## Objetivo del Rol

Permitir que TrackNariño sea una plataforma logística completa, no solo una app de contratistas y camioneros.

El cliente debe poder:

- Crear cargas.
- Publicar oportunidades.
- Ver viajes asociados.
- Ver ubicación en tiempo real de sus viajes.
- Ver estado de entrega.
- Ver alertas relacionadas.
- Ver historial.

El cliente no debe poder:

- Tomar viajes.
- Conducir.
- Gestionar flota.
- Gestionar conductores.
- Ver ubicación de viajes ajenos.
- Ver tokens, datos internos o diagnósticos operativos.

## Capacidades

### Crear Cargas

Campos mínimos:

- Título
- Descripción
- Origen
- Destino
- Fecha/ventana de cargue
- Tipo de carga
- Peso/capacidad requerida
- Requisitos especiales
- Precio sugerido o presupuesto

Reglas:

- Toda carga creada por cliente debe guardar `ownerType = 'cliente'`.
- El `owner` debe ser el ID del cliente autenticado.
- El backend debe ignorar cualquier `owner` enviado por el frontend.

### Publicar Oportunidades

Una carga publicada se convierte en oportunidad visible para actores permitidos.

Debe mostrar:

```text
Creado por: Cliente
```

Si fue creada por contratista:

```text
Creado por: Contratista
```

Filtros requeridos:

- Todas
- Clientes
- Contratistas

### Ver Viajes Asociados

El cliente puede ver:

- Cargas creadas por él.
- Viajes derivados de sus cargas.
- Estado actual.
- Camionero/contratista asignado con información limitada.
- Historial de eventos del viaje.

No puede ver:

- Viajes de otros clientes.
- Flota completa del contratista.
- Ubicación histórica de camioneros fuera del viaje.

### Ver Ubicación en Tiempo Real

Condiciones:

- Solo si existe viaje asociado.
- Solo durante estados operativos: `asignada`, `aceptada`, `en_ruta`.
- No después de retención definida para entrega, salvo historial autorizado.

Realtime:

- El cliente debe unirse a room de viaje autorizada.
- El backend debe validar relación antes de permitir `trip:join`.

### Ver Estado de Entrega

Estados recomendados:

```text
publicada
asignada
aceptada
en_cargue
en_ruta
en_descargue
entregada
cancelada
```

Compatibilidad:

El modelo actual usa:

```text
disponible
asignada
aceptada
en_ruta
entregada
cancelada
```

La implementación inicial puede mantener los estados actuales y documentar expansión futura.

### Ver Alertas Relacionadas

El cliente puede ver alertas:

- Creadas dentro del viaje.
- Cercanas a la ruta de su viaje.
- Marcadas como relevantes para su carga.

No debe ver el listado global de alertas.

### Ver Historial

Historial visible:

- Cargas publicadas.
- Viajes completados.
- Estados y timestamps.
- Evidencias de entrega cuando existan.
- Alertas asociadas.

## Navegación Propuesta

### Tabs

1. Inicio
2. Crear carga
3. Seguimiento
4. Historial
5. Perfil

### Inicio

Debe mostrar:

- Cargas activas.
- Estado resumido.
- CTA crear carga.
- Alertas relevantes.

### Crear Carga

Debe ser simple y progresiva:

- Datos obligatorios mínimos.
- Detalles opcionales.
- Validación clara.
- Sin datos mock.

### Seguimiento

Debe mostrar:

- Mapa del viaje seleccionado.
- Estado actual.
- Última ubicación.
- ETA solo si hay fuente real.
- Alertas relacionadas.

### Historial

Debe mostrar:

- Viajes completados/cancelados.
- Filtros por fecha/estado.
- Evidencias cuando estén implementadas.

### Perfil

Debe mostrar:

- Nombre.
- Correo.
- Foto Google si existe.
- Tipo de usuario: Cliente.
- Cerrar sesión.

## Backend API Propuesta

Mantener endpoints existentes y extender con permisos.

### Reutilizar

```http
POST /api/oportunidades/crear
GET /api/oportunidades
GET /api/ubicacion/ultima/:idCamionero
GET /api/alertas/cercanas
GET /api/auth/perfil
```

### Agregar o ajustar

```http
GET /api/oportunidades?origen=todos|clientes|contratistas
GET /api/oportunidades/mis-cargas
GET /api/oportunidades/:id/tracking
GET /api/oportunidades/:id/alertas
```

Regla:

Si se puede resolver con endpoints existentes sin romper contratos, preferir extensión compatible antes que endpoints nuevos.

## Modelo de Datos Propuesto

### `Oportunidad`

Agregar:

```js
owner: { type: ObjectId, ref: 'User', required: true }
ownerType: { type: String, enum: ['cliente', 'contratista'], required: true }
createdBy: { type: ObjectId, ref: 'User', required: true }
createdByRole: { type: String, enum: ['cliente', 'contratista'], required: true }
```

Mantener:

```js
contratista
camioneroAsignado
estado
negociacion
```

Compatibilidad:

Para oportunidades antiguas:

```text
owner = contratista
ownerType = contratista
createdBy = contratista
createdByRole = contratista
```

## UI Copy

Selector de rol:

```text
¿Cómo usarás TrackNariño?
```

Opciones:

```text
Camionero
Contratista
Cliente
```

Origen de oportunidad:

```text
Creado por: Cliente
```

```text
Creado por: Contratista
```

Estados vacíos:

```text
Aún no tienes cargas activas.
Crea tu primera carga para encontrar transporte seguro en Nariño.
```

## Restricciones

- No puede tomar viajes.
- No puede conducir.
- No puede gestionar flota.
- No puede ver diagnósticos operativos.
- No puede ver todos los camioneros.
- No puede ver alertas globales.
- No puede cambiar manualmente ownership.

## Criterios de Aceptación

- Usuario Google nuevo puede elegir `Cliente`.
- `Cliente` entra a un home propio.
- Cliente puede crear carga sin formularios largos.
- La oportunidad queda con `ownerType = cliente`.
- Listados muestran "Creado por: Cliente".
- Filtro Clientes muestra oportunidades de clientes.
- Filtro Contratistas muestra oportunidades de contratistas.
- Cliente ve solo sus viajes.
- Cliente ve tracking solo de viajes propios.
- Cliente no puede aceptar/tomar viaje.
- Cliente no puede acceder a flota.

## Riesgos

| Severidad | Riesgo | Mitigación |
|---|---|---|
| CRÍTICO | Cliente ve GPS ajeno | Validar ownership en backend y Socket.IO |
| ALTO | Copiar home contratista y dejar permisos incorrectos | Crear home cliente específico |
| ALTO | Crear carga sin owner real | Backend asigna owner desde JWT |
| MEDIO | Duplicar lógica de oportunidades | Reutilizar service y componentes con permisos claros |
| MEDIO | ETA falsa | Mostrar ETA solo si existe cálculo real |

## Implementación Recomendada

1. Agregar rol en backend y Flutter.
2. Agregar selección de rol post-Google.
3. Crear `ClienteHomeScreen` mínimo.
4. Extender oportunidades con owner/origen.
5. Agregar filtros.
6. Proteger tracking y alertas por ownership.
7. Agregar historial cliente.
