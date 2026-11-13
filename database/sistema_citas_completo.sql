
-- =============================================================
-- Consolidado desde database/01_esquema.sql
-- =============================================================
-- INSTALACION DESTRUCTIVA: DROP DATABASE elimina todos los datos existentes.
-- Ejecutar solo en una instalacion nueva o cuando se quiera reiniciar la demo.
DROP DATABASE IF EXISTS sistema_citas;
CREATE DATABASE sistema_citas
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
-- =============================================================
-- 01. ESQUEMA DE LA BASE DE DATOS + DATOS DE PRUEBA
-- Instalacion completa: ejecutar este archivo primero.
-- =============================================================
SET NAMES utf8mb4;
SET SESSION time_zone = 'SYSTEM';
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET FOREIGN_KEY_CHECKS = 0;
USE sistema_citas;

-- ─────────────────────────────────────────────────────────────
-- 1. USUARIOS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE usuarios (
  id_usuario    INT    NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(120)    NOT NULL,
  email         VARCHAR(150)    NOT NULL UNIQUE,
  password_hash VARCHAR(255)    NOT NULL,
  telefono      VARCHAR(20),
  dni           VARCHAR(20)     NOT NULL UNIQUE,
  rol           ENUM('paciente','medico','admin')  NOT NULL DEFAULT 'paciente',
    activo        TINYINT(1)      NOT NULL DEFAULT 1,
  creado_en     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario),
    CONSTRAINT chk_usuarios_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 2. PACIENTES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE pacientes (
  id_paciente      INT  NOT NULL AUTO_INCREMENT,
  id_usuario       INT  NOT NULL UNIQUE,
  fecha_nacimiento DATE,
  genero           ENUM('Masculino','Femenino','Otro'),
  tipo_sangre      VARCHAR(5),
  PRIMARY KEY (id_paciente),
    CONSTRAINT fk_paciente_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_paciente_tipo_sangre CHECK (tipo_sangre IS NULL OR tipo_sangre IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'))
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 3. ESPECIALIDADES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE especialidades (
  id_especialidad TINYINT NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(80)      NOT NULL UNIQUE,
    PRIMARY KEY (id_especialidad)
) ENGINE=InnoDB;

INSERT INTO especialidades (nombre) VALUES
  ('Medicina General'), ('Cardiología'), ('Pediatría'), ('Traumatología');

-- ─────────────────────────────────────────────────────────────
-- 4. MÉDICOS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE medicos (
  id_medico       INT     NOT NULL AUTO_INCREMENT,
  id_usuario      INT     NOT NULL UNIQUE,
  id_especialidad TINYINT NOT NULL,
    consultorio     VARCHAR(120) NOT NULL,
    duracion_consulta_min SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  PRIMARY KEY (id_medico),
  CONSTRAINT fk_medico_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_medico_especialidad
        FOREIGN KEY (id_especialidad) REFERENCES especialidades (id_especialidad),
    CONSTRAINT chk_medico_duracion CHECK (duracion_consulta_min > 0),
    CONSTRAINT chk_medico_consultorio CHECK (CHAR_LENGTH(TRIM(consultorio)) > 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 5. HORARIOS DE MÉDICOS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE horarios_medicos (
  id_horario   INT NOT NULL AUTO_INCREMENT,
  id_medico    INT NOT NULL,
  tipo         ENUM('regular', 'excepcion') NOT NULL DEFAULT 'regular',
  dia_semana   TINYINT,       -- 1=Domingo, 2=Lunes, 3=Martes, 4=Miércoles, 5=Jueves, 6=Viernes, 7=Sábado
  fecha        DATE,          -- Usado solo si es una 'excepcion' (ej. feriado o reemplazo)
  hora_inicio  TIME NOT NULL,
  hora_fin     TIME NOT NULL,
  motivo       VARCHAR(255),
  activo       TINYINT(1) NOT NULL DEFAULT 1,
  creado_en    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_horario),
  INDEX idx_horarios_medico_dia (id_medico, dia_semana, tipo, activo),
    CONSTRAINT fk_horario_medico
        FOREIGN KEY (id_medico) REFERENCES medicos (id_medico) ON DELETE CASCADE,
    CONSTRAINT chk_horario_rango CHECK (hora_inicio < hora_fin),
    CONSTRAINT chk_horario_tipo_datos CHECK (
        (tipo = 'regular' AND dia_semana BETWEEN 1 AND 7 AND fecha IS NULL)
        OR (tipo = 'excepcion' AND dia_semana IS NULL AND fecha IS NOT NULL)
    ),
    CONSTRAINT chk_horario_activo CHECK (activo IN (0, 1))
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 6. CITAS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE citas (
  id_cita       INT  NOT NULL AUTO_INCREMENT,
  id_paciente   INT  NOT NULL,
  id_medico     INT  NOT NULL,
  fecha         DATE          NOT NULL,
  hora          TIME          NOT NULL,
  motivo        TEXT          NOT NULL,
  notas_medico  TEXT,
    estado        ENUM('programada','confirmada','en_curso','completada','cancelada','reprogramada','no_asistio') NOT NULL DEFAULT 'programada',
  creado_en     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cita),
  INDEX idx_citas_medico_fecha (id_medico, fecha, hora),
    INDEX idx_citas_fecha_estado (fecha, estado),
    INDEX idx_citas_medico_fecha_estado (id_medico, fecha, estado),
  INDEX idx_citas_paciente_fecha (id_paciente, fecha),
  INDEX idx_citas_estado (estado),
  CONSTRAINT fk_cita_paciente
    FOREIGN KEY (id_paciente) REFERENCES pacientes (id_paciente),
    CONSTRAINT fk_cita_medico
        FOREIGN KEY (id_medico)   REFERENCES medicos (id_medico)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 7. NOTIFICACIONES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE notificaciones_config (
  id_usuario        INT NOT NULL UNIQUE,
  notif_email       TINYINT(1)   NOT NULL DEFAULT 1,
  notif_whatsapp    TINYINT(1)   NOT NULL DEFAULT 0,
  recordatorio_24h  TINYINT(1)   NOT NULL DEFAULT 1,
  recordatorio_2h   TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (id_usuario),
    CONSTRAINT fk_notif_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_notif_valores CHECK (notif_email IN (0, 1) AND notif_whatsapp IN (0, 1) AND recordatorio_24h IN (0, 1) AND recordatorio_2h IN (0, 1))
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 8. HISTORIAL DE CITAS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE citas_historial (
  id_historial  INT  NOT NULL AUTO_INCREMENT,
  id_cita       INT  NOT NULL,
  estado_ant    VARCHAR(20),
  estado_nuevo  VARCHAR(20)   NOT NULL,
  cambiado_por  INT,
  cambiado_en   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_historial),
    INDEX idx_historial_cita_fecha (id_cita, cambiado_en),
  CONSTRAINT fk_hist_cita
    FOREIGN KEY (id_cita)      REFERENCES citas (id_cita) ON DELETE CASCADE,
    CONSTRAINT fk_hist_usuario
        FOREIGN KEY (cambiado_por) REFERENCES usuarios (id_usuario) ON DELETE SET NULL,
    CONSTRAINT chk_historial_estado CHECK (estado_nuevo IN ('programada','confirmada','en_curso','completada','cancelada','reprogramada','no_asistio'))
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================
-- DATOS DE PRUEBA (POBLACIÓN DE LA BASE DE DATOS)
-- =============================================================

INSERT INTO usuarios (id_usuario, nombre, email, password_hash, telefono, dni, rol, activo) VALUES
(1, 'Admin Principal', 'admin@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654321', '00000001', 'admin', 1),
(2, 'Dr. Alejandro Torres', 'atorres@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654322', '11111111', 'medico', 1),
(3, 'Dra. Lucía Mendoza', 'lmendoza@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654323', '22222222', 'medico', 1),
(4, 'Ana María García', 'ana@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654324', '33333333', 'paciente', 1),
(5, 'Carlos Ruiz', 'carlos@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654325', '44444444', 'paciente', 1),
(6, 'María Fernández', 'maria@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654326', '55555555', 'paciente', 1),
(7, 'Paciente Inactivo', 'inactivo@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654327', '66666666', 'paciente', 0);

INSERT INTO pacientes (id_paciente, id_usuario, fecha_nacimiento, genero, tipo_sangre) VALUES
(1, 4, '1995-08-15', 'Femenino', 'O+'),
(2, 5, '1988-03-22', 'Masculino', 'A-'),
(3, 6, '2001-11-05', 'Femenino', 'B+'),
(4, 7, '1990-04-10', 'Otro', 'AB+');

INSERT INTO medicos (id_medico, id_usuario, id_especialidad, consultorio, duracion_consulta_min) VALUES
(1, 2, 2, 'Consultorio 101', 30),
(2, 3, 3, 'Consultorio 202', 45);

INSERT INTO horarios_medicos (id_medico, tipo, dia_semana, hora_inicio, hora_fin) VALUES
(1, 'regular', 2, '08:00:00', '14:00:00'), (1, 'regular', 3, '08:00:00', '14:00:00'),
(1, 'regular', 4, '08:00:00', '14:00:00'), (1, 'regular', 5, '08:00:00', '14:00:00'),
(1, 'regular', 6, '08:00:00', '14:00:00'),
(2, 'regular', 2, '14:00:00', '20:00:00'), (2, 'regular', 3, '14:00:00', '20:00:00'),
(2, 'regular', 4, '14:00:00', '20:00:00'), (2, 'regular', 5, '14:00:00', '20:00:00'),
(2, 'regular', 6, '14:00:00', '20:00:00');

INSERT INTO horarios_medicos (id_medico, tipo, dia_semana, fecha, hora_inicio, hora_fin, motivo) VALUES
(1, 'excepcion', NULL, DATE_ADD(CURDATE(), INTERVAL 9 DAY), '12:00:00', '12:30:00', 'Bloqueo de demostración');

INSERT INTO citas (id_cita, id_paciente, id_medico, fecha, hora, motivo, notas_medico, estado) VALUES
(1, 1, 1, DATE_SUB(CURDATE(), INTERVAL 14 DAY), '09:00:00', 'Dolor en el pecho al correr', 'Se recomienda electrocardiograma', 'completada'),
(2, 2, 1, DATE_ADD(CURDATE(), INTERVAL 7 DAY), '09:00:00', 'Chequeo general de presión arterial', NULL, 'programada'),
(3, 3, 1, DATE_ADD(CURDATE(), INTERVAL 8 DAY), '09:30:00', 'Control preventivo', NULL, 'confirmada'),
(4, 1, 1, CURDATE(), TIME(NOW()), 'Consulta en curso de demostración', NULL, 'en_curso'),
(5, 2, 1, DATE_ADD(CURDATE(), INTERVAL 9 DAY), '11:00:00', 'Cita cancelada de demostración', NULL, 'cancelada'),
(6, 3, 2, DATE_ADD(CURDATE(), INTERVAL 10 DAY), '15:00:00', 'Cita reprogramada de demostración', NULL, 'reprogramada'),
(7, 4, 1, DATE_SUB(CURDATE(), INTERVAL 3 DAY), '10:00:00', 'Cita con inasistencia de demostración', NULL, 'no_asistio');

INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por, cambiado_en) VALUES
(1, 'programada', 'completada', 2, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 14 DAY), '09:00:00')),
(3, 'programada', 'confirmada', 1, NOW()),
(4, 'confirmada', 'en_curso', 2, NOW()),
(5, 'programada', 'cancelada', 1, NOW()),
(6, 'programada', 'reprogramada', 1, NOW()),
(7, 'confirmada', 'no_asistio', 2, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 3 DAY), '10:00:00'));

INSERT INTO notificaciones_config (id_usuario, notif_email, notif_whatsapp, recordatorio_24h, recordatorio_2h) VALUES
(1, 1, 0, 1, 0), (2, 1, 0, 1, 0), (3, 1, 0, 1, 0),
(4, 1, 1, 1, 1), (5, 1, 0, 1, 0), (6, 1, 0, 1, 0), (7, 0, 0, 0, 0);



-- =============================================================
-- Consolidado desde database/02_funciones.sql
-- =============================================================
-- =============================================================
-- 02. FUNCIONES DEFINIDAS POR EL USUARIO
-- Requiere: 01_esquema.sql
-- =============================================================
SET NAMES utf8mb4;
USE sistema_citas;
-- =============================================================
-- FUNCIONES DEFINIDAS PARA EL USUARIO
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. FUNCIÓN: Calcular la edad del paciente
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP FUNCTION IF EXISTS fn_calcular_edad;
CREATE FUNCTION fn_calcular_edad(p_fecha_nacimiento DATE)
RETURNS INT
NOT DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, p_fecha_nacimiento, CURDATE());
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 2. FUNCIÓN: Validar Restricción de 24 Horas
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP FUNCTION IF EXISTS fn_validar_anticipacion_24h;
CREATE FUNCTION fn_validar_anticipacion_24h(p_fecha DATE, p_hora TIME)
RETURNS TINYINT(1)
NOT DETERMINISTIC
BEGIN
    DECLARE v_fecha_cita DATETIME;
    DECLARE v_minutos_restantes INT;

    IF p_fecha IS NULL OR p_hora IS NULL THEN
        RETURN 0;
    END IF;

    SET v_fecha_cita = TIMESTAMP(p_fecha, p_hora);

    SET v_minutos_restantes = TIMESTAMPDIFF(MINUTE, NOW(), v_fecha_cita);

    IF v_minutos_restantes >= 1440 THEN
        RETURN 1; -- 1 significa "Válido" (Cumple la regla)
    ELSE
        RETURN 0; -- 0 significa "Inválido" (Faltan menos de 24h)
    END IF;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 3. FUNCIÓN: Obtener Perfil Completo del Paciente
-- Retorna en una sola llamada los datos personales y de cuenta del Paciente.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP FUNCTION IF EXISTS fn_obtener_perfil_paciente_json;
CREATE FUNCTION fn_obtener_perfil_paciente_json(p_id_paciente INT)
RETURNS JSON
READS SQL DATA
BEGIN
    DECLARE v_resultado JSON;

    SELECT JSON_OBJECT(
        'id_paciente', p.id_paciente,
        'id_usuario', u.id_usuario,
        'nombre', u.nombre,
        'email', u.email,
        'dni', u.dni,
        'telefono', u.telefono,
        'fecha_nacimiento', p.fecha_nacimiento,
        'edad', fn_calcular_edad(p.fecha_nacimiento),
        'genero', p.genero,
        'tipo_sangre', p.tipo_sangre,
        'creado_en', u.creado_en
    ) INTO v_resultado
    FROM pacientes p
    INNER JOIN usuarios u ON p.id_usuario = u.id_usuario
    WHERE p.id_paciente = p_id_paciente;

    RETURN v_resultado;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 4. FUNCIÓN: Obtener Perfil e Información Profesional del Médico
-- Retorna en formato JSON los datos del médico para la vista "Mi Perfil"
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP FUNCTION IF EXISTS fn_obtener_perfil_medico_json;
CREATE FUNCTION fn_obtener_perfil_medico_json(p_id_medico INT)
RETURNS JSON
READS SQL DATA
BEGIN
    DECLARE v_resultado JSON;

    SELECT JSON_OBJECT(
        'id_medico', m.id_medico,
        'id_usuario', u.id_usuario,
        'nombre', u.nombre,
        'email', u.email,
        'telefono', u.telefono,
        'dni', u.dni,
        'especialidad', e.nombre,
        'id_especialidad', e.id_especialidad
    ) INTO v_resultado
    FROM medicos m
    INNER JOIN usuarios u ON m.id_usuario = u.id_usuario
    INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
    WHERE m.id_medico = p_id_medico;

    RETURN v_resultado;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 5. FUNCIÓN: Calcular Tasa de Completitud del Sistema
-- Retorna el porcentaje (%) de citas que terminaron con éxito (completadas).
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP FUNCTION IF EXISTS fn_obtener_tasa_completacion;
CREATE FUNCTION fn_obtener_tasa_completacion()
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total_citas INT;
    DECLARE v_citas_completadas INT;
    DECLARE v_tasa DECIMAL(5,2);

    SELECT COUNT(*), COALESCE(SUM(CASE WHEN estado = 'completada' THEN 1 ELSE 0 END), 0)
    INTO v_total_citas, v_citas_completadas
    FROM citas;

    IF v_total_citas = 0 THEN
        RETURN 0.00;
    ELSE
        SET v_tasa = (v_citas_completadas / v_total_citas) * 100;
        RETURN v_tasa;
    END IF;
END //

DELIMITER ;

-- =============================================================
-- Consolidado desde database/03_procedimientos.sql
-- =============================================================
-- =============================================================
-- 03. PROCEDIMIENTOS ALMACENADOS
-- Requiere: 01_esquema.sql y 02_funciones.sql
-- =============================================================
SET NAMES utf8mb4;
USE sistema_citas;
-- =============================================================
-- PROCEDIMIENTOS ALMACENADOS
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. PROCEDIMIENTO ALMACENADO: Registrar Cita
-- ─────────────────────────────────────────────────────────────

DELIMITER //

DROP PROCEDURE IF EXISTS sp_registrar_cita;
CREATE PROCEDURE sp_registrar_cita (
    IN p_paciente_id INT,
    IN p_medico_id INT,
    IN p_fecha DATE,
    IN p_hora TIME,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_horarios_validos INT DEFAULT 0;
    DECLARE v_dia_valido INT DEFAULT 0;
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

    SELECT COUNT(*) INTO v_dia_valido
    FROM horarios_medicos
    WHERE id_medico = p_medico_id
      AND dia_semana = v_dia_semana
      AND tipo = 'regular'
      AND activo = 1;

    IF v_dia_valido = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: El médico no atiende consultas en el día de la semana seleccionado.';
    END IF;

    SELECT COUNT(*) INTO v_horarios_validos
    FROM horarios_medicos
    WHERE id_medico = p_medico_id
      AND dia_semana = v_dia_semana
      AND tipo = 'regular'
      AND activo = 1
      AND p_hora >= hora_inicio
      AND p_hora < hora_fin;

    IF v_horarios_validos = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La hora solicitada está fuera del horario de atención del médico.';
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

DROP PROCEDURE IF EXISTS sp_cancelar_cita;
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

DROP PROCEDURE IF EXISTS sp_reprogramar_cita;
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

DROP PROCEDURE IF EXISTS sp_listar_medicos_por_especialidad;
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

DROP PROCEDURE IF EXISTS sp_actualizar_preferencias;
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

DROP PROCEDURE IF EXISTS sp_actualizar_password;
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

DROP PROCEDURE IF EXISTS sp_obtener_citas_paciente;
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

DROP PROCEDURE IF EXISTS sp_registrar_paciente;
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

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 9. PROCEDIMIENTO ALMACENADO: Obtener Métricas del Dashboard del Paciente
-- Devuelve los contadores de la cabecera: Próximas, Completadas y Canceladas.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP PROCEDURE IF EXISTS sp_obtener_metricas_dashboard_paciente;
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

DROP PROCEDURE IF EXISTS sp_actualizar_perfil_paciente;
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

DROP PROCEDURE IF EXISTS sp_obtener_horarios_disponibles_medico;
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
-- 12. PROCEDIMIENTO ALMACENADO: Consultar el historial de una cita
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP PROCEDURE IF EXISTS sp_obtener_historial_cita;
CREATE PROCEDURE sp_obtener_historial_cita (IN p_id_cita INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM citas WHERE id_cita = p_id_cita) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: La cita no existe.';
    END IF;

    SELECT h.id_historial, h.id_cita, h.estado_ant, h.estado_nuevo,
           h.cambiado_por, u.nombre AS nombre_cambiado_por, h.cambiado_en
    FROM citas_historial h
    LEFT JOIN usuarios u ON u.id_usuario = h.cambiado_por
    WHERE h.id_cita = p_id_cita
    ORDER BY h.cambiado_en, h.id_historial;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 13. PROCEDIMIENTO ALMACENADO: Métricas Rápidas del Dashboard Médico
-- Calcula los contadores de la cabecera: Hoy, En Curso, Próximas y Total Pacientes.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP PROCEDURE IF EXISTS sp_obtener_metricas_dashboard_medico;
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

DROP PROCEDURE IF EXISTS sp_atender_cita_medica;
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
    ELSEIF v_estado_ant NOT IN ('programada', 'confirmada', 'reprogramada', 'en_curso') THEN
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

DROP PROCEDURE IF EXISTS sp_guardar_horario_regular_medico;
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

DROP PROCEDURE IF EXISTS sp_bloquear_fecha_medico;
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

DROP PROCEDURE IF EXISTS sp_listar_pacientes_por_medico;
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

DROP PROCEDURE IF EXISTS sp_obtener_metricas_dashboard_admin;
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

DROP PROCEDURE IF EXISTS sp_registrar_medico;
CREATE PROCEDURE sp_registrar_medico (
    IN p_nombre VARCHAR(120),
    IN p_email VARCHAR(150),
    IN p_password_hash VARCHAR(255),
    IN p_telefono VARCHAR(20),
    IN p_dni VARCHAR(20),
    IN p_id_especialidad TINYINT,
    IN p_consultorio VARCHAR(120),
    IN p_duracion_consulta_min SMALLINT UNSIGNED
)
BEGIN
    DECLARE v_id_usuario INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_consultorio IS NULL OR TRIM(p_consultorio) = ''
       OR p_duracion_consulta_min IS NULL OR p_duracion_consulta_min = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Consultorio y duración de consulta son obligatorios.';
    END IF;

    -- 1. Registrar usuario con rol médico
    INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol, activo)
    VALUES (p_nombre, p_email, p_password_hash, p_telefono, p_dni, 'medico', 1);

    SET v_id_usuario = LAST_INSERT_ID();

    -- 2. Asignar perfil médico y especialidad
    INSERT INTO medicos (id_usuario, id_especialidad, consultorio, duracion_consulta_min)
    VALUES (v_id_usuario, p_id_especialidad, TRIM(p_consultorio), p_duracion_consulta_min);

    COMMIT;
END //

DELIMITER ;


-- ─────────────────────────────────────────────────────────────
-- 20. PROCEDIMIENTO ALMACENADO: Cambiar Estado de Actividad de Usuario
-- Activa o desactiva (bloquea) el acceso de un paciente o médico al sistema.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP PROCEDURE IF EXISTS sp_cambiar_estado_usuario;
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
-- Permite al administrador cambiar el estado respetando las transiciones permitidas.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

DROP PROCEDURE IF EXISTS sp_admin_cambiar_estado_cita;
CREATE PROCEDURE sp_admin_cambiar_estado_cita (
    IN p_id_cita INT,
    IN p_nuevo_estado ENUM('programada','confirmada','en_curso','completada','cancelada','reprogramada','no_asistio'),
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

DROP PROCEDURE IF EXISTS sp_obtener_reportes_estadisticos;
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


-- =============================================================
-- Consolidado desde database/04_vistas.sql
-- =============================================================
-- =============================================================
-- 04. VISTAS
-- Requiere: 01_esquema.sql y 02_funciones.sql
-- =============================================================
SET NAMES utf8mb4;
USE sistema_citas;

-- ─────────────────────────────────────────────────────────────
-- 1. VISTA: Agenda del Paciente (Para el Dashboard del Paciente)
-- Muestra todas las citas con los datos del médico, especialidad y estado.
-- ─────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_agenda_paciente;
CREATE VIEW vw_agenda_paciente AS
SELECT
    c.id_cita,
    p.id_paciente,
    u_pac.id_usuario AS id_usuario_paciente,
    u_pac.nombre AS nombre_paciente,
    u_pac.dni AS dni_paciente,
    m.id_medico,
    u_med.nombre AS nombre_medico,
    e.nombre AS especialidad,
    c.fecha,
    c.hora,
    c.motivo,
    c.notas_medico,
    c.estado,
    CASE
        WHEN c.estado IN ('programada', 'confirmada', 'reprogramada')
         AND fn_validar_anticipacion_24h(c.fecha, c.hora) = 1 THEN 1
        ELSE 0
    END AS permite_reprogramar_cancelar
FROM citas c
INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
INNER JOIN usuarios u_pac ON p.id_usuario = u_pac.id_usuario
INNER JOIN medicos m ON c.id_medico = m.id_medico
INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad;


-- ─────────────────────────────────────────────────────────────
-- 2. VISTA: Agenda Diaria y Consultas del Médico
-- Diseñada para la vista del médico, incluyendo edad y datos del paciente.
-- ─────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_agenda_medico;
CREATE VIEW vw_agenda_medico AS
SELECT
    c.id_cita,
    m.id_medico,
    u_med.id_usuario AS id_usuario_medico,
    u_med.nombre AS nombre_medico,
    e.nombre AS especialidad,
    p.id_paciente,
    u_pac.nombre AS nombre_paciente,
    u_pac.dni AS dni_paciente,
    u_pac.telefono AS telefono_paciente,
    p.fecha_nacimiento,
    fn_calcular_edad(p.fecha_nacimiento) AS edad_paciente,
    p.genero AS genero_paciente,
    p.tipo_sangre,
    c.fecha,
    c.hora,
    c.motivo,
    c.notas_medico,
    c.estado
FROM citas c
INNER JOIN medicos m ON c.id_medico = m.id_medico
INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
INNER JOIN usuarios u_pac ON p.id_usuario = u_pac.id_usuario;


-- ─────────────────────────────────────────────────────────────
-- 3. VISTA: Lista Directiva de Médicos y sus Horarios
-- Consolida los datos del profesional, su especialidad y días/horas de atención.
-- ─────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_medicos_horarios;
CREATE VIEW vw_medicos_horarios AS
SELECT
    m.id_medico,
    u.id_usuario,
    u.nombre AS nombre_medico,
    u.email,
    u.telefono,
    e.id_especialidad,
    e.nombre AS especialidad,
    hm.id_horario,
    hm.tipo,
    CASE hm.dia_semana
        WHEN 1 THEN 'Domingo'
        WHEN 2 THEN 'Lunes'
        WHEN 3 THEN 'Martes'
        WHEN 4 THEN 'Miércoles'
        WHEN 5 THEN 'Jueves'
        WHEN 6 THEN 'Viernes'
        WHEN 7 THEN 'Sábado'
    END AS dia_semana_nombre,
    hm.dia_semana,
    hm.fecha AS fecha_excepcion,
    hm.hora_inicio,
    hm.hora_fin,
    hm.activo AS horario_activo
FROM medicos m
INNER JOIN usuarios u ON m.id_usuario = u.id_usuario
INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
LEFT JOIN horarios_medicos hm ON m.id_medico = hm.id_medico
WHERE u.activo = 1;


-- ─────────────────────────────────────────────────────────────
-- 4. VISTA: Próximas Citas para Envío de Recordatorios
-- Filtra las citas activas de las próximas 24 horas y cruza las preferencias
-- de notificación del usuario para usarse en un script o tarea programada.
-- ─────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_recordatorios_pendientes;
CREATE VIEW vw_recordatorios_pendientes AS
SELECT
    c.id_cita,
    c.fecha,
    c.hora,
    c.motivo,
    c.estado,
    u_pac.id_usuario AS id_usuario_paciente,
    u_pac.nombre AS nombre_paciente,
    u_pac.email AS email_paciente,
    u_pac.telefono AS telefono_paciente,
    u_med.nombre AS nombre_medico,
    e.nombre AS especialidad,
    nc.notif_email,
    nc.notif_whatsapp,
    nc.recordatorio_24h,
    nc.recordatorio_2h
FROM citas c
INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
INNER JOIN usuarios u_pac ON p.id_usuario = u_pac.id_usuario
INNER JOIN medicos m ON c.id_medico = m.id_medico
INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
LEFT JOIN notificaciones_config nc ON u_pac.id_usuario = nc.id_usuario
WHERE c.estado IN ('programada', 'confirmada', 'reprogramada')
    AND TIMESTAMP(c.fecha, c.hora) >= NOW()
    AND TIMESTAMP(c.fecha, c.hora) <= DATE_ADD(NOW(), INTERVAL 24 HOUR);


-- ─────────────────────────────────────────────────────────────
-- 5. VISTA: Reportes y Métricas para el Administrador
-- Ofrece un consolidado general del sistema.
-- ─────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_reporte_general_citas;
CREATE VIEW vw_reporte_general_citas AS
SELECT
    c.id_cita,
    c.fecha,
    c.hora,
    c.estado,
    e.nombre AS especialidad,
    u_med.nombre AS nombre_medico,
    u_pac.nombre AS nombre_paciente,
    c.creado_en AS fecha_reserva
FROM citas c
INNER JOIN medicos m ON c.id_medico = m.id_medico
INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
INNER JOIN especialidades e ON m.id_especialidad = e.id_especialidad
INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
INNER JOIN usuarios u_pac ON p.id_usuario = u_pac.id_usuario;

-- ─────────────────────────────────────────────────────────────
-- 6. VISTA: Relación de Médicos y Pacientes para el Médico
-- Permite al médico ver todos sus pacientes con citas activas.
-- ─────────────────────────────────────────────────────────────

DROP VIEW IF EXISTS vw_vista_medico_pacientes;
CREATE VIEW vw_vista_medico_pacientes AS
SELECT DISTINCT
        m.id_medico,
    p.id_paciente,
        u_pac.nombre AS nombre_paciente,
        u_pac.dni AS dni_paciente,
        u_pac.telefono AS telefono_paciente,
    fn_calcular_edad(p.fecha_nacimiento) AS edad_paciente,
    p.genero AS genero_paciente,
    p.tipo_sangre
FROM citas c
INNER JOIN medicos m ON c.id_medico = m.id_medico
INNER JOIN usuarios u_med ON m.id_usuario = u_med.id_usuario
INNER JOIN pacientes p ON c.id_paciente = p.id_paciente
INNER JOIN usuarios u_pac ON p.id_usuario = u_pac.id_usuario
WHERE c.estado IN ('programada', 'confirmada', 'en_curso', 'reprogramada')
    AND u_med.activo = 1
    AND u_pac.rol = 'paciente';

-- ─────────────────────────────────────────────────────────────
-- 7. VISTA: Lista de Médicos y Pacientes para el Administrador
-- Permite al administrador ver todos los usuarios con rol de médico o paciente.
-- ─────────────────────────────────────────────────────────────

DROP VIEW IF EXISTS vw_vista_admin_medicosypacientes;
CREATE VIEW vw_vista_admin_medicosypacientes AS
SELECT
    u.id_usuario,
    u.nombre,
    u.email,
    u.telefono,
    u.rol
FROM usuarios u
WHERE u.rol IN ('medico', 'paciente');
-- =============================================================
-- TRIGGERS
-- El historial de cambios de estado se registra en los procedimientos.
-- No se crea un trigger AFTER UPDATE para evitar filas duplicadas.
-- =============================================================
