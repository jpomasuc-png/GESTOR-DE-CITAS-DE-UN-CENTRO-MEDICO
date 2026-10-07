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