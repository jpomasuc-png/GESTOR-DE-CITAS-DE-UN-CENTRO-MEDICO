USE sistema_citas;
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

-- ─────────────────────────────────────────────────────────────
-- 3. FUNCIÓN: Obtener Perfil Completo del Paciente
-- Retorna en una sola llamada los datos personales y de cuenta del Paciente.
-- ─────────────────────────────────────────────────────────────
DELIMITER //

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

CREATE FUNCTION fn_obtener_tasa_completacion() 
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total_citas INT;
    DECLARE v_citas_completadas INT;
    DECLARE v_tasa DECIMAL(5,2);

    SELECT COUNT(*), SUM(CASE WHEN estado = 'completada' THEN 1 ELSE 0 END) 
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