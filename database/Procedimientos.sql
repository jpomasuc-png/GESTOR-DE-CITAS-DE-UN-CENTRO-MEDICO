USE sistema_citas;
-- =============================================================
-- PROCEDIMIENTOS ALMACENADOS
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. PROCEDIMIENTO ALMACENADO: Registrar Cita 
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_registrar_cita (
    IN p_paciente_id INT,
    IN p_medico_id INT,
    IN p_fecha DATE,
    IN p_hora TIME,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_hora_inicio TIME;
    DECLARE v_hora_fin TIME;
    DECLARE v_horarios_validos INT DEFAULT 0;
    DECLARE v_citas_existentes INT;
    DECLARE v_excepciones INT DEFAULT 0;
    DECLARE v_usuario_activo INT DEFAULT 0;
    DECLARE v_medico_bloqueo INT;
    DECLARE v_dia_semana TINYINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_fecha IS NULL OR p_hora IS NULL OR p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La fecha, hora y motivo son obligatorios.';
    END IF;

    IF p_fecha < CURDATE() OR fn_validar_anticipacion_24h(p_fecha, p_hora) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita debe solicitarse con al menos 24 horas de anticipacion.';
    END IF;

    SELECT COUNT(*) INTO v_usuario_activo
    FROM pacientes p
    INNER JOIN usuarios u ON u.id_usuario = p.id_usuario
    WHERE p.id_paciente = p_paciente_id AND u.activo = 1;

    IF v_usuario_activo = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El paciente no existe o esta inactivo.';
    END IF;

    SELECT COUNT(*) INTO v_usuario_activo
    FROM medicos m
    INNER JOIN usuarios u ON u.id_usuario = m.id_usuario
    WHERE m.id_medico = p_medico_id AND u.activo = 1;

    IF v_usuario_activo = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El medico no existe o esta inactivo.';
    END IF;

    SELECT id_medico INTO v_medico_bloqueo
    FROM medicos
    WHERE id_medico = p_medico_id
    FOR UPDATE;

    SET v_dia_semana = DAYOFWEEK(p_fecha);

    SELECT COUNT(*), MIN(hora_inicio), MAX(hora_fin)
    INTO v_horarios_validos, v_hora_inicio, v_hora_fin
    FROM horarios_medicos
    WHERE id_medico = p_medico_id
      AND dia_semana = v_dia_semana
      AND tipo = 'regular'
      AND activo = 1
      AND p_hora >= hora_inicio
      AND p_hora < hora_fin;

    IF v_horarios_validos = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: El médico no atiende consultas en el día de la semana seleccionado.';
    END IF;

    SELECT COUNT(*) INTO v_excepciones
    FROM horarios_medicos
    WHERE id_medico = p_medico_id
      AND tipo = 'excepcion'
      AND fecha = p_fecha
      AND activo = 1
      AND p_hora >= hora_inicio
      AND p_hora < hora_fin;

    IF v_excepciones > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El horario esta bloqueado por una excepcion del medico.';
    END IF;

    SELECT COUNT(*) INTO v_citas_existentes
    FROM citas
    WHERE id_medico = p_medico_id
      AND fecha = p_fecha
      AND hora = p_hora
      AND estado IN ('programada', 'confirmada', 'en_curso', 'reprogramada');

    IF v_citas_existentes > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El medico ya tiene una cita reservada en esa fecha y hora.';
    END IF;

    INSERT INTO citas (id_paciente, id_medico, fecha, hora, motivo, estado)
    VALUES (p_paciente_id, p_medico_id, p_fecha, p_hora, p_motivo, 'programada');

    COMMIT;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 2. PROCEDIMIENTO ALMACENADO: Cancelar Cita (Operación UPDATE)
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_cancelar_cita (
    IN p_id_cita INT ,
    IN p_id_usuario INT 
)
BEGIN
    DECLARE v_estado_actual VARCHAR(20);
    DECLARE v_fecha DATE;
    DECLARE v_hora TIME;
    DECLARE v_id_paciente INT;
    DECLARE v_id_medico INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET v_estado_actual = NULL;

    START TRANSACTION;

    SELECT estado, fecha, hora, id_paciente, id_medico
    INTO v_estado_actual, v_fecha, v_hora, v_id_paciente, v_id_medico
    FROM citas
    WHERE id_cita = p_id_cita
    FOR UPDATE;

    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita no existe.';
    ELSEIF NOT EXISTS (
        SELECT 1
        FROM usuarios u
        LEFT JOIN pacientes p ON p.id_usuario = u.id_usuario
        LEFT JOIN medicos m ON m.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario
          AND u.activo = 1
          AND (u.rol = 'admin' OR p.id_paciente = v_id_paciente OR m.id_medico = v_id_medico)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: No tiene autorizacion para cancelar esta cita.';
    ELSEIF v_estado_actual IN ('cancelada', 'completada', 'en_curso') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El estado actual de la cita no permite cancelarla.';
    ELSEIF fn_validar_anticipacion_24h(v_fecha, v_hora) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Debe cancelar con al menos 24 horas de anticipacion.';
    END IF;

    UPDATE citas SET estado = 'cancelada' WHERE id_cita = p_id_cita;
    INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
    VALUES (p_id_cita, v_estado_actual, 'cancelada', p_id_usuario);

    COMMIT;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 3. PROCEDIMIENTO ALMACENADO: Reprogramar Cita (Operación UPDATE)
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_reprogramar_cita (
    IN p_id_cita INT,
    IN p_nueva_fecha DATE,
    IN p_nueva_hora TIME,
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_estado_actual VARCHAR(20);
    DECLARE v_fecha_actual DATE;
    DECLARE v_hora_actual TIME;
    DECLARE v_id_medico INT;
    DECLARE v_choques INT;
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_horario_valido INT DEFAULT 0;
    DECLARE v_excepcion INT DEFAULT 0;
    DECLARE v_medico_bloqueo INT;
    DECLARE v_dia_semana TINYINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT estado, fecha, hora, id_medico INTO v_estado_actual, v_fecha_actual, v_hora_actual, v_id_medico
    FROM citas WHERE id_cita = p_id_cita FOR UPDATE;

    IF v_estado_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita no existe.';
    ELSEIF v_estado_actual NOT IN ('programada', 'confirmada', 'reprogramada') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: El estado actual de la cita no permite reprogramarla.';
    ELSEIF fn_validar_anticipacion_24h(v_fecha_actual, v_hora_actual) = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: Debe reprogramar con al menos 24 horas de anticipación.';
    ELSEIF p_nueva_fecha IS NULL OR p_nueva_hora IS NULL
        OR fn_validar_anticipacion_24h(p_nueva_fecha, p_nueva_hora) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La nueva fecha debe tener al menos 24 horas de anticipacion.';
    END IF;

    SELECT id_medico INTO v_medico_bloqueo
    FROM medicos
    WHERE id_medico = v_id_medico
    FOR UPDATE;

    SELECT COUNT(*) INTO v_existe
    FROM usuarios u
    LEFT JOIN pacientes p ON p.id_usuario = u.id_usuario
    LEFT JOIN medicos m ON m.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
      AND u.activo = 1
      AND (u.rol = 'admin' OR p.id_paciente = (
          SELECT id_paciente FROM citas WHERE id_cita = p_id_cita
      ) OR m.id_medico = v_id_medico);

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: No tiene autorizacion para reprogramar esta cita.';
    END IF;

    SET v_dia_semana = DAYOFWEEK(p_nueva_fecha);

    SELECT COUNT(*) INTO v_horario_valido
    FROM horarios_medicos
    WHERE id_medico = v_id_medico
      AND dia_semana = v_dia_semana
      AND tipo = 'regular'
      AND activo = 1
      AND p_nueva_hora >= hora_inicio
      AND p_nueva_hora < hora_fin;

    IF v_horario_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La nueva hora esta fuera del horario del medico.';
    END IF;

    SELECT COUNT(*) INTO v_excepcion
    FROM horarios_medicos
    WHERE id_medico = v_id_medico
      AND tipo = 'excepcion'
      AND fecha = p_nueva_fecha
      AND activo = 1
      AND p_nueva_hora >= hora_inicio
      AND p_nueva_hora < hora_fin;

    IF v_excepcion > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El nuevo horario esta bloqueado por una excepcion.';
    END IF;

    SELECT COUNT(*) INTO v_choques
    FROM citas
    WHERE id_medico = v_id_medico
      AND fecha = p_nueva_fecha
      AND hora = p_nueva_hora
      AND id_cita <> p_id_cita
      AND estado IN ('programada', 'confirmada', 'en_curso', 'reprogramada');

    IF v_choques > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El medico ya tiene una cita en ese nuevo horario.';
    END IF;

    UPDATE citas
    SET fecha = p_nueva_fecha, hora = p_nueva_hora, estado = 'reprogramada'
    WHERE id_cita = p_id_cita;

    INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
    VALUES (p_id_cita, v_estado_actual, 'reprogramada', p_id_usuario);

    COMMIT;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 4. PROCEDIMIENTO ALMACENADO: Listar Médicos por Especialidad
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_listar_medicos_por_especialidad (
    IN p_id_especialidad TINYINT
)
BEGIN
    SELECT 
        m.id_medico, 
        u.nombre AS nombre_medico
    FROM medicos m
    INNER JOIN usuarios u ON m.id_usuario = u.id_usuario
    WHERE m.id_especialidad = p_id_especialidad 
      AND u.activo = 1;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 5. PROCEDIMIENTO ALMACENADO: Actualizar Preferencias de Notificación
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_actualizar_preferencias (
    IN p_id_usuario INT,
    IN p_notif_email TINYINT(1),
    IN p_notif_whatsapp TINYINT(1),
    IN p_rec_24h TINYINT(1),
    IN p_rec_2h TINYINT(1)
)
BEGIN
     IF p_notif_email IS NULL OR p_notif_email NOT IN (0, 1)
         OR p_notif_whatsapp IS NULL OR p_notif_whatsapp NOT IN (0, 1)
         OR p_rec_24h IS NULL OR p_rec_24h NOT IN (0, 1)
         OR p_rec_2h IS NULL OR p_rec_2h NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Las preferencias deben ser 0 o 1.';
    END IF;

    INSERT INTO notificaciones_config
        (id_usuario, notif_email, notif_whatsapp, recordatorio_24h, recordatorio_2h)
    VALUES
        (p_id_usuario, p_notif_email, p_notif_whatsapp, p_rec_24h, p_rec_2h)
    ON DUPLICATE KEY UPDATE
        notif_email = VALUES(notif_email),
        notif_whatsapp = VALUES(notif_whatsapp),
        recordatorio_24h = VALUES(recordatorio_24h),
        recordatorio_2h = VALUES(recordatorio_2h);
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 6. PROCEDIMIENTO ALMACENADO: Actualizar Password
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_actualizar_password (
    IN p_email VARCHAR(150),
    IN p_nuevo_password_hash VARCHAR(255)
)
BEGIN
    IF p_nuevo_password_hash IS NULL OR TRIM(p_nuevo_password_hash) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El hash de la nueva contrasena es obligatorio.';
    END IF;

    UPDATE usuarios
    SET password_hash = p_nuevo_password_hash
    WHERE email = p_email AND activo = 1;

    IF ROW_COUNT() = 0 AND NOT EXISTS (
        SELECT 1 FROM usuarios WHERE email = p_email AND activo = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: No existe un usuario activo con ese correo.';
    END IF;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 7. PROCEDIMIENTO ALMACENADO: Obtener Citas de un Paciente
-- ─────────────────────────────────────────────────────────────

DELIMITER //

CREATE PROCEDURE sp_obtener_citas_paciente (
    IN p_id_paciente INT
)
BEGIN
    SELECT 
        c.id_cita,
        c.fecha,
        c.hora,
        c.motivo,
        c.estado,
        u_med.nombre AS medico,
        e.nombre AS especialidad
    FROM citas c
    INNER JOIN medicos m ON c.id_medico = m.id_medico
    INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
    INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
    WHERE c.id_paciente = p_id_paciente
    ORDER BY c.fecha DESC, c.hora DESC;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 8. PROCEDIMIENTO ALMACENADO: Registrar Nuevo Paciente
-- Crea el usuario, crea su perfil de paciente e inicializa sus notificaciones.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_registrar_paciente (
    IN p_nombre VARCHAR(120),
    IN p_email VARCHAR(150),
    IN p_password_hash VARCHAR(255),
    IN p_telefono VARCHAR(20),
    IN p_dni VARCHAR(20)
)
BEGIN
    DECLARE v_id_usuario INT;

    -- Manejador de excepciones: deshacer cambios si ocurre un error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Insertar en la tabla principal de usuarios
    INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol, activo)
    VALUES (p_nombre, p_email, p_password_hash, p_telefono, p_dni, 'paciente', 1);

    SET v_id_usuario = LAST_INSERT_ID();

    -- 2. Crear perfil inicial en la tabla pacientes
    INSERT INTO pacientes (id_usuario)
    VALUES (v_id_usuario);

    -- 3. Crear configuración predeterminada de notificaciones
    INSERT INTO notificaciones_config (id_usuario, notif_email, notif_whatsapp, recordatorio_24h, recordatorio_2h)
    VALUES (v_id_usuario, 1, 0, 1, 0);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 9. PROCEDIMIENTO ALMACENADO: Obtener Métricas del Dashboard del Paciente
-- Devuelve los contadores de la cabecera: Próximas, Completadas y Canceladas.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_obtener_metricas_dashboard_paciente (
    IN p_id_paciente INT
)
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN TIMESTAMP(fecha, hora) >= NOW() AND estado IN ('programada', 'confirmada', 'reprogramada') THEN 1 ELSE 0 END), 0) AS citas_proximas,
        COALESCE(SUM(CASE WHEN estado = 'completada' THEN 1 ELSE 0 END), 0) AS citas_completadas,
        COALESCE(SUM(CASE WHEN estado = 'cancelada' THEN 1 ELSE 0 END), 0) AS citas_canceladas
    FROM citas
    WHERE id_paciente = p_id_paciente;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 10. PROCEDIMIENTO ALMACENADO: Actualizar Datos de Perfil del Paciente
-- Permite modificar teléfono y datos de salud (Fecha Nac., Género, Tipo Sangre).
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_actualizar_perfil_paciente (
    IN p_id_paciente INT,
    IN p_telefono VARCHAR(20),
    IN p_fecha_nacimiento DATE,
    IN p_genero ENUM('Masculino','Femenino','Otro'),
    IN p_tipo_sangre VARCHAR(5)
)
BEGIN
    DECLARE v_id_usuario INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id_usuario INTO v_id_usuario FROM pacientes WHERE id_paciente = p_id_paciente;

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El paciente no existe.';
    END IF;

    -- Actualizar teléfono en la tabla usuarios
    UPDATE usuarios 
    SET telefono = p_telefono 
    WHERE id_usuario = v_id_usuario;

    -- Actualizar datos adicionales en la tabla pacientes
    UPDATE pacientes 
    SET fecha_nacimiento = p_fecha_nacimiento,
        genero = p_genero,
        tipo_sangre = p_tipo_sangre
    WHERE id_paciente = p_id_paciente;

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 11. PROCEDIMIENTO ALMACENADO: Consultar Slots / Horarios Libres de un Médico
-- Retorna las horas dentro de la jornada laboral del médico que NO estén reservadas.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_obtener_horarios_disponibles_medico (
    IN p_id_medico INT,
    IN p_fecha DATE
)
BEGIN
    DECLARE v_dia_semana TINYINT;
    
    SET v_dia_semana = DAYOFWEEK(p_fecha);

    -- Obtener la jornada del médico para el día indicado
    SELECT 
        hm.hora_inicio, 
        hm.hora_fin
    FROM horarios_medicos hm
    WHERE hm.id_medico = p_id_medico 
      AND hm.dia_semana = v_dia_semana 
      AND hm.tipo = 'regular' 
      AND hm.activo = 1;

    -- Listar horas ya reservadas en esa fecha para que el Frontend las deshabilite
    SELECT hora 
    FROM citas 
    WHERE id_medico = p_id_medico 
      AND fecha = p_fecha 
      AND estado IN ('programada', 'confirmada', 'en_curso', 'reprogramada');
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 12. PROCEDIMIENTO ALMACENADO: Generar Token para Recuperación de Contraseña
-- Almacena un token seguro que vence en 1 hora.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_solicitar_recuperacion_password (
    IN p_email VARCHAR(150),
    IN p_token_hash CHAR(64)
)
BEGIN
    DECLARE v_id_usuario INT;

    SELECT id_usuario INTO v_id_usuario
    FROM usuarios
    WHERE email = p_email AND activo = 1;

    IF v_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El correo no existe o el usuario esta inactivo.';
    END IF;

    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'ERROR: Recuperacion no disponible; el esquema no almacena tokens.';
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 13. PROCEDIMIENTO ALMACENADO: Métricas Rápidas del Dashboard Médico
-- Calcula los contadores de la cabecera: Hoy, En Curso, Próximas y Total Pacientes.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_obtener_metricas_dashboard_medico (
    IN p_id_medico INT
)
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN fecha = CURDATE() AND estado IN ('programada', 'confirmada') THEN 1 ELSE 0 END), 0) AS citas_hoy,
        COALESCE(SUM(CASE WHEN fecha = CURDATE() AND estado = 'en_curso' THEN 1 ELSE 0 END), 0) AS citas_en_curso,
        COALESCE(SUM(CASE WHEN fecha > CURDATE() AND estado IN ('programada', 'confirmada', 'reprogramada') THEN 1 ELSE 0 END), 0) AS citas_proximas,
        COUNT(DISTINCT CASE WHEN estado = 'completada' THEN id_paciente END) AS total_pacientes_atendidos
    FROM citas
    WHERE id_medico = p_id_medico;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 14. PROCEDIMIENTO ALMACENADO: Atender / Completar Cita Médica
-- Permite al médico guardar sus notas/diagnóstico y marcar la cita como 'completada'.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_atender_cita_medica (
    IN p_id_cita INT,
    IN p_id_medico INT,
    IN p_notas_medico TEXT,
    IN p_estado ENUM('en_curso', 'completada')
)
BEGIN
    DECLARE v_medico_cita INT;
    DECLARE v_estado_ant VARCHAR(20);
    DECLARE v_id_usuario_medico INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id_medico, estado INTO v_medico_cita, v_estado_ant 
    FROM citas 
    WHERE id_cita = p_id_cita;

    IF v_medico_cita IS NULL OR v_medico_cita != p_id_medico THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: No tiene autorización para gestionar esta cita médica.';
    ELSEIF v_estado_ant NOT IN ('programada', 'confirmada', 'en_curso') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El estado actual no permite atender esta cita.';
    ELSEIF (p_estado = 'en_curso' AND v_estado_ant = 'en_curso')
        OR (p_estado = 'completada' AND v_estado_ant = 'completada') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita ya se encuentra en ese estado.';
    END IF;

    SELECT id_usuario INTO v_id_usuario_medico FROM medicos WHERE id_medico = p_id_medico;

    UPDATE citas
    SET notas_medico = COALESCE(p_notas_medico, notas_medico),
        estado = p_estado
    WHERE id_cita = p_id_cita;

    INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
    VALUES (p_id_cita, v_estado_ant, p_estado, v_id_usuario_medico);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 15. PROCEDIMIENTO ALMACENADO: Configurar Horario Semanal del Médico
-- Inserta o actualiza las horas de atención regulares por día de la semana.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_guardar_horario_regular_medico (
    IN p_id_medico INT,
    IN p_dia_semana TINYINT, -- 1=Domingo, 2=Lunes, ..., 7=Sábado
    IN p_hora_inicio TIME,
    IN p_hora_fin TIME
)
BEGIN
    DECLARE v_horarios_existentes INT DEFAULT 0;
    DECLARE v_medico_bloqueo INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

     IF p_dia_semana IS NULL OR p_dia_semana NOT BETWEEN 1 AND 7
         OR p_hora_inicio IS NULL OR p_hora_fin IS NULL
       OR p_hora_inicio >= p_hora_fin THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: El dia o el rango horario no es valido.';
    END IF;

    SELECT id_medico INTO v_medico_bloqueo
    FROM medicos
    WHERE id_medico = p_id_medico
    FOR UPDATE;

    IF v_medico_bloqueo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El medico no existe.';
    END IF;

    SELECT COUNT(*) INTO v_horarios_existentes
    FROM horarios_medicos
    WHERE id_medico = p_id_medico
      AND tipo = 'regular'
      AND dia_semana = p_dia_semana;

    IF v_horarios_existentes > 0 THEN
        UPDATE horarios_medicos
        SET hora_inicio = p_hora_inicio,
            hora_fin = p_hora_fin,
            activo = 1
        WHERE id_medico = p_id_medico
          AND tipo = 'regular'
          AND dia_semana = p_dia_semana;
    ELSE
        INSERT INTO horarios_medicos
            (id_medico, tipo, dia_semana, hora_inicio, hora_fin, activo)
        VALUES
            (p_id_medico, 'regular', p_dia_semana, p_hora_inicio, p_hora_fin, 1);
    END IF;

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 16. PROCEDIMIENTO ALMACENADO: Bloquear / Registrar Excepción de Horario
-- Bloquea la atención del médico en una fecha específica (vacaciones, imprevistos).
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_bloquear_fecha_medico (
    IN p_id_medico INT,
    IN p_fecha DATE,
    IN p_hora_inicio TIME,
    IN p_hora_fin TIME,
    IN p_motivo VARCHAR(255)
)
BEGIN
    DECLARE v_medico_bloqueo INT;
    DECLARE v_citas_afectadas INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_fecha IS NULL OR p_fecha < CURDATE()
       OR p_hora_inicio IS NULL OR p_hora_fin IS NULL
       OR p_hora_inicio >= p_hora_fin THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La fecha o el rango horario de la excepcion no es valido.';
    END IF;

    SELECT id_medico INTO v_medico_bloqueo
    FROM medicos
    WHERE id_medico = p_id_medico
    FOR UPDATE;

    IF v_medico_bloqueo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El medico no existe.';
    END IF;

    SELECT COUNT(*) INTO v_citas_afectadas
    FROM citas
    WHERE id_medico = p_id_medico
      AND fecha = p_fecha
      AND hora >= p_hora_inicio
      AND hora < p_hora_fin
      AND estado IN ('programada', 'confirmada', 'en_curso', 'reprogramada');

    IF v_citas_afectadas > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El rango contiene citas reservadas.';
    END IF;

    INSERT INTO horarios_medicos (id_medico, tipo, fecha, hora_inicio, hora_fin, motivo, activo)
    VALUES (p_id_medico, 'excepcion', p_fecha, p_hora_inicio, p_hora_fin, p_motivo, 1);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 17. PROCEDIMIENTO ALMACENADO: Listar Pacientes Atendidos por el Médico
-- Retorna el directorio de pacientes asignados con sus datos de contacto.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_listar_pacientes_por_medico (
    IN p_id_medico INT
)
BEGIN
    SELECT DISTINCT
        p.id_paciente,
        u.nombre AS nombre_paciente,
        u.dni,
        u.telefono,
        u.email,
        p.tipo_sangre,
        fn_calcular_edad(p.fecha_nacimiento) AS edad,
        COUNT(c.id_cita) AS total_citas_con_medico
    FROM citas c
    INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
    INNER JOIN usuarios u ON p.id_usuario = u.id_usuario
    WHERE c.id_medico = p_id_medico
    GROUP BY p.id_paciente, u.nombre, u.dni, u.telefono, u.email, p.tipo_sangre, p.fecha_nacimiento;
END //

DELIMITER ;

USE sistema_citas;

-- ─────────────────────────────────────────────────────────────
-- 18. PROCEDIMIENTO ALMACENADO: Métricas Globales para el Dashboard Administrador
-- Calcula las tarjetas métricas del panel principal de administración.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_obtener_metricas_dashboard_admin ()
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN fecha = CURDATE() THEN 1 ELSE 0 END), 0) AS citas_hoy,
        COALESCE(SUM(CASE WHEN TIMESTAMP(fecha, hora) >= NOW() AND estado IN ('programada', 'confirmada', 'reprogramada') THEN 1 ELSE 0 END), 0) AS citas_pendientes,
        (SELECT COUNT(*) FROM pacientes) AS total_pacientes,
        COALESCE(SUM(CASE WHEN estado = 'cancelada' THEN 1 ELSE 0 END), 0) AS citas_canceladas
    FROM citas;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 19. PROCEDIMIENTO ALMACENADO: Registrar Nuevo Médico en el Sistema
-- Crea la cuenta de usuario con rol 'medico' y su perfil profesional asociado.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_registrar_medico (
    IN p_nombre VARCHAR(120),
    IN p_email VARCHAR(150),
    IN p_password_hash VARCHAR(255),
    IN p_telefono VARCHAR(20),
    IN p_dni VARCHAR(20),
    IN p_id_especialidad TINYINT
)
BEGIN
    DECLARE v_id_usuario INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Registrar usuario con rol médico
    INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol, activo)
    VALUES (p_nombre, p_email, p_password_hash, p_telefono, p_dni, 'medico', 1);

    SET v_id_usuario = LAST_INSERT_ID();

    -- 2. Asignar perfil médico y especialidad
    INSERT INTO medicos (id_usuario, id_especialidad)
    VALUES (v_id_usuario, p_id_especialidad);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 20. PROCEDIMIENTO ALMACENADO: Cambiar Estado de Actividad de Usuario
-- Activa o desactiva (bloquea) el acceso de un paciente o médico al sistema.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_cambiar_estado_usuario (
    IN p_id_usuario INT,
    IN p_nuevo_estado TINYINT(1) -- 1 = Activo, 0 = Inactivo
)
BEGIN
    IF p_nuevo_estado IS NULL OR p_nuevo_estado NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El estado debe ser 0 o 1.';
    END IF;

    UPDATE usuarios
    SET activo = p_nuevo_estado
    WHERE id_usuario = p_id_usuario
      AND rol IN ('paciente', 'medico');

    IF ROW_COUNT() = 0 AND NOT EXISTS (
        SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario AND rol IN ('paciente', 'medico')
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: No existe un paciente o medico con ese identificador.';
    END IF;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 21. PROCEDIMIENTO ALMACENADO: Cambio Manual de Estado de Cita por el Admin
-- Permite al administrador forzar un cambio de estado en cualquier cita.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_admin_cambiar_estado_cita (
    IN p_id_cita INT,
    IN p_nuevo_estado ENUM('programada','confirmada','en_curso','completada','cancelada','reprogramada'),
    IN p_id_admin INT
)
BEGIN
    DECLARE v_estado_ant VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM usuarios
        WHERE id_usuario = p_id_admin AND rol = 'admin' AND activo = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Se requiere un administrador activo.';
    END IF;

    SELECT estado INTO v_estado_ant
    FROM citas
    WHERE id_cita = p_id_cita
    FOR UPDATE;

    IF v_estado_ant IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita no existe.';
    END IF;

    UPDATE citas 
    SET estado = p_nuevo_estado 
    WHERE id_cita = p_id_cita;

    -- Registrar la auditoría realizada por el administrador
    INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
    VALUES (p_id_cita, v_estado_ant, p_nuevo_estado, p_id_admin);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 22. PROCEDIMIENTO ALMACENADO: Generar Reportes Estadísticos de Citas
-- Devuelve 2 conjuntos de resultados: resumen por Estado y resumen por Especialidad.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE PROCEDURE sp_obtener_reportes_estadisticos ()
BEGIN
    -- Resultado 1: Distribución de Citas por Estado
    SELECT 
        estado, 
        COUNT(*) AS total_citas 
    FROM citas 
    GROUP BY estado;

    -- Resultado 2: Distribución de Citas por Especialidad
    SELECT 
        e.nombre AS especialidad, 
        COUNT(c.id_cita) AS total_citas 
    FROM especialidades e
    LEFT JOIN medicos m ON e.id_especialidad = m.id_especialidad
    LEFT JOIN citas c ON m.id_medico = c.id_medico
    GROUP BY e.id_especialidad, e.nombre;
END //

DELIMITER ;
