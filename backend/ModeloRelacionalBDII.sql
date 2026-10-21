DROP DATABASE IF EXISTS sistema_citas;
CREATE DATABASE IF NOT EXISTS sistema_citas;
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
  PRIMARY KEY (id_usuario)
);

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
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- 3. ESPECIALIDADES
-- ─────────────────────────────────────────────────────────────
CREATE TABLE especialidades (
  id_especialidad TINYINT NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(80)      NOT NULL UNIQUE,
  PRIMARY KEY (id_especialidad)
);

INSERT INTO especialidades (nombre) VALUES
  ('Medicina General'), ('Cardiología'), ('Pediatría'), ('Traumatología');

-- ─────────────────────────────────────────────────────────────
-- 4. MÉDICOS (Corregido: sin columna horario)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE medicos (
  id_medico       INT     NOT NULL AUTO_INCREMENT,
  id_usuario      INT     NOT NULL UNIQUE,
  id_especialidad TINYINT NOT NULL,
  PRIMARY KEY (id_medico),
  CONSTRAINT fk_medico_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
  CONSTRAINT fk_medico_especialidad
    FOREIGN KEY (id_especialidad) REFERENCES especialidades (id_especialidad)
);

-- ─────────────────────────────────────────────────────────────
-- 5. HORARIOS DE MÉDICOS (Restablecida desde el diagrama)
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
  CONSTRAINT fk_horario_medico
    FOREIGN KEY (id_medico) REFERENCES medicos (id_medico) ON DELETE CASCADE
);

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
  estado        ENUM('programada','confirmada','en_curso','completada','cancelada','reprogramada') NOT NULL DEFAULT 'programada',
  creado_en     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cita),
  CONSTRAINT fk_cita_paciente
    FOREIGN KEY (id_paciente) REFERENCES pacientes (id_paciente),
  CONSTRAINT fk_cita_medico
    FOREIGN KEY (id_medico)   REFERENCES medicos (id_medico)
);
 
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
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE
);

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
  CONSTRAINT fk_hist_cita
    FOREIGN KEY (id_cita)      REFERENCES citas (id_cita) ON DELETE CASCADE,
  CONSTRAINT fk_hist_usuario
    FOREIGN KEY (cambiado_por) REFERENCES usuarios (id_usuario) ON DELETE SET NULL
);

-- =============================================================
-- DATOS DE PRUEBA (POBLACIÓN DE LA BASE DE DATOS)
-- =============================================================

INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol) VALUES
('Admin Principal', 'admin@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654321', '00000001', 'admin'),
('Dr. Alejandro Torres', 'atorres@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654322', '11111111', 'medico'),
('Dra. Lucía Mendoza', 'lmendoza@clinica.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654323', '22222222', 'medico'),
('Ana María García', 'ana@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654324', '33333333', 'paciente'),
('Carlos Ruiz', 'carlos@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654325', '44444444', 'paciente'),
('María Fernández', 'maria@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '987654326', '55555555', 'paciente');

INSERT INTO pacientes (id_usuario, fecha_nacimiento, genero, tipo_sangre) VALUES
(4, '1995-08-15', 'Femenino', 'O+'),
(5, '1988-03-22', 'Masculino', 'A-'),
(6, '2001-11-05', 'Femenino', 'B+');

-- Insertamos a los médicos 
INSERT INTO medicos (id_usuario, id_especialidad) VALUES
(2, 2), -- Dr. Torres (Cardiología), será el id_medico = 1
(3, 3); -- Dra. Mendoza (Pediatría), será el id_medico = 2

-- Le asignamos sus turnos semanales en la nueva tabla (Ej: 2=Lunes a 6=Viernes)
INSERT INTO horarios_medicos (id_medico, tipo, dia_semana, hora_inicio, hora_fin) VALUES
(1, 'regular', 2, '08:00:00', '14:00:00'), (1, 'regular', 3, '08:00:00', '14:00:00'), 
(1, 'regular', 4, '08:00:00', '14:00:00'), (1, 'regular', 5, '08:00:00', '14:00:00'), 
(1, 'regular', 6, '08:00:00', '14:00:00'),
(2, 'regular', 2, '14:00:00', '20:00:00'), (2, 'regular', 3, '14:00:00', '20:00:00'), 
(2, 'regular', 4, '14:00:00', '20:00:00'), (2, 'regular', 5, '14:00:00', '20:00:00'), 
(2, 'regular', 6, '14:00:00', '20:00:00');

INSERT INTO citas (id_paciente, id_medico, fecha, hora, motivo, notas_medico, estado) VALUES
(1, 1, '2026-10-15', '09:00:00', 'Dolor en el pecho al correr', 'Se recomienda electrocardiograma', 'completada'),
(2, 1, '2026-10-25', '10:00:00', 'Chequeo general de presión arterial', NULL, 'programada'),
(3, 2, '2026-10-26', '15:00:00', 'Control anual de niño sano', NULL, 'programada');

INSERT INTO notificaciones_config (id_usuario, notif_email, notif_whatsapp, recordatorio_24h) VALUES
(4, 1, 1, 1),
(5, 1, 0, 1);


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
    DECLARE v_citas_existentes INT;
    DECLARE v_dia_semana TINYINT;

    -- Obtener el día de la semana para la fecha solicitada (1=Domingo, 2=Lunes, etc.)
    SET v_dia_semana = DAYOFWEEK(p_fecha);

    -- 1. Validar si el médico trabaja ese día y obtener sus horas (Ignorando excepciones por ahora)
    SELECT MAX(hora_inicio), MAX(hora_fin) INTO v_hora_inicio, v_hora_fin
    FROM horarios_medicos
    WHERE id_medico = p_medico_id 
      AND dia_semana = v_dia_semana 
      AND tipo = 'regular' 
      AND activo = 1;

    -- 2. Validaciones lógicas
    IF v_hora_inicio IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: El médico no atiende consultas en el día de la semana seleccionado.';
    ELSEIF p_hora < v_hora_inicio OR p_hora > v_hora_fin THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: La hora solicitada está fuera del horario de atención del médico.';
    ELSE
        -- 3. Validar disponibilidad (que no choque con otra cita)
        SELECT COUNT(*) INTO v_citas_existentes
        FROM citas
        WHERE id_medico = p_medico_id AND fecha = p_fecha AND hora = p_hora 
          AND estado IN ('programada', 'confirmada', 'en_curso');

        IF v_citas_existentes > 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'ERROR: El médico ya tiene una cita reservada en esa fecha y hora.';
        ELSE
            -- 4. Registrar la cita
            INSERT INTO citas (id_paciente, id_medico, fecha, hora, motivo, estado)
            VALUES (p_paciente_id, p_medico_id, p_fecha, p_hora, p_motivo, 'programada');
        END IF;
    END IF;
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
    SELECT estado INTO v_estado_actual FROM citas WHERE id_cita = p_id_cita;

    IF v_estado_actual = 'cancelada' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: La cita ya está cancelada.';
    ELSEIF v_estado_actual = 'completada' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: No se puede cancelar una cita completada.';
    ELSE
        UPDATE citas SET estado = 'cancelada' WHERE id_cita = p_id_cita;
        INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
        VALUES (p_id_cita, v_estado_actual, 'cancelada', p_id_usuario);
    END IF;
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

    -- Obtenemos los datos actuales de la cita
    SELECT estado, fecha, hora, id_medico INTO v_estado_actual, v_fecha_actual, v_hora_actual, v_id_medico
    FROM citas WHERE id_cita = p_id_cita;

    -- 1. Validar restricción de tiempo con nuestra función (mínimo 24h antes)
    IF fn_validar_anticipacion_24h(v_fecha_actual, v_hora_actual) = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: Debe reprogramar con al menos 24 horas de anticipación.';
        
    -- 2. Validar que la cita no esté terminada o cancelada
    ELSEIF v_estado_actual IN ('completada', 'cancelada') THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'ERROR: No se puede reprogramar una cita completada o cancelada.';
        
    ELSE
        -- 3. Validar si el médico tiene ese nuevo horario libre
        SELECT COUNT(*) INTO v_choques FROM citas
        WHERE id_medico = v_id_medico AND fecha = p_nueva_fecha AND hora = p_nueva_hora 
        AND estado IN ('programada', 'confirmada', 'reprogramada');
        
        IF v_choques > 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'ERROR: El médico ya tiene una cita en ese nuevo horario.';
        ELSE
            -- 4. Actualizar la cita y liberar el cupo anterior
            UPDATE citas 
            SET fecha = p_nueva_fecha, hora = p_nueva_hora, estado = 'reprogramada' 
            WHERE id_cita = p_id_cita;
            
            -- 5. Registrar el movimiento en el historial
            INSERT INTO citas_historial (id_cita, estado_ant, estado_nuevo, cambiado_por)
            VALUES (p_id_cita, v_estado_actual, 'reprogramada', p_id_usuario);
        END IF;
    END IF;
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
    UPDATE notificaciones_config
    SET notif_email = p_notif_email,
        notif_whatsapp = p_notif_whatsapp,
        recordatorio_24h = p_rec_24h,
        recordatorio_2h = p_rec_2h
    WHERE id_usuario = p_id_usuario;
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
    UPDATE usuarios 
    SET password_hash = p_nuevo_password_hash 
    WHERE email = p_email AND activo = 1;
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


-- =============================================================
-- FUNCIONES DEFINIDAS PARA EL USUARIO
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. FUNCIÓN: Calcular la edad del paciente
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE FUNCTION fn_calcular_edad(p_fecha_nacimiento DATE) 
RETURNS INT 
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, p_fecha_nacimiento, CURDATE());
END //

DELIMITER ;

-- ─────────────────────────────────────────────────────────────
-- 2. FUNCIÓN: Validar Restricción de 24 Horas
-- ─────────────────────────────────────────────────────────────
DELIMITER //

CREATE FUNCTION fn_validar_anticipacion_24h(p_fecha DATE, p_hora TIME) 
RETURNS TINYINT(1)
DETERMINISTIC
BEGIN
    DECLARE v_fecha_cita DATETIME;
    DECLARE v_horas_restantes INT;
    
    SET v_fecha_cita = CONCAT(p_fecha, ' ', p_hora);
    
    -- Calculamos la diferencia en horas desde este momento (NOW) hasta la cita
    SET v_horas_restantes = TIMESTAMPDIFF(HOUR, NOW(), v_fecha_cita);
    
    IF v_horas_restantes >= 24 THEN
        RETURN 1; -- 1 significa "Válido" (Cumple la regla)
    ELSE
        RETURN 0; -- 0 significa "Inválido" (Faltan menos de 24h)
    END IF;
END //

DELIMITER ;