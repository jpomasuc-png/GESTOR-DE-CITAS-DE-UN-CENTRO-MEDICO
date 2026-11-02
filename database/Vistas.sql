USE sistema_citas;

-- ─────────────────────────────────────────────────────────────
-- 1. VISTA: Agenda del Paciente (Para el Dashboard del Paciente)
-- Muestra todas las citas con los datos del médico, especialidad y estado.
-- ─────────────────────────────────────────────────────────────
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
    fn_validar_anticipacion_24h(c.fecha, c.hora) AS permite_reprogramar_cancelar
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
WHERE c.estado IN ('programada', 'confirmada')
  AND CONCAT(c.fecha, ' ', c.hora) >= NOW()
  AND CONCAT(c.fecha, ' ', c.hora) <= DATE_ADD(NOW(), INTERVAL 24 HOUR);


-- ─────────────────────────────────────────────────────────────
-- 5. VISTA: Reportes y Métricas para el Administrador
-- Ofrece un consolidado general del sistema.
-- ─────────────────────────────────────────────────────────────
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

CREATE VIEW vw_vista_medico_pacientes AS
SELECT
    p.id_paciente,
    u.nombre AS nombre_paciente,
    u.dni AS dni_paciente,
    u.telefono AS telefono_paciente,
    fn_calcular_edad(p.fecha_nacimiento) AS edad_paciente,
    p.genero AS genero_paciente,
    p.tipo_sangre
FROM usuarios u
INNER JOIN medicos m ON u.id_usuario = m.id_usuario
INNER JOIN pacientes p ON m.id_medico = p.id_medico
INNER JOIN citas c ON p.id_paciente = c.id_paciente
WHERE c.estado IN ('programada', 'confirmada') AND u.rol = 'paciente';

-- ─────────────────────────────────────────────────────────────
-- 7. VISTA: Lista de Médicos y Pacientes para el Administrador
-- Permite al administrador ver todos los usuarios con rol de médico o paciente.
-- ─────────────────────────────────────────────────────────────

CREATE VIEW vw_vista_admin_medicosypacientes AS
SELECT 
    u.id_usuario,
    u.nombre,
    u.email,
    u.telefono, 
    u.rol
FROM usuarios u
WHERE u.rol IN ('medico', 'paciente')
GROUP BY u.rol
ORDER BY u.id_usuario;

