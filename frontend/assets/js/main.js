document.addEventListener("DOMContentLoaded", () => {
    
    // Lógica para la vista de Login
    const loginForm = document.getElementById("login-form");
    
    if (loginForm) {
        loginForm.addEventListener("submit", (e) => {
            e.preventDefault(); // Evita que la página se recargue
            
            const email = document.getElementById("email").value;
            const password = document.getElementById("password").value;
            const errorDiv = document.getElementById("error-message");
            
            // Simulación temporal: Validar si los campos están vacíos
            if (!email || !password) {
                errorDiv.textContent = "Por favor, completa todos los campos.";
                errorDiv.style.display = "block";
                return;
            }

            // Aquí es donde conectaremos con api.php más adelante.
            // Por ahora, simulamos un inicio de sesión exitoso redirigiendo al dashboard.
            errorDiv.style.display = "none";
            window.location.href = "../dashboard.html"; 
        });
    }
});

// ==========================================
    // Lógica para la vista de Agendar Cita
    // ==========================================
    const bookForm = document.getElementById("book-form");
    const dateInput = document.getElementById("date");
    const doctorSelect = document.getElementById("doctor");
    const doctorInfoBox = document.getElementById("doctor-info");
    const docSpecialty = document.getElementById("doc-specialty");

    // Mostrar fecha actual en el topbar si existe
    const topbarDate = document.getElementById('current-date');
    if (topbarDate) {
        topbarDate.textContent = new Date().toISOString().split('T')[0];
    }

    if (bookForm) {
        // 1. Bloquear fechas pasadas en el input de fecha
        const today = new Date().toISOString().split('T')[0];
        dateInput.setAttribute('min', today);

        // 2. Mostrar info del médico al seleccionarlo
        doctorSelect.addEventListener('change', function() {
            if (this.value) {
                // Obtenemos el texto de la opción seleccionada y sacamos la especialidad
                const text = this.options[this.selectedIndex].text;
                const especialidad = text.split('—')[1].trim();
                docSpecialty.textContent = especialidad;
                doctorInfoBox.style.display = 'block';
            } else {
                doctorInfoBox.style.display = 'none';
            }
        });

        // 3. Simular el guardado de la cita
        bookForm.addEventListener("submit", (e) => {
            e.preventDefault();
            
            const successDiv = document.getElementById("success-message");
            successDiv.style.display = "block";
            
            // Ocultamos el formulario para simular que procesó
            bookForm.style.opacity = "0.5";
            bookForm.querySelector('button').disabled = true;

            // Redirigimos a "Mis citas" después de 2 segundos
            setTimeout(() => {
                window.location.href = "mis_citas.html";
            }, 2000);
        });
    }

    // ==========================================
    // Lógica para la vista de Mis Citas
    // ==========================================
    
    // Función global para simular la cancelación de una cita
    window.cancelarCita = function(citaId) {
        if (confirm("¿Estás seguro de que deseas cancelar esta cita?")) {
            const badge = document.getElementById(`badge-${citaId}`);
            const actions = document.getElementById(`actions-${citaId}`);
            const item = document.getElementById(`cita-${citaId}`);
            
            if (badge && actions && item) {
                // Cambiar el diseño visual
                badge.className = "badge badge-red";
                badge.textContent = "Cancelada";
                
                // Ocultar botones
                actions.style.display = "none";
                
                // Bajar opacidad para indicar que ya no está activa
                item.style.backgroundColor = "var(--bg-background)";
                item.style.opacity = "0.8";
            }
        }
    };