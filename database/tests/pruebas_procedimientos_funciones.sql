USE sistema_citas;
SET NAMES utf8mb4;

-- ====================================================================
-- PRUEBAS DE PROCEDIMIENTOS ALMACENADOS Y FUNCIONES
-- --------------------------------------------------------------------
-- IMPORTANTE: este script provoca errores a proposito para validar las
-- restricciones. Ejecutarlo con la opcion --force para que continue:
--
--   mysql --force -u root < database/tests/pruebas_procedimientos_funciones.sql
--
-- Requiere haber ejecutado 01_esquema.sql, 02_funciones.sql,
-- Requiere haber instalado database/sistema_citas_completo.sql.
-- ====================================================================

-- Fechas dinamicas: el proximo lunes con al menos 8 dias de anticipacion.
-- Asi las pruebas no dependen de la fecha real en que se ejecuten.
SET @lunes     = DATE_ADD(CURDATE(), INTERVAL (14 - WEEKDAY(CURDATE())) DAY);
SET @martes    = DATE_ADD(@lunes, INTERVAL 1 DAY);
SET @miercoles = DATE_ADD(@lunes, INTERVAL 2 DAY);
SET @jueves    = DATE_ADD(@lunes, INTERVAL 3 DAY);
SET @viernes   = DATE_ADD(@lunes, INTERVAL 4 DAY);
SET @domingo   = DATE_ADD(@lunes, INTERVAL 6 DAY);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_registrar_cita
-- ---------------------------------------------------------
-- PRUEBA 1 - EXITO: lunes, dentro del horario del Dr. Torres (08:00-14:00)
CALL sp_registrar_cita(1, 1, @lunes, '11:00:00', 'Chequeo general');
SET @cita_ana = LAST_INSERT_ID();

-- PRUEBA 2 - ERROR POR HORA: fuera del horario del medico
CALL sp_registrar_cita(2, 1, @lunes, '16:00:00', 'Dolor de cabeza');

-- PRUEBA 3 - ERROR POR CHOQUE: misma fecha/hora que la cita anterior
CALL sp_registrar_cita(3, 1, @lunes, '11:00:00', 'Consulta de resultados');

-- PRUEBA 4 - ERROR POR DIA: domingo no trabaja
CALL sp_registrar_cita(1, 1, @domingo, '10:00:00', 'Urgencia de domingo');

-- PRUEBA 5 - EXITO: paciente y medico activos, hora valida
CALL sp_registrar_cita(3, 1, @martes, '10:30:00', 'Control general');
SET @cita_maria = LAST_INSERT_ID();

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_cancelar_cita
-- ---------------------------------------------------------
-- EXITO: Ana (usuario 4) cancela su propia cita futura
CALL sp_cancelar_cita(@cita_ana, 4);

-- ERROR: intentar cancelar una cita ya cancelada
CALL sp_cancelar_cita(@cita_ana, 4);

-- ERROR: intentar cancelar una cita completada
CALL sp_cancelar_cita(1, 4);

-- ERROR: un paciente no puede cancelar la cita de otro
CALL sp_cancelar_cita(@cita_maria, 4);

-- COMPROBAR HISTORIAL DE CAMBIO DE ESTADO
SELECT *
FROM citas_historial
ORDER BY cambiado_en DESC;

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_reprogramar_cita
-- ---------------------------------------------------------
-- PRUEBA 1 - EXITO: mover la cita de Maria del martes al jueves
CALL sp_reprogramar_cita(@cita_maria, @jueves, '11:00:00', 6);

-- PRUEBA 2 - ERROR DE ESTADO: cita completada, no se puede reprogramar
CALL sp_reprogramar_cita(1, @jueves, '12:00:00', 4);

-- PRUEBA 3 - ERROR POR CHOQUE: intentar reprogramar a un horario ocupado
INSERT INTO citas (id_paciente, id_medico, fecha, hora, motivo, estado)
VALUES (1, 1, @jueves, '11:30:00', 'Prueba de choque', 'programada');
SET @cita_bloqueo = LAST_INSERT_ID();

CALL sp_reprogramar_cita(@cita_maria, @jueves, '11:30:00', 6);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_listar_medicos_por_especialidad
-- ---------------------------------------------------------
-- id_especialidad = 2 -> Cardiologia
CALL sp_listar_medicos_por_especialidad(2);

-- id_especialidad = 3 -> Pediatria
CALL sp_listar_medicos_por_especialidad(3);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_actualizar_preferencias
-- ---------------------------------------------------------
CALL sp_actualizar_preferencias(4, 1, 1, 1, 1);

SELECT u.nombre, n.*
FROM notificaciones_config n
INNER JOIN usuarios u ON n.id_usuario = u.id_usuario
WHERE n.id_usuario = 4;

-- PRUEBA DE VALIDACION: las preferencias solo aceptan 0 o 1
CALL sp_actualizar_preferencias(4, 2, 0, 1, 0);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_actualizar_password
-- ---------------------------------------------------------
CALL sp_actualizar_password(
  'ana@gmail.com',
  '$2y$10$NUEVOHASHENCRIPTADOPARALAPRUEBA1234567890'
);

SELECT nombre, email, password_hash
FROM usuarios
WHERE email = 'ana@gmail.com';

-- ERROR: correo inexistente
CALL sp_actualizar_password('noexiste@test.com', '$2y$10$hash');

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_citas_paciente
-- ---------------------------------------------------------
CALL sp_obtener_citas_paciente(1);
CALL sp_obtener_citas_paciente(3);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_registrar_paciente
-- ---------------------------------------------------------
CALL sp_registrar_paciente(
  'Laura Gomez',
  'laura@gmail.com',
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  '987654333',
  '77777777'
);

SELECT u.id_usuario, u.nombre, u.email, p.id_paciente, nc.notif_email, nc.recordatorio_24h
FROM usuarios u
LEFT JOIN pacientes p ON p.id_usuario = u.id_usuario
LEFT JOIN notificaciones_config nc ON nc.id_usuario = u.id_usuario
WHERE u.email = 'laura@gmail.com';

-- ERROR: DNI duplicado (debe revertir toda la transaccion)
CALL sp_registrar_paciente(
  'Laura Repetida',
  'laura2@gmail.com',
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  '987654334',
  '77777777'
);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_metricas_dashboard_paciente
-- ---------------------------------------------------------
CALL sp_obtener_metricas_dashboard_paciente(1);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_actualizar_perfil_paciente
-- ---------------------------------------------------------
CALL sp_actualizar_perfil_paciente(
  1,
  '987654998',
  '1995-08-15',
  'Femenino',
  'O+'
);

SELECT * FROM pacientes WHERE id_paciente = 1;

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_horarios_disponibles_medico
-- ---------------------------------------------------------
CALL sp_obtener_horarios_disponibles_medico(1, @lunes);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_solicitar_recuperacion_password
-- PRUEBAS PARA: sp_obtener_historial_cita
-- ---------------------------------------------------------
CALL sp_obtener_historial_cita(@cita_maria);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_metricas_dashboard_medico
-- ---------------------------------------------------------
CALL sp_obtener_metricas_dashboard_medico(1);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_atender_cita_medica
-- ---------------------------------------------------------
-- EXITO: el medico 1 completa la cita @cita_bloqueo que le pertenece
CALL sp_atender_cita_medica(@cita_bloqueo, 1, 'Paciente estable, sin hallazgos.', 'completada');

-- EXITO: una cita reprogramada tambien puede ser atendida
CALL sp_atender_cita_medica(@cita_maria, 1, 'Inicio de consulta.', 'en_curso');

-- ERROR: el medico 2 no puede atender una cita del medico 1
CALL sp_atender_cita_medica(@cita_maria, 2, 'Intento no autorizado', 'completada');

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_guardar_horario_regular_medico
-- ---------------------------------------------------------
CALL sp_guardar_horario_regular_medico(1, 7, '09:00:00', '13:00:00');

SELECT * FROM horarios_medicos WHERE id_medico = 1 ORDER BY dia_semana;

-- ERROR: rango horario invalido
CALL sp_guardar_horario_regular_medico(1, 7, '13:00:00', '09:00:00');

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_bloquear_fecha_medico
-- ---------------------------------------------------------
CALL sp_bloquear_fecha_medico(1, @viernes, '08:00:00', '10:00:00', 'Capacitacion');

SELECT * FROM horarios_medicos
WHERE id_medico = 1 AND tipo = 'excepcion';

-- ERROR: no se puede bloquear un rango que ya tiene citas
CALL sp_bloquear_fecha_medico(1, @jueves, '11:00:00', '12:00:00', 'Bloqueo invalido');

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_listar_pacientes_por_medico
-- ---------------------------------------------------------
CALL sp_listar_pacientes_por_medico(1);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_metricas_dashboard_admin
-- ---------------------------------------------------------
CALL sp_obtener_metricas_dashboard_admin();

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_registrar_medico
-- ---------------------------------------------------------
CALL sp_registrar_medico(
  'Dr. Nuevo Especialista',
  'nuevo.medico@test.com',
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  '555000111',
  '88888888',
  1,
  'Consultorio 303',
  30
);
SET @nuevo_usuario_medico = (
    SELECT id_usuario FROM usuarios WHERE email = 'nuevo.medico@test.com'
);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_cambiar_estado_usuario
-- ---------------------------------------------------------
CALL sp_cambiar_estado_usuario(@nuevo_usuario_medico, 0);

SELECT id_usuario, nombre, rol, activo
FROM usuarios
WHERE id_usuario = @nuevo_usuario_medico;

-- ERROR: el estado solo admite 0 o 1
CALL sp_cambiar_estado_usuario(@nuevo_usuario_medico, 5);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_admin_cambiar_estado_cita
-- ---------------------------------------------------------
-- ERROR esperado: no se permite volver de en_curso a confirmada.
CALL sp_admin_cambiar_estado_cita(@cita_maria, 'confirmada', 1);
CALL sp_admin_cambiar_estado_cita(@cita_maria, 'completada', 1);

-- ERROR: el usuario 4 no es administrador
CALL sp_admin_cambiar_estado_cita(@cita_maria, 'cancelada', 4);

-- ---------------------------------------------------------
-- PRUEBAS PARA: sp_obtener_reportes_estadisticos
-- ---------------------------------------------------------
CALL sp_obtener_reportes_estadisticos();

-- ====================================================================
-- PRUEBAS DE FUNCIONES
-- ====================================================================

-- FUNCION: fn_calcular_edad
SELECT
    p.id_paciente,
    u.nombre,
    p.fecha_nacimiento,
    fn_calcular_edad(p.fecha_nacimiento) AS edad_actual
FROM pacientes p
INNER JOIN usuarios u ON p.id_usuario = u.id_usuario;

-- FUNCION: fn_validar_anticipacion_24h
SELECT fn_validar_anticipacion_24h(@lunes, '10:00:00') AS es_valido_futuro;
SELECT fn_validar_anticipacion_24h(CURDATE(), CURTIME()) AS es_valido_hoy;

-- FUNCION: fn_obtener_perfil_paciente_json
SELECT fn_obtener_perfil_paciente_json(1) AS perfil_paciente;

-- FUNCION: fn_obtener_perfil_medico_json
SELECT fn_obtener_perfil_medico_json(1) AS perfil_medico;

-- FUNCION: fn_obtener_tasa_completacion
SELECT fn_obtener_tasa_completacion() AS tasa_completacion;
