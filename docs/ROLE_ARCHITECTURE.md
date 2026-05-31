# Role Architecture

Fecha: 2026-05-30

Estado: especificación de arquitectura previa a implementación.

## Roles Actuales

### `camionero`

Responsabilidad actual:

- Ver oportunidades disponibles.
- Aceptar viajes.
- Enviar ubicación.
- Crear alertas.
- Iniciar viaje.
- Ver ruta activa.
- Gestionar perfil básico y método de pago.

Problemas:

- Disponibilidad se maneja localmente en Flutter.
- Puede acceder a crear oportunidad en backend según configuración actual de rutas.
- Documentación y verificación son insuficientes para producción.

### `contratista`

Responsabilidad actual:

- Crear oportunidades.
- Ver flota.
- Ver ubicación de camioneros afiliados/asignados.
- Negociar ofertas.
- Finalizar viajes.
- Consultar historial.

Problemas:

- Se usa como actor operativo y casi administrativo.
- Puede acceder a listados sensibles.
- No representa al dueño final de la carga necesariamente.

### `usuario`

Responsabilidad actual:

- Existe en enum backend.
- No tiene flujo de producto real.

Problemas:

- Flutter lo considera rol inválido.
- Puede ser útil como estado transitorio, pero no debe operar cargas.

## Nuevo Rol: `cliente`

`cliente` representa al dueño de la carga o usuario que necesita transportar mercancía.

No reemplaza a `contratista`.

Relación recomendada:

```text
cliente -> crea carga/solicitud
contratista -> opera/capacita/asigna/gestiona
camionero -> ejecuta el transporte
```

## Matriz de Permisos

| Acción | Cliente | Contratista | Camionero |
|---|---:|---:|---:|
| Crear carga | Sí | Sí | No |
| Publicar oportunidad | Sí | Sí | No |
| Ver oportunidades propias | Sí | Sí | No aplica |
| Ver oportunidades disponibles | No | Según modelo | Sí |
| Tomar viaje | No | No | Sí |
| Conducir viaje | No | No | Sí |
| Ver viajes asociados | Sí | Sí | Sí |
| Ver ubicación realtime | Solo viajes propios | Flota/viajes autorizados | Solo propio/viaje |
| Crear alertas | Sí, asociadas | Sí, asociadas | Sí |
| Ver alertas | Relacionadas | Relacionadas/zona | Relacionadas/zona |
| Gestionar flota | No | Sí | No |
| Gestionar vehículos | No | Sí | Propio limitado |
| Gestionar conductores | No | Sí | No |
| Confirmar entrega | Sí | Sí | No |
| Subir evidencia entrega | No | Sí | Sí |
| Calificar servicio | Sí | Sí | Sí |

## Reglas de Autorización

### Principios

1. Autenticación no implica autorización.
2. Cada recurso debe tener propietario o relación operacional.
3. El backend no debe confiar en IDs enviados por el frontend sin verificar relación.
4. El rol debe viajar en JWT solo como ayuda; la base de datos sigue siendo fuente de verdad.
5. Rutas sensibles deben comprobar ownership, no solo rol.

### Recursos con Ownership Obligatorio

| Recurso | Owner recomendado |
|---|---|
| Oportunidad/Carga | `ownerType` + `owner` |
| Viaje | Oportunidad + camionero asignado |
| Ubicación | Camionero + viaje activo |
| Alerta | Creador + viaje/zona opcional |
| Documento | Usuario/vehículo/viaje |
| Evidencia entrega | Viaje |
| Chat | Viaje |

## Modelo Recomendado para `User`

Campos existentes a conservar:

- `nombre`
- `correo`
- `tipoUsuario`
- `estadoAprobacion`
- `deviceToken`
- `camion`
- `camionerosAfiliados`

Campos propuestos:

```js
authProvider: 'password' | 'google'
googleSub: String
fotoPerfil: String
rolConfigurado: Boolean
estadoPerfil: 'incompleto' | 'completo'
```

Enum actualizado:

```js
['usuario', 'camionero', 'contratista', 'cliente']
```

Uso recomendado:

- `usuario`: estado transitorio sin permisos operativos.
- `cliente`: puede crear y supervisar cargas.
- `contratista`: opera capacidad/flota.
- `camionero`: ejecuta viajes.

## Navegación Flutter por Rol

### AuthWrapper actual

Actualmente enruta:

```text
camionero -> CamioneroHomeScreen
contratista -> ContratistaHomeScreen
otro -> invalidRole
```

### AuthWrapper propuesto

```text
sin sesión -> LoginScreen
sesión Google sin rol -> RoleSelectionScreen
camionero -> CamioneroHomeScreen
contratista -> ContratistaHomeScreen
cliente -> ClienteHomeScreen
rol desconocido -> pantalla de error bloqueante
```

## Cliente Home Propuesto

Tabs mínimas:

1. Cargas
2. Crear
3. Seguimiento
4. Alertas
5. Perfil

No debe reutilizar sin control el home de contratista porque los permisos son distintos.

## Compatibilidad

No romper APIs existentes:

- Mantener `contratista` en `Oportunidad`.
- Agregar ownership nuevo de forma compatible.
- Mantener rutas actuales mientras se introducen filtros nuevos.
- Documentar contratos duplicados antes de retirarlos.

## Reglas de Migración

### Paso 1

Agregar `cliente` al enum y navegación sin cambiar lógica de oportunidades.

### Paso 2

Agregar ownership a oportunidades:

```js
owner: ObjectId
ownerType: 'cliente' | 'contratista'
createdBy: ObjectId
createdByRole: 'cliente' | 'contratista'
```

### Paso 3

Actualizar listados:

- Cliente ve propias.
- Contratista ve propias y asignadas a su operación.
- Camionero ve disponibles que pueda tomar.

### Paso 4

Actualizar realtime:

- Rooms por viaje.
- Rooms por owner.
- Eventos filtrados por rol.

## Riesgos

| Severidad | Riesgo | Mitigación |
|---|---|---|
| CRÍTICO | Agregar `cliente` en backend sin Flutter | AuthWrapper rompería sesión |
| CRÍTICO | Cliente pueda ver ubicación ajena | Ownership obligatorio |
| ALTO | Duplicar lógica contratista/cliente | Crear servicios compartidos por dominio, no copiar pantallas completas |
| ALTO | Romper oportunidades existentes | Mantener `contratista` y agregar campos nuevos opcionales |
| MEDIO | `usuario` queda ambiguo | Usarlo solo como estado sin rol operativo |

## Decisión Recomendada

Implementar roles en este orden:

1. `cliente` en enum y AuthWrapper.
2. Selección de rol post-Google.
3. Home cliente mínimo conectado a datos reales.
4. Ownership de oportunidades.
5. Filtros y permisos avanzados.
