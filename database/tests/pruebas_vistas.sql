USE sistema_citas;
SET NAMES utf8mb4;

-- ====================================================================
-- PRUEBAS DE VISTAS
-- Requiere: 01_esquema.sql, 02_funciones.sql, 03_procedimientos.sql
--           y 04_vistas.sql
-- ====================================================================

-- ---------------------------------------------------------
-- 1. Vista: vw_agenda_paciente
-- ---------------------------------------------------------
SELECT
    id_cita,
    nombre_medico,
    especialidad,
    fecha,
    hora,
    motivo,
    estado,
    IF(permite_reprogramar_cancelar = 1, 'Si', 'No (menos de 24h)') AS puede_modificar
FROM vw_agenda_paciente
WHERE id_paciente = 1
ORDER BY fecha DESC, hora DESC;

-- ---------------------------------------------------------
-- 2. Vista: vw_agenda_medico
-- ---------------------------------------------------------
SELECT
    id_cita,
    hora,
    nombre_paciente,
    dni_paciente,
    edad_paciente,
    genero_paciente,
    tipo_sangre,
    motivo,
    estado
FROM vw_agenda_medico
WHERE id_medico = 1
ORDER BY fecha ASC, hora ASC;

-- ---------------------------------------------------------
-- 3. Vista: vw_medicos_horarios
-- ---------------------------------------------------------
SELECT
    nombre_medico,
    especialidad,
    dia_semana_nombre,
    hora_inicio,
    hora_fin,
    tipo
FROM vw_medicos_horarios
WHERE especialidad = 'Cardiología'
  AND horario_activo = 1
ORDER BY dia_semana ASC, hora_inicio ASC;

-- ---------------------------------------------------------
-- 4. Vista: vw_recordatorios_pendientes
-- ---------------------------------------------------------
SELECT
    id_cita,
    nombre_paciente,
    email_paciente,
    telefono_paciente,
    nombre_medico,
    especialidad,
    fecha,
    hora,
    notif_email,
    notif_whatsapp
FROM vw_recordatorios_pendientes
WHERE recordatorio_24h = 1;

-- ---------------------------------------------------------
-- 5. Vista: vw_reporte_general_citas
-- ---------------------------------------------------------
SELECT
    estado,
    COUNT(*) AS total
FROM vw_reporte_general_citas
GROUP BY estado;

SELECT
    especialidad,
    COUNT(*) AS total_reservas
FROM vw_reporte_general_citas
GROUP BY especialidad
ORDER BY total_reservas DESC;

-- ---------------------------------------------------------
-- 6. Vista: vw_vista_medico_pacientes
-- ---------------------------------------------------------
SELECT *
FROM vw_vista_medico_pacientes
WHERE id_medico = 1
ORDER BY nombre_paciente;

-- ---------------------------------------------------------
-- 7. Vista: vw_vista_admin_medicosypacientes
-- ---------------------------------------------------------
SELECT *
FROM vw_vista_admin_medicosypacientes
ORDER BY rol, nombre;
