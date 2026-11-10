USE sistema_citas;
SET NAMES utf8mb4;

-- ====================================================================
-- 05. VERIFICACION DE TRANSACCIONES
-- --------------------------------------------------------------------
-- Comprueba ROLLBACK, SAVEPOINT, atomicidad de los procedimientos y
-- COMMIT. Algunas pruebas provocan errores a proposito, por lo que el
-- script debe ejecutarse con la opcion --force:
--
--   mysql --force -u root < database/05_transactions.sql
--
-- Requiere haber ejecutado 01_esquema.sql, 02_funciones.sql,
-- 03_procedimientos.sql y 04_vistas.sql sobre una base limpia.
-- ====================================================================

-- ---------------------------------------------------------
-- PRUEBA 1: ROLLBACK explicito descarta todos los cambios
-- ---------------------------------------------------------
START TRANSACTION;
INSERT INTO especialidades (nombre) VALUES ('Especialidad Temporal');

SELECT COUNT(*) AS dentro_transaccion
FROM especialidades
WHERE nombre = 'Especialidad Temporal';

ROLLBACK;

SELECT COUNT(*) AS despues_rollback
FROM especialidades
WHERE nombre = 'Especialidad Temporal';

-- ---------------------------------------------------------
-- PRUEBA 2: SAVEPOINT revierte solo una parte del trabajo
-- ---------------------------------------------------------
START TRANSACTION;
INSERT INTO especialidades (nombre) VALUES ('Especialidad Persistente');
SAVEPOINT sp_antes_del_cambio;

UPDATE especialidades
SET nombre = 'Nombre Temporal'
WHERE nombre = 'Especialidad Persistente';

SELECT nombre AS durante_savepoint
FROM especialidades
WHERE nombre = 'Nombre Temporal';

ROLLBACK TO SAVEPOINT sp_antes_del_cambio;

SELECT nombre AS tras_rollback_savepoint
FROM especialidades
WHERE nombre = 'Especialidad Persistente';

ROLLBACK;

-- ---------------------------------------------------------
-- PRUEBA 3: una violacion de unicidad no deja filas parciales
-- ---------------------------------------------------------
SET @antes = (SELECT COUNT(*) FROM usuarios);

START TRANSACTION;
INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol)
VALUES ('Usuario Temporal 1', 'temp1@test.com', '$2y$10$hash', '900000001', '90000001', 'paciente');

-- ERROR esperado: DNI duplicado
INSERT INTO usuarios (nombre, email, password_hash, telefono, dni, rol)
VALUES ('Usuario Temporal 2', 'temp2@test.com', '$2y$10$hash', '900000002', '90000001', 'paciente');

ROLLBACK;

SET @despues = (SELECT COUNT(*) FROM usuarios);

SELECT
    @antes   AS usuarios_antes,
    @despues AS usuarios_despues,
    IF(@antes = @despues, 'OK: rollback completo', 'FALLO: quedaron filas') AS resultado;

-- ---------------------------------------------------------
-- PRUEBA 4: atomicidad de sp_registrar_medico
-- Inserta el usuario y luego falla al asignar una especialidad
-- inexistente; el EXIT HANDLER debe revertir todo.
-- ---------------------------------------------------------
SET @antes = (SELECT COUNT(*) FROM usuarios);

-- ERROR esperado: la especialidad 99 no existe (FK)
CALL sp_registrar_medico(
    'Dr. Transaccion',
    'tx.medico@test.com',
    '$2y$10$hash',
    '900000003',
    '90000003',
    99
);

SET @despues = (SELECT COUNT(*) FROM usuarios);

SELECT
    @antes   AS usuarios_antes,
    @despues AS usuarios_despues,
    IF(@antes = @despues, 'OK: rollback atomico del procedimiento', 'FALLO: usuario huerfano') AS resultado;

-- ---------------------------------------------------------
-- PRUEBA 5: COMMIT persiste los cambios
-- ---------------------------------------------------------
START TRANSACTION;
INSERT INTO especialidades (nombre) VALUES ('Especialidad Confirmada');
COMMIT;

SELECT COUNT(*) AS persiste_tras_commit
FROM especialidades
WHERE nombre = 'Especialidad Confirmada';

DELETE FROM especialidades
WHERE nombre = 'Especialidad Confirmada';

-- ---------------------------------------------------------
-- VERIFICACION FINAL: no deben quedar datos de prueba
-- ---------------------------------------------------------
SELECT COUNT(*) AS especialidades_temporales
FROM especialidades
WHERE nombre IN (
    'Especialidad Temporal',
    'Especialidad Persistente',
    'Nombre Temporal',
    'Especialidad Confirmada'
);
