## Estructura del Proyecto

```text
sistema-gestion-citas/
├── database/                   # Scripts de la base de datos (tablas y datos iniciales)
├── backend/                    # Lógica del servidor y API REST
│   ├── config/                 # Ajustes del sistema y conexión a la BD
│   ├── controllers/            # Manejo de peticiones y respuestas
│   ├── models/                 # Consultas SQL y gestión de datos
│   ├── middlewares/            # Control de acceso y protección de rutas
│   ├── routes/                 # Definición de endpoints (/api/login, /api/citas)
│   └── helpers/                # Funciones auxiliares (validaciones, utilidades)
├── frontend/                   # Interfaz de usuario (Vistas y cliente web)
│   ├── assets/                 # Estilos (CSS) y scripts del cliente (JS)
│   ├── views/                  # Vistas HTML/PHP organizadas por módulos
│   └── index.php               # Punto de entrada principal a la app
└── docs/                       # Manuales y documentación adicional