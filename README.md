# Sistema de Gestión de Citas Médicas

Sistema web para la gestión de citas de un centro de salud (pacientes, médicos y
administradores), construido sobre PHP, MySQL/MariaDB y JavaScript.

## Estructura del proyecto

```text
sistema-gestion-citas/
├── database/                          # Base de datos
│   ├── sistema_citas_completo.sql     # Instalador único principal
│   ├── 01_esquema.sql                 # Tablas + datos de prueba
│   ├── 02_funciones.sql               # Funciones definidas por el usuario
│   ├── 03_procedimientos.sql          # Procedimientos almacenados
│   ├── 04_vistas.sql                  # Vistas
│   ├── 05_transactions.sql            # Verificación de transacciones
│   └── tests/
│       ├── pruebas_procedimientos_funciones.sql
│       └── pruebas_vistas.sql
├── backend/                           # API REST (pendiente de implementación)
│   ├── config/                        # Conexión a la base de datos
│   ├── controllers/                   # Manejo de peticiones y respuestas
│   ├── models/                        # Consultas y acceso a datos
│   ├── middlewares/                   # Sesión, autenticación y roles
│   ├── routes/                        # Definición de endpoints
│   └── helpers/                       # Utilidades y validaciones
├── frontend/                          # Interfaz de usuario
│   ├── assets/                        # CSS y JS del cliente
│   ├── views/
│   │   ├── admin/                     # Panel general, citas, médicos, pacientes y reportes
│   │   ├── medico/                    # Panel, agenda de citas y horarios
│   │   ├── paciente/                  # Panel, citas, agenda, notificaciones y perfil
│   │   └── auth/                      # Inicio de sesión y registro
│   └── index.html                     # Punto de entrada
├── docs/                              # Documentación
└── README.md
```

## Instalación de la base de datos

El archivo principal es `database/sistema_citas_completo.sql`. En XAMPP, inicia
MySQL/MariaDB y ejecuta desde **CMD** en la carpeta raíz del proyecto:

```cmd
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < database\sistema_citas_completo.sql
```

También se puede importar ese mismo archivo desde phpMyAdmin. No es necesario
ejecutar los módulos `01`–`05` para instalar el proyecto.

> **ADVERTENCIA: este instalador es destructivo.** Ejecuta `DROP DATABASE IF
> EXISTS sistema_citas` y elimina todos los datos actuales de esa base antes de
> crearla de nuevo. Solo debe usarse en una instalación limpia o para reiniciar
> deliberadamente el entorno de demostración; no ejecutarlo en producción.

El script fija charset, zona horaria y modo SQL de la sesión, crea las tablas,
datos demo, funciones, procedimientos, vistas y triggers, y finaliza mostrando
conteos de objetos y datos. Puede ejecutarse otra vez sin errores, pero cada
ejecución vuelve a borrar y reconstruir `sistema_citas`.

## Pruebas

Primero instala la base con `database/sistema_citas_completo.sql`. Los
siguientes scripts crean y modifican datos, y algunas pruebas provocan
errores de forma intencional; usar `--force` para que continúen:

```bash
# Procedimientos almacenados y funciones
mysql --force -u root --default-character-set=utf8mb4 < database/tests/pruebas_procedimientos_funciones.sql

# Vistas
mysql -u root --default-character-set=utf8mb4 < database/tests/pruebas_vistas.sql

# Integridad transaccional (ROLLBACK, SAVEPOINT, COMMIT y atomicidad)
mysql --force -u root --default-character-set=utf8mb4 < database/05_transactions.sql
```

## Estado actual

- Base de datos: esquema, funciones, procedimientos, vistas y pruebas de
  transacciones verificados.
- Backend: estructura creada, archivos PHP aún vacíos.
- Frontend: vistas estáticas con datos de ejemplo para pacientes, médicos y
  administradores; falta conectar formularios, filtros y acciones con la API.
  Los módulos de médico y administrador reutilizan el diseño y la estructura
  visual del módulo de paciente.
