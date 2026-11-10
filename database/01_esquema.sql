DROP DATABASE IF EXISTS sistema_citas;
CREATE DATABASE IF NOT EXISTS sistema_citas
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
-- =============================================================
-- 01. ESQUEMA DE LA BASE DE DATOS + DATOS DE PRUEBA
-- Instalacion completa: ejecutar este archivo primero.
-- =============================================================
SET NAMES utf8mb4;
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
-- 4. MÉDICOS 
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
  INDEX idx_citas_medico_fecha (id_medico, fecha, hora),
  INDEX idx_citas_paciente_fecha (id_paciente, fecha),
  INDEX idx_citas_estado (estado),
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

