# Tareas pendientes — Script de creación de la base de datos MySQL

**Proyecto:** Gestor de Citas de un Centro Médico (`sistema_citas`)
**Fecha de revisión:** 13/11/2026
**Motor verificado:** MariaDB 10.4.32 (XAMPP)
**Alcance:** script SQL completo con estructura, restricciones, datos, funciones, procedimientos almacenados, vistas, triggers y objetos de automatización. Sin videos.

---

## 1. Estado actual verificado

### Ya existe y está cargado en la base

- 8 tablas: `usuarios`, `pacientes`, `medicos`, `especialidades`, `horarios_medicos`, `citas`, `notificaciones_config`, `citas_historial`.
- 5 funciones: `fn_calcular_edad`, `fn_validar_anticipacion_24h`, `fn_obtener_perfil_paciente_json`, `fn_obtener_perfil_medico_json`, `fn_obtener_tasa_completacion`.
- 22 procedimientos almacenados (`sp_registrar_cita`, `sp_cancelar_cita`, `sp_reprogramar_cita`, etc.).
- 7 vistas: `vw_agenda_paciente`, `vw_agenda_medico`, `vw_medicos_horarios`, `vw_recordatorios_pendientes`, `vw_reporte_general_citas`, `vw_vista_medico_pacientes`, `vw_vista_admin_medicosypacientes`.
- Scripts separados: `01_esquema.sql`, `02_funciones.sql`, `03_procedimientos.sql`, `04_vistas.sql`, `05_transactions.sql` y pruebas en `database/tests/`.
- Pruebas de procedimientos, funciones, vistas y transacciones documentadas en el README.

### Faltantes principales

- **0 triggers** en toda la base.
- **0 eventos** programados.
- **No existe un script único consolidado** de creación; la instalación depende de ejecutar 4 archivos en orden.
- **No existe tabla ni flujo real de recuperación de contraseña**; el procedimiento actual siempre lanza error.
- **No hay tabla de notificaciones enviadas** ni historial de recordatorios.
- **Los datos de prueba están desactualizados** (fechas de octubre 2026 ya pasadas) y la base actual contiene residuos de pruebas (5 citas en lugar de las 3 del esquema).
- **No hay diccionario de datos, diagrama ER ni inventario de objetos** como documentación de entrega.

---

## 2. Prioridad

| Prioridad | Significado |
|---|---|
| **P0** | Bloqueante para considerar el script completo y entregable. |
| **P1** | Necesario para que el sistema funcione de punta a punta. |
| **P2** | Mejora de calidad, seguridad o mantenibilidad. |

---

## 3. Tareas P0 — Entregable mínimo

### 3.1 Script único de creación

- [ ] Crear `database/sistema_citas_completo.sql` que incluya, en orden:
  - [ ] `DROP DATABASE IF EXISTS` / `CREATE DATABASE` con `utf8mb4` y `utf8mb4_unicode_ci`.
  - [ ] `SET NAMES utf8mb4`, `SET time_zone`, `SET sql_mode` y `FOREIGN_KEY_CHECKS = 0/1`.
  - [ ] Creación de las 8 tablas con PK, FK, `UNIQUE`, `CHECK` e índices.
  - [ ] Datos iniciales (especialidades, usuarios demo, pacientes, médicos, horarios, citas, historial y notificaciones).
  - [ ] Funciones.
  - [ ] Procedimientos almacenados.
  - [ ] Vistas.
  - [ ] Triggers.
  - [ ] Eventos (si se aprueban como parte del alcance).
  - [ ] Bloque final de verificación con conteo de objetos.
- [ ] Mantener los archivos modulares `01`–`05` y agregar `06_triggers.sql` (o el número que corresponda), pero el script consolidado debe ser la entrega principal.
- [ ] Verificar que el script se ejecute **desde cero** sin errores y que pueda volver a ejecutarse sin fallar.
- [ ] Separar claramente “instalación limpia” de “reinicio destructivo”: advertir en el encabezado que `DROP DATABASE` borra todo.
- [ ] Actualizar el README con el nuevo orden de ejecución y el comando de instalación completa.

### 3.2 Triggers (actualmente no existe ninguno)

Crear `database/06_triggers.sql` con, como mínimo:

- [ ] `trg_usuarios_after_insert`: crear automáticamente la fila en `notificaciones_config` para usuarios nuevos (especialmente pacientes), con valores por defecto.
- [ ] `trg_pacientes_before_insert`: validar que el `id_usuario` tenga rol `paciente`.
- [ ] `trg_medicos_before_insert`: validar que el `id_usuario` tenga rol `medico`.
- [ ] `trg_horarios_before_insert` / `trg_horarios_before_update`: validar `hora_inicio < hora_fin`; exigir `dia_semana` en horarios regulares y `fecha` en excepciones; impedir rangos inválidos.
- [ ] `trg_citas_before_insert`: validación de defensa en profundidad (fecha futura, anticipación mínima, horario del médico, excepción, choque de médico y choque de paciente).
- [ ] `trg_citas_before_update`: validar transiciones de estado permitidas y evitar cambios directos que salten las reglas del negocio.
- [ ] `trg_citas_after_update`: registrar automáticamente en `citas_historial` los cambios de estado hechos por cualquier vía.
- [ ] `trg_citas_before_delete`: impedir borrar citas con historial o registrar la eliminación en una tabla de auditoría.
- [ ] `trg_usuarios_before_update`: impedir desactivar o cambiar el rol del último administrador activo.
- [ ] Definir una estrategia para no duplicar historial: hoy los procedimientos insertan en `citas_historial` manualmente; si el trigger también lo hace, se duplicarán filas. Elegir una de estas opciones:
  - [ ] Mover el registro de historial al trigger y quitar los `INSERT` de los procedimientos.
  - [ ] Dejar el historial en los procedimientos y usar el trigger solo para cambios directos, con una bandera o tabla auxiliar.

### 3.3 Datos iniciales completos y coherentes

- [ ] Reemplazar las fechas fijas de octubre 2026 por fechas relativas, por ejemplo `DATE_ADD(CURDATE(), INTERVAL 7 DAY)`, para que la demo siempre tenga citas próximas.
- [ ] Incluir ejemplos de todos los estados: `programada`, `confirmada`, `en_curso`, `completada`, `cancelada`, `reprogramada`.
- [ ] Insertar historial coherente para las citas que ya nacen completadas, canceladas o reprogramadas.
- [ ] Crear `notificaciones_config` para **todos** los pacientes (hoy falta María Fernández, usuario 6).
- [ ] Agregar al menos una excepción de horario (`tipo = 'excepcion'`) de ejemplo.
- [ ] Agregar más especialidades y médicos si se necesita cubrir el catálogo de la interfaz (hoy solo 4 especialidades y 2 médicos).
- [ ] Incluir casos de prueba útiles: un usuario inactivo, una cita cancelada, una cita reprogramada y una cita en curso.
- [ ] Documentar las credenciales demo. El hash actual corresponde a la contraseña `password`; indicarlo explícitamente o cambiarlo por una contraseña segura de demo.
- [ ] Limpiar los residuos de pruebas de la base actual y dejar la base en el estado exacto que produce el script.

### 3.4 Recuperación de contraseña

- [ ] Decidir si el módulo entra en el alcance de la entrega.
- [ ] Si entra:
  - [ ] Crear tabla `password_reset_tokens` (`id_usuario`, `token_hash`, `expira_en`, `usado`, `creado_en`).
  - [ ] Implementar `sp_solicitar_recuperacion_password` para insertar el token con vencimiento (por ejemplo, 1 hora).
  - [ ] Implementar `sp_validar_token_recuperacion` y `sp_consumir_token_recuperacion`.
  - [ ] Implementar `sp_restablecer_password_con_token` con validación de expiración y uso único.
  - [ ] Agregar trigger o evento para limpiar tokens vencidos.
- [ ] Si no entra: eliminar el procedimiento actual o documentarlo como “no implementado” para que no parezca un error del script.

### 3.5 Verificación de instalación

- [ ] Script de verificación que compruebe:
  - [ ] 8 tablas base (o las que resulten del alcance final).
  - [ ] 5 funciones, 22 procedimientos y 7 vistas como mínimo.
  - [ ] Triggers creados (conteo esperado).
  - [ ] Conteo de datos iniciales por tabla.
  - [ ] Existencia de al menos una cita próxima, una completada y una cancelada.
- [ ] Ejecutar el script consolidado en una base limpia y adjuntar la salida como evidencia.
- [ ] Ejecutar las pruebas existentes y corregir cualquier prueba que dependa de IDs o fechas fijas.

---

## 4. Tareas P1 — Funcionalidad y consistencia

### 4.1 Procedimientos almacenados

- [ ] Corregir `sp_registrar_cita`: además del choque del médico, validar que el **paciente** no tenga otra cita activa en la misma fecha y hora.
- [ ] Corregir `sp_reprogramar_cita`: aplicar la misma validación de choque del paciente.
- [ ] Revisar `sp_obtener_horarios_disponibles_medico`: hoy devuelve la jornada y las horas ocupadas, pero no genera la lista de slots libres. Implementar generación de intervalos (requiere definir duración de consulta, por ejemplo 30 minutos).
- [ ] Revisar `sp_obtener_metricas_dashboard_admin`: `citas_hoy` cuenta también canceladas y completadas. Definir si debe contar solo citas activas.
- [ ] Endurecer `sp_admin_cambiar_estado_cita`: validar transiciones permitidas o documentar que el administrador puede forzar cualquier estado.
- [ ] Agregar procedimientos de lectura que la interfaz necesita y hoy no existen:
  - [ ] `sp_listar_especialidades`.
  - [ ] `sp_listar_medicos` con especialidad, estado y horarios.
  - [ ] `sp_listar_citas_admin` con filtros por fecha, estado, médico y paciente.
  - [ ] `sp_listar_horarios_medico` y `sp_listar_excepciones_medico`.
  - [ ] `sp_obtener_historial_cita`.
  - [ ] `sp_buscar_pacientes` / `sp_buscar_medicos`.
- [ ] Agregar procedimientos de escritura faltantes:
  - [ ] `sp_actualizar_perfil_medico` (teléfono, especialidad, datos profesionales).
  - [ ] `sp_actualizar_datos_usuario` (nombre, email, teléfono).
  - [ ] `sp_eliminar_excepcion_horario` o `sp_desbloquear_fecha_medico`.
  - [ ] `sp_registrar_notificacion` / `sp_marcar_notificacion_enviada` si se agrega la tabla correspondiente.
- [ ] Agregar motivo de cancelación y observaciones al historial (`citas_historial.motivo` o `observacion`) para auditoría real.

### 4.2 Vistas

- [ ] Agregar `activo`, fecha de creación y especialidad a `vw_vista_admin_medicosypacientes`; hoy el administrador no puede ver el estado del usuario desde la vista.
- [ ] Agregar email, última cita y total de citas a `vw_vista_medico_pacientes`.
- [ ] Crear `vw_recordatorios_2h` o unificar `vw_recordatorios_pendientes` para que `recordatorio_2h` se use realmente.
- [ ] Crear `vw_historial_citas` con cita, estados, usuario que cambió y fecha.
- [ ] Crear `vw_disponibilidad_medico` con slots libres por médico y fecha.
- [ ] Crear `vw_citas_admin` con datos completos para la tabla del panel administrativo.
- [ ] Revisar `SQL SECURITY` de las vistas (`DEFINER` vs `INVOKER`) y documentar el criterio.
- [ ] Verificar que las vistas no expongan datos sensibles innecesarios (`password_hash` no está expuesto, correcto).

### 4.3 Integridad y restricciones

- [ ] Implementar una garantía a nivel de base para evitar doble reserva médico + fecha + hora. MySQL/MariaDB no tiene índices parciales; usar trigger `BEFORE INSERT/UPDATE` o una columna generada que anule la unicidad cuando la cita está cancelada.
- [ ] Agregar `CHECK` para rangos de hora y coherencia de `horarios_medicos`.
- [ ] Agregar `CHECK` para `tipo_sangre` y validaciones básicas de DNI/teléfono si se consideran parte del alcance.
- [ ] Revisar `ON DELETE` de `citas` y `citas_historial`: hoy el borrado de un médico o paciente con citas queda restringido por las FK; documentar la política de baja lógica.
- [ ] Añadir índices para reportes: `citas(fecha, estado)`, `citas(id_medico, fecha, estado)`, `citas_historial(id_cita, cambiado_en)`.
- [ ] Evaluar una tabla `auditoria` general para altas/bajas/cambios de usuarios y horarios.

### 4.4 Notificaciones

- [ ] Decidir si se almacena el historial de notificaciones. Si sí, crear `notificaciones` con `id_usuario`, `id_cita`, `canal`, `estado`, `enviado_en`, `error`.
- [ ] Crear vista de recordatorios pendientes que excluya los ya enviados.
- [ ] Documentar que el envío real de email/WhatsApp queda fuera de la base de datos y se hará desde el backend o un cron.

### 4.5 Eventos y automatización

- [ ] Evaluar agregar el estado `no_asistio` para citas vencidas no atendidas.
- [ ] Crear evento que marque citas vencidas como `no_asistio` (si se aprueba el estado).
- [ ] Crear evento de limpieza de tokens vencidos.
- [ ] Documentar que el Event Scheduler debe estar activo (`event_scheduler = ON`) y cómo hacerlo en XAMPP.
- [ ] Si no se usan eventos, dejar claro que los recordatorios se ejecutan desde el backend.

---

## 5. Tareas P2 — Calidad, pruebas y documentación

### 5.1 Pruebas

- [ ] Crear `database/tests/pruebas_triggers.sql` con casos válidos e inválidos para cada trigger.
- [ ] Aislar las pruebas: hoy modifican la base real y dejan datos residuales. Usar una base de pruebas (`sistema_citas_test`) o un script de reinicio previo.
- [ ] Evitar dependencias de IDs fijos (`id_paciente = 1`, `id_medico = 1`); obtenerlos por email o DNI.
- [ ] Probar concurrencia de reservas: dos sesiones intentando el mismo médico/fecha/hora.
- [ ] Probar todas las rutas de error de los procedimientos, no solo las principales.
- [ ] Probar el script consolidado dos veces seguidas para verificar idempotencia.
- [ ] Probar la instalación en una base vacía y en una base existente.
- [ ] Agregar pruebas de las vistas nuevas y de los procedimientos nuevos.

### 5.2 Documentación de entrega

- [ ] Crear diccionario de datos: tabla, columna, tipo, nulo, clave, descripción.
- [ ] Crear diagrama ER (imagen o Mermaid) en `docs/`.
- [ ] Crear inventario de objetos: tablas, funciones, procedimientos, vistas, triggers y eventos con una línea de propósito.
- [ ] Documentar el orden de instalación y las dependencias entre scripts.
- [ ] Documentar credenciales demo y advertir que son solo para desarrollo.
- [ ] Documentar el modelo de negocio: estados de cita, regla de 24 horas, horarios regulares/excepciones, auditoría.
- [ ] Incluir en el README la sección “Script completo” y la sección “Triggers”.
- [ ] Adjuntar evidencia de ejecución: salida de `SHOW TABLES`, `SHOW TRIGGERS`, conteos y pruebas.

### 5.3 Seguridad y operación

- [ ] No usar `root` sin contraseña como usuario de aplicación; crear un usuario MySQL con permisos mínimos (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `EXECUTE`).
- [ ] Crear `database/07_usuarios_permisos.sql` (opcional, según el alcance de la entrega).
- [ ] Documentar que el script `01_esquema.sql` hace `DROP DATABASE` y que no debe ejecutarse en producción.
- [ ] Agregar script de respaldo/restauración (`mysqldump`) como anexo opcional.
- [ ] Revisar que los `DEFINER` de funciones, procedimientos, vistas y triggers no dependan de un usuario local específico.

---

## 6. Decisiones que deben tomarse antes de implementar

- [ ] ¿La entrega es un **solo archivo SQL** o se mantienen los archivos modulares?
- [ ] ¿La recuperación de contraseña entra en el alcance de la base de datos?
- [ ] ¿El historial de cambios se centraliza en triggers o se mantiene en los procedimientos?
- [ ] ¿Se agrega el estado `no_asistio`?
- [ ] ¿Se agrega duración de consulta para generar slots disponibles?
- [ ] ¿Se almacenan notificaciones enviadas?
- [ ] ¿Se incluyen eventos programados o la automatización queda en el backend?
- [ ] ¿Se amplía el esquema con datos profesionales del médico (colegiatura, consultorio, biografía)?

---

## 7. Criterios de aceptación del entregable

Se considera completo cuando:

- [ ] Un único comando o archivo crea la base desde cero sin errores.
- [ ] El script incluye estructura, restricciones, datos, funciones, procedimientos, vistas y triggers.
- [ ] Existen triggers funcionales y probados para las reglas críticas del negocio.
- [ ] Los datos iniciales permiten demostrar todos los módulos con fechas vigentes.
- [ ] No quedan procedimientos que siempre fallen ni funcionalidades documentadas como “pendientes” dentro del SQL.
- [ ] Las pruebas se ejecutan sin dejar residuos y validan los objetos nuevos.
- [ ] La documentación permite a otra persona instalar, entender y verificar la base sin ayuda.
- [ ] El README refleja el estado real y el orden de ejecución.

---

## 8. Orden sugerido de trabajo

1. Definir alcance y decisiones de la sección 6.
2. Corregir datos iniciales y dejar la base limpia.
3. Implementar triggers y resolver la estrategia de historial.
4. Corregir y completar procedimientos y vistas.
5. Crear el script consolidado.
6. Crear y ejecutar las pruebas de triggers, instalación y concurrencia.
7. Generar diccionario de datos, diagrama ER e inventario.
8. Actualizar README y preparar evidencia de entrega.
