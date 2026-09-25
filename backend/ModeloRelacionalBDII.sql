CREATE DATABASE IF NOT EXISTS sistema_citas;
USE sistema_citas;

-- 1. Tabla: Inicio de Sesión Usuario
CREATE TABLE inicio_sesion_usuario (
    dni INT AUTO_INCREMENT PRIMARY KEY,
    ndocumento VARCHAR(20) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE,
    celular VARCHAR(20),
    contrasena VARCHAR(255) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL
);

-- 2. Tabla: Base de datos Medico
CREATE TABLE base_datos_medico (
    idmedico INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    celular INT,
    estado VARCHAR(50),
    dni VARCHAR(20) NOT NULL UNIQUE
);

-- 3. Tabla: Citas del usuario
CREATE TABLE citas_del_usuario (
    idmedico INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    celular INT,
    estado VARCHAR(50),
    dni VARCHAR(20) NOT NULL UNIQUE
);

-- 4. Tabla: Citas Medicas
CREATE TABLE citas_medicas (
    idcita INT AUTO_INCREMENT PRIMARY KEY,
    dni INT NOT NULL,
    fecha DATETIME NOT NULL,
    hora DATETIME NOT NULL,
    CONSTRAINT fk_citas_usuario FOREIGN KEY (dni) 
        REFERENCES inicio_sesion_usuario(dni) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 5. Tabla: Horarios y disponibilidad
CREATE TABLE horarios_y_disponibilidad (
    idcita INT NOT NULL,
    idmedico INT NOT NULL,
    horarios DATETIME NOT NULL,
    estado VARCHAR(50),
    PRIMARY KEY (idcita, idmedico),
    CONSTRAINT fk_horarios_cita FOREIGN KEY (idcita) 
        REFERENCES citas_medicas(idcita) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_horarios_medico FOREIGN KEY (idmedico) 
        REFERENCES base_datos_medico(idmedico) 
        ON DELETE CASCADE ON UPDATE CASCADE
);