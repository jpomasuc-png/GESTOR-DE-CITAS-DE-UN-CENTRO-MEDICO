document.addEventListener("DOMContentLoaded", () => {
  const byId = (id) => document.getElementById(id);

  // Fecha actual en la topbar
  const formattedDate = new Date().toLocaleDateString("es-ES", {
    day: "2-digit",
    month: "short",
    year: "numeric"
  });
  const topbarDate = byId("current-date");
  if (topbarDate) {
    topbarDate.textContent = formattedDate;
  }
  const topbarDateInline = byId("current-date-inline");
  if (topbarDateInline) {
    topbarDateInline.textContent = formattedDate;
  }

  // Menú lateral en móviles
  const menuToggle = byId("menu-toggle");
  const sidebar = byId("sidebar");
  const overlay = byId("sidebar-overlay");
  const sidebarClose = byId("sidebar-close");

  if (menuToggle && sidebar && overlay) {
    const openMenu = () => {
      sidebar.classList.add("open");
      overlay.classList.add("open");
      document.body.classList.add("no-scroll");
      menuToggle.setAttribute("aria-expanded", "true");
    };

    const closeMenu = () => {
      sidebar.classList.remove("open");
      overlay.classList.remove("open");
      document.body.classList.remove("no-scroll");
      menuToggle.setAttribute("aria-expanded", "false");
    };

    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-controls", "sidebar");
    menuToggle.addEventListener("click", () => {
      if (sidebar.classList.contains("open")) {
        closeMenu();
      } else {
        openMenu();
      }
    });

    overlay.addEventListener("click", closeMenu);

    if (sidebarClose) {
      sidebarClose.addEventListener("click", closeMenu);
    }

    sidebar.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", closeMenu);
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && sidebar.classList.contains("open")) {
        closeMenu();
        menuToggle.focus();
      }
    });
  }

  // Inicio de sesión (demo, sin API): redirige según el rol del correo
  const loginForm = byId("login-form");
  if (loginForm) {
    loginForm.addEventListener("submit", (event) => {
      event.preventDefault();

      const email = byId("email").value.trim().toLowerCase();
      const password = byId("password").value;
      const errorDiv = byId("error-message");

      if (!email || !password) {
        if (errorDiv) {
          errorDiv.textContent = "Por favor, completa todos los campos.";
          errorDiv.style.display = "block";
        }
        return;
      }

      if (errorDiv) {
        errorDiv.style.display = "none";
      }

      const demoAccounts = {
        "admin@clinica.com": "../admin/dashboard.html",
        "admin@demo.com": "../admin/dashboard.html",
        "atorres@clinica.com": "../medico/dashboard.html",
        "lmendoza@clinica.com": "../medico/dashboard.html",
        "medico@demo.com": "../medico/dashboard.html",
        "paciente@demo.com": "../paciente/dashboard.html",
        "ana@gmail.com": "../paciente/dashboard.html",
        "carlos@gmail.com": "../paciente/dashboard.html",
        "maria@gmail.com": "../paciente/dashboard.html"
      };

      let target = demoAccounts[email];
      if (!target) {
        if (email.includes("admin")) {
          target = "../admin/dashboard.html";
        } else if (email.includes("medico") || email.includes("médico") || email.includes("doctor") || email.startsWith("dr") || email.startsWith("dra")) {
          target = "../medico/dashboard.html";
        } else {
          target = "../paciente/dashboard.html";
        }
      }

      window.location.href = target;
    });
  }

  // Registro de pacientes
  const registerForm = byId("register-form");
  if (registerForm) {
    registerForm.addEventListener("submit", (event) => {
      event.preventDefault();

      const password = byId("password").value;
      const errorDiv = byId("error-message");

      if (password.length < 6) {
        if (errorDiv) {
          errorDiv.textContent = "La contraseña debe tener al menos 6 caracteres.";
          errorDiv.style.display = "block";
        }
        return;
      }

      window.location.href = "login.html";
    });
  }

  // Agendar cita
  const bookForm = byId("book-form");
  if (bookForm) {
    const dateInput = byId("date");
    const doctorSelect = byId("doctor");
    const doctorInfoBox = byId("doctor-info");
    const docSpecialty = byId("doc-specialty");

    if (dateInput) {
      dateInput.setAttribute("min", new Date().toISOString().split("T")[0]);
    }

    if (doctorSelect && doctorInfoBox && docSpecialty) {
      doctorSelect.addEventListener("change", function () {
        if (this.value) {
          const text = this.options[this.selectedIndex].text;
          const specialty = text.split("—")[1] || text;
          docSpecialty.textContent = specialty.trim();
          doctorInfoBox.style.display = "block";
        } else {
          doctorInfoBox.style.display = "none";
        }
      });
    }

    bookForm.addEventListener("submit", (event) => {
      event.preventDefault();

      const successDiv = byId("success-message");
      if (successDiv) {
        successDiv.style.display = "block";
      }

      bookForm.style.opacity = "0.5";
      const submitButton = bookForm.querySelector('button[type="submit"]');
      if (submitButton) {
        submitButton.disabled = true;
      }

      setTimeout(() => {
        window.location.href = "mis_citas.html";
      }, 2000);
    });
  }

  // Cancelar cita (paciente)
  window.cancelarCita = function (citaId) {
    if (!confirm("¿Estás seguro de que deseas cancelar esta cita?")) {
      return;
    }

    const badge = byId(`badge-${citaId}`);
    const actions = byId(`actions-${citaId}`);
    const item = byId(`cita-${citaId}`);

    if (badge && actions && item) {
      badge.className = "badge badge-red";
      badge.textContent = "Cancelada";
      actions.style.display = "none";
      item.style.backgroundColor = "var(--bg-background)";
      item.style.opacity = "0.8";
    }
  };

  // Acciones sobre citas (médico y paciente)
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-cita-action]");
    if (!button) {
      return;
    }

    const action = button.dataset.citaAction;
    const row = button.closest(".list-item");
    const badge = row ? row.querySelector(".badge") : null;

    if (action === "reprogramar") {
      alert("Modal de reprogramación en construcción");
      return;
    }

    if (action === "cancelar") {
      if (!confirm("¿Estás seguro de que deseas cancelar esta cita?")) {
        return;
      }
      if (badge) {
        badge.className = "badge badge-red";
        badge.textContent = "Cancelada";
      }
      if (row) {
        row.querySelectorAll("[data-cita-action]").forEach((btn) => {
          btn.disabled = true;
          btn.style.opacity = "0.5";
        });
      }
      return;
    }

    if (action === "iniciar") {
      if (badge) {
        badge.className = "badge badge-blue";
        badge.textContent = "En curso";
      }
      button.textContent = "Completar";
      button.dataset.citaAction = "completar";
      button.classList.remove("btn-primary");
      button.classList.add("btn-secondary");
      return;
    }

    if (action === "completar") {
      if (badge) {
        badge.className = "badge badge-green";
        badge.textContent = "Completada";
      }
      if (row) {
        row.querySelectorAll("[data-cita-action]").forEach((btn) => {
          btn.disabled = true;
          btn.style.opacity = "0.5";
        });
      }
    }
  });

  // Notificaciones: marcar todas como leídas
  const markAllRead = byId("mark-all-read");
  if (markAllRead) {
    markAllRead.addEventListener("click", () => {
      document.querySelectorAll(".list-item.is-unread").forEach((item) => {
        item.classList.remove("is-unread");
      });
    });
  }

  // Detalle de cita / perfil (demo)
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-row-detail]");
    if (!button) {
      return;
    }

    const row = button.closest(".list-item");
    if (!row) {
      return;
    }

    const details = Array.from(row.querySelectorAll("p, span"))
      .map((element) => element.textContent.trim())
      .filter(Boolean);

    alert(details.join(" · "));
  });

  // Filtros de citas (administrador)
  const appointmentFilters = byId("appointment-filters");
  if (appointmentFilters) {
    const list = byId("appointment-list");
    const statusFilter = byId("filter-status");
    const statusDetails = {
      programada: { label: "Programada", badge: "badge-blue" },
      confirmada: { label: "Confirmada", badge: "badge-green" },
      en_curso: { label: "En curso", badge: "badge-amber" },
      completada: { label: "Completada", badge: "badge-gray" },
      cancelada: { label: "Cancelada", badge: "badge-red" }
    };

    const applyAppointmentFilter = () => {
      if (!list || !statusFilter) {
        return;
      }

      list.querySelectorAll(".appointment-row").forEach((row) => {
        row.hidden = Boolean(statusFilter.value) && row.dataset.estado !== statusFilter.value;
      });
    };

    appointmentFilters.addEventListener("submit", (event) => {
      event.preventDefault();
      applyAppointmentFilter();
    });

    appointmentFilters.addEventListener("change", (event) => {
      if (event.target === statusFilter) {
        applyAppointmentFilter();
      }
    });

    if (list) {
      list.addEventListener("change", (event) => {
        const select = event.target.closest("[data-status-select]");
        if (!select) {
          return;
        }

        const row = select.closest(".appointment-row");
        const badge = row ? row.querySelector("[data-status-badge]") : null;
        const status = statusDetails[select.value];
        if (!row || !badge || !status) {
          return;
        }

        row.dataset.estado = select.value;
        badge.className = `badge ${status.badge}`;
        badge.textContent = status.label;
        applyAppointmentFilter();
      });
    }
  }

  // Directorio de médicos (administrador, demostración local)
  const doctorList = byId("doctor-list");
  const doctorDialog = byId("doctor-dialog");
  const doctorForm = byId("doctor-form");
  if (doctorList) {
    doctorList.addEventListener("click", (event) => {
      const button = event.target.closest(".doctor-toggle");
      if (!button) {
        return;
      }

      const row = button.closest(".doctor-row");
      const status = row.querySelector(".doctor-status");
      const isActive = row.dataset.estado === "activo";
      const doctorName = row.querySelector(".doctor-name").textContent;

      row.dataset.estado = isActive ? "inactivo" : "activo";
      status.textContent = isActive ? "Inactivo" : "Activo";
      button.textContent = isActive ? "Activar" : "Desactivar";
      button.classList.toggle("is-inactive", isActive);
      button.setAttribute("aria-label", `${isActive ? "Activar" : "Desactivar"} a ${doctorName}`);
    });
  }

  const openDoctorForm = byId("open-doctor-form");
  const closeDoctorForm = byId("close-doctor-form");
  const cancelDoctorForm = byId("cancel-doctor-form");
  if (doctorDialog && doctorForm && openDoctorForm) {
    openDoctorForm.addEventListener("click", () => doctorDialog.showModal());
    closeDoctorForm.addEventListener("click", () => doctorDialog.close());
    cancelDoctorForm.addEventListener("click", () => doctorDialog.close());

    doctorForm.addEventListener("submit", (event) => {
      event.preventDefault();

      const formData = new FormData(doctorForm);
      const name = formData.get("nombre").trim();
      const email = formData.get("correo").trim();
      const specialty = formData.get("especialidad").trim();
      const phone = formData.get("telefono").trim();
      const schedule = formData.get("horario").trim();
      const initials = name
        .split(/\s+/)
        .filter((part) => !/^(dr\.?|dra\.?)$/i.test(part))
        .slice(0, 2)
        .map((part) => part[0])
        .join("")
        .toUpperCase();

      const row = document.createElement("tr");
      row.className = "doctor-row";
      row.dataset.estado = "activo";

      const profileCell = document.createElement("td");
      const profile = document.createElement("div");
      profile.className = "doctor-cell";
      const avatar = document.createElement("span");
      avatar.className = "doctor-avatar";
      avatar.setAttribute("aria-hidden", "true");
      avatar.textContent = initials;
      const info = document.createElement("div");
      info.className = "doctor-info";
      const nameElement = document.createElement("span");
      nameElement.className = "doctor-name";
      nameElement.textContent = name;
      const emailElement = document.createElement("span");
      emailElement.className = "doctor-email";
      emailElement.textContent = email;
      info.append(nameElement, emailElement);
      profile.append(avatar, info);
      profileCell.append(profile);

      const specialtyCell = document.createElement("td");
      specialtyCell.className = "doctor-data";
      specialtyCell.textContent = specialty;
      const phoneCell = document.createElement("td");
      phoneCell.className = "doctor-data";
      phoneCell.textContent = phone;
      const scheduleCell = document.createElement("td");
      scheduleCell.className = "doctor-data";
      const scheduleParts = schedule.split(",");
      scheduleCell.append(document.createTextNode(scheduleParts[0].trim()));
      if (scheduleParts[1]) {
        scheduleCell.append(document.createElement("br"), document.createTextNode(scheduleParts.slice(1).join(",").trim()));
      }
      const countCell = document.createElement("td");
      countCell.className = "doctor-count";
      countCell.textContent = "0";
      const statusCell = document.createElement("td");
      const status = document.createElement("span");
      status.className = "doctor-status";
      status.textContent = "Activo";
      statusCell.append(status);
      const actionCell = document.createElement("td");
      const toggle = document.createElement("button");
      toggle.className = "doctor-toggle";
      toggle.type = "button";
      toggle.textContent = "Desactivar";
      toggle.setAttribute("aria-label", `Desactivar a ${name}`);
      actionCell.append(toggle);

      row.append(profileCell, specialtyCell, phoneCell, scheduleCell, countCell, statusCell, actionCell);
      doctorList.querySelector("tbody").append(row);
      doctorForm.reset();
      doctorDialog.close();
    });
  }

  // Cambio de estado de pacientes (administrador)
  const patientList = byId("patient-list");
  if (patientList) {
    patientList.addEventListener("click", (event) => {
      const button = event.target.closest(".patient-toggle");
      if (!button) {
        return;
      }

      const row = button.closest(".patient-row");
      const status = row.querySelector(".patient-status");
      const isActive = row.dataset.estado === "activo";
      const patientName = row.querySelector(".patient-name").textContent;

      row.dataset.estado = isActive ? "inactivo" : "activo";
      status.textContent = isActive ? "Inactivo" : "Activo";
      button.textContent = isActive ? "Activar" : "Desactivar";
      button.classList.toggle("is-inactive", isActive);
      button.setAttribute("aria-label", `${isActive ? "Activar" : "Desactivar"} a ${patientName}`);
    });
  }

  // Formulario de perfil (demostración local)
  document.querySelectorAll("[data-profile-form]").forEach((form) => {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      alert("Perfil actualizado correctamente");
    });
  });

});
