<div align="center">

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Alan_Stefanov-blue?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/alanstefanov/)
[![Email](https://img.shields.io/badge/Email-alan.emanuel.stefanov@gmail.com-red?style=flat-square&logo=gmail)](mailto:alan.emanuel.stefanov@gmail.com)
[![GitHub](https://img.shields.io/badge/GitHub-AlanStefanov-black?style=flat-square&logo=github)](https://github.com/AlanStefanov)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

**Alan Stefanov** — Engineering Manager · DevOps Engineer · Software Developer · _La Plata, Argentina_

---

</div>

# 🛠️ Toolkit Dev & DevOps — Ecosistema .deb

> Instalador interactivo para Ubuntu/Debian con las herramientas esenciales para desarrollo y operaciones.

![UI Preview](https://img.shields.io/badge/UI-whiptail-brightgreen?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-orange?style=flat-square)
![Shell](https://img.shields.io/badge/Shell-Bash-blue?style=flat-square)

## ✨ Características

- **Interfaz interactiva** — Checklist con whiptail para seleccionar solo lo que necesitás
- **Instalación secuencial** — Cada herramienta se instala de forma independiente con feedback visual
- **Detección inteligente** — Saltea herramientas ya instaladas
- **Log detallado** — Todo queda registrado en `/tmp/toolkit-install-*.log`
- **Sin dependencias pesadas** — Solo necesita `whiptail` (se instala automáticamente si falta)

## 🚀 Uso

```bash
# 1. Clonar el repositorio
git clone https://github.com/AlanStefanov/toolkit-dev-ubuntu.git
cd toolkit-dev-ubuntu

# 2. Ejecutar el instalador
./toolkit-devops-install.sh
```

O directamente desde el repo:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AlanStefanov/toolkit-dev-ubuntu/main/toolkit-devops-install.sh)
```

## 📦 Herramientas incluidas

### 🖥️ Editores / IDE

| Herramienta | Descripción |
|-------------|-------------|
| **Visual Studio Code** | Editor de código multiplataforma de Microsoft |
| **Sublime Text 4** | Editor de texto rápido y liviano |
| **Neovim** | Editor CLI moderno (fork de Vim) |
| **OpenCode** | CLI de IA para asistencia en código |

### 🚀 Terminales

| Herramienta | Descripción |
|-------------|-------------|
| **Alacritty** | Terminal con aceleración GPU |
| **Warp Terminal** | Terminal moderna con integración de AI |
| **Tmux** | Multiplexor de terminal (múltiples paneles/ventanas) |

### 🗄️ Bases de Datos

| Herramienta | Descripción |
|-------------|-------------|
| **DBeaver CE** | Gestor de bases de datos universal |
| **psql + sqlite3 + mysql-client** | Clientes CLI para PostgreSQL, SQLite y MySQL |
| **Turso CLI** | CLI para Turso (base de datos edge/libsql) |

### ☁️ Cloud / Infra

| Herramienta | Descripción |
|-------------|-------------|
| **AWS CLI v2** | Interfaz de línea de comandos de AWS |
| **GitHub CLI (gh)** | Interfaz de GitHub desde la terminal |
| **kubectl** | CLI de Kubernetes |
| **Helm** | Package manager para Kubernetes |
| **Terraform** | Infrastructure as Code de HashiCorp |

### 🐳 Contenedores

| Herramienta | Descripción |
|-------------|-------------|
| **Docker Engine + Compose** | Contenedores (configurado sin sudo) |
| **Portainer** | GUI web para gestión de Docker |

### 🛠️ Dev Essentials

| Herramienta | Descripción |
|-------------|-------------|
| **nvm + Node.js LTS** | Version manager + Node.js |
| **python3-pip + venv** | Python package manager y entornos virtuales |
| **build-essential** | Compilador GCC, make y herramientas de build |
| **git + curl + wget** | Herramientas fundamentales |
| **GNU Make** | Automatización de builds |
| **OpenSSH Server** | Servidor SSH para acceso remoto |
| **tree** | Visualización de directorios en árbol |

### ⚡ CLI Power-ups

| Herramienta | Descripción |
|-------------|-------------|
| **jq** | Procesador JSON desde la terminal |
| **htop** | Monitor interactivo de procesos |
| **fzf** | Fuzzy finder universal (búsqueda rápida) |
| **ripgrep (rg)** | Búsqueda recursiva ultrarrápida en código |
| **bat** | cat con syntax highlighting |
| **lazygit** | Interfaz TUI para Git |

### 🔌 API Client

| Herramienta | Descripción |
|-------------|-------------|
| **Postman** | Cliente HTTP para testing de APIs (via Flatpak) |

### 🎨 Sistema / UI

| Herramienta | Descripción |
|-------------|-------------|
| **Dash to Dock** | Dock tipo macOS para GNOME |
| **sudo sin contraseña** | Configura NOPASSWD para tu usuario |
| **VLC Media Player** | Reproductor multimedia universal |

## 🧩 Agregar herramientas

¿Falta alguna herramienta? Hacé un fork, agregala y enviá un PR. Las instalaciones se definen como funciones en el script, es fácil extenderlo.

## 📄 Licencia

MIT — Ver [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Alan Stefanov** — [LinkedIn](https://www.linkedin.com/in/alan-stefanov-87b8721b9/) · [GitHub](https://github.com/AlanStefanov) · [Email](mailto:alan.emanuel.stefanov@gmail.com)

</div>
