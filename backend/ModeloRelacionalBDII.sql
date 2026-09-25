CREATE DATABASE IF NOT EXISTS sistema_citas;
USE sistema_citas;


-- ─────────────────────────────────────────────────────────────
-- 1. USUARIOS  (pacientes, médicos y administradores)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE usuarios (
  id            INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(120)    NOT NULL,
  email         VARCHAR(150)    NOT NULL UNIQUE,
  password_hash VARCHAR(255)    NOT NULL,          -- bcrypt / argon2
  telefono      VARCHAR(20),
  dni           VARCHAR(20)     NOT NULL UNIQUE,
  rol           ENUM('paciente','medico','admin')  NOT NULL DEFAULT 'paciente',
  activo        TINYINT(1)      NOT NULL DEFAULT 1,
  creado_en     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

-- ─────────────────────────────────────────────────────────────
-- 2. PERFILES DE PACIENTE  (datos clínicos extra)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE pacientes (
  id              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  usuario_id      INT UNSIGNED  NOT NULL UNIQUE,
  fecha_nacimiento DATE,
  genero          ENUM('Masculino','Femenino','Otro'),
  tipo_sangre     VARCHAR(5),                      -- O+, A-, AB+, etc.
  PRIMARY KEY (id),
  CONSTRAINT fk_paciente_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- 3. ESPECIALIDADES  (catálogo)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE especialidades (
  id     TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(80)      NOT NULL UNIQUE,
  PRIMARY KEY (id)
);

INSERT INTO especialidades (nombre) VALUES
  ('Medicina General'),
  ('Cardiología'),
  ('Pediatría'),
  ('Traumatología'),
  ('Ginecología'),
  ('Neurología'),
  ('Dermatología'),
  ('Oftalmología');

-- ─────────────────────────────────────────────────────────────
-- 4. MÉDICOS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE medicos (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  usuario_id       INT UNSIGNED    NOT NULL UNIQUE,
  especialidad_id  TINYINT UNSIGNED NOT NULL,
  horario          VARCHAR(80),                    -- texto libre p.ej. "Lun–Vie 08:00–16:00"
  PRIMARY KEY (id),
  CONSTRAINT fk_medico_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_medico_especialidad
    FOREIGN KEY (especialidad_id) REFERENCES especialidades (id)
);

-- ─────────────────────────────────────────────────────────────
-- 5. CITAS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE citas (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  paciente_id   INT UNSIGNED  NOT NULL,
  medico_id     INT UNSIGNED  NOT NULL,
  fecha         DATE          NOT NULL,
  hora          TIME          NOT NULL,
  motivo        TEXT          NOT NULL,
  notas_medico  TEXT,
  estado        ENUM(
                  'programada',
                  'confirmada',
                  'en_curso',
                  'completada',
                  'cancelada',
                  'reprogramada'
                ) NOT NULL DEFAULT 'programada',
  creado_en     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_cita_paciente
    FOREIGN KEY (paciente_id) REFERENCES usuarios (id),
  CONSTRAINT fk_cita_medico
    FOREIGN KEY (medico_id)   REFERENCES medicos (id)
);

-- Índices de búsqueda frecuente
CREATE INDEX idx_citas_fecha      ON citas (fecha);
CREATE INDEX idx_citas_paciente   ON citas (paciente_id);
CREATE INDEX idx_citas_medico     ON citas (medico_id);
CREATE INDEX idx_citas_estado     ON citas (estado);

-- ─────────────────────────────────────────────────────────────
-- 6. PREFERENCIAS DE NOTIFICACIÓN
-- ─────────────────────────────────────────────────────────────
CREATE TABLE notificaciones_config (
  usuario_id        INT UNSIGNED NOT NULL UNIQUE,
  notif_email       TINYINT(1)   NOT NULL DEFAULT 1,
  notif_whatsapp    TINYINT(1)   NOT NULL DEFAULT 0,
  recordatorio_24h  TINYINT(1)   NOT NULL DEFAULT 1,
  recordatorio_2h   TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (usuario_id),
  CONSTRAINT fk_notif_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────────────────────────
-- 7. HISTORIAL DE CAMBIOS DE ESTADO  (auditoría ligera)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE citas_historial (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  cita_id       INT UNSIGNED  NOT NULL,
  estado_ant    VARCHAR(20),
  estado_nuevo  VARCHAR(20)   NOT NULL,
  cambiado_por  INT UNSIGNED,                      -- usuario_id que hizo el cambio
  cambiado_en   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_hist_cita
    FOREIGN KEY (cita_id)      REFERENCES citas (id) ON DELETE CASCADE,
  CONSTRAINT fk_hist_usuario
    FOREIGN KEY (cambiado_por) REFERENCES usuarios (id) ON DELETE SET NULL
);