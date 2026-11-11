# Sistema de Gestión de Citas Médicas

Sistema web para la gestión de citas de un centro de salud (pacientes, médicos y
administradores), construido sobre PHP, MySQL/MariaDB y JavaScript.

## Estructura del proyecto

```text
sistema-gestion-citas/
├── database/                          # Base de datos (ejecutar en orden)
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

Ejecutar los scripts **en orden** sobre una instalación limpia:

```bash
mysql -u root --default-character-set=utf8mb4 < database/01_esquema.sql
mysql -u root --default-character-set=utf8mb4 < database/02_funciones.sql
mysql -u root --default-character-set=utf8mb4 < database/03_procedimientos.sql
mysql -u root --default-character-set=utf8mb4 < database/04_vistas.sql
```

Notas:

- `01_esquema.sql` elimina y recrea la base `sistema_citas` con charset
  `utf8mb4`, por lo que una nueva ejecución reinicia los datos.
- `02`, `03` y `04` usan `DROP ... IF EXISTS`, así que pueden volver a
  ejecutarse sin errores.
- Las funciones deben crearse antes que los procedimientos y las vistas, porque
  ambos dependen de ellas.

## Pruebas

Los siguientes scripts crean y modifican datos, y algunas pruebas provocan
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
