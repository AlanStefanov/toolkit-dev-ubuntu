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

![UI](https://img.shields.io/badge/UI-TUI_Propio-blue?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-orange?style=flat-square)
![Shell](https://img.shields.io/badge/Shell-Bash-blue?style=flat-square)

## ✨ Características

- **Interfaz TUI interactiva** — Menú propio con navegación por teclado (↑↓), selección múltiple con espacio, "Todos/Ninguno"
- **Instalación secuencial** — Cada herramienta se instala de forma independiente con feedback visual
- **Detección inteligente** — Saltea herramientas ya instaladas
- **Log detallado** — Todo queda registrado en `/tmp/toolkit-install-*.log`
- **Orden por dependencias** — Las herramientas se instalan en orden para que las dependencias estén listas
- **sudo automático** — Detecta si necesita sudo y pide contraseña si es necesario

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

### 🧱 Base del Sistema

| Herramienta | Descripción |
|-------------|-------------|
| **git + curl + wget** | Control de versiones y descarga |
| **build-essential** | GCC, G++ y herramientas de build |
| **GNU Make** | Automatización de builds |
| **OpenSSH Server** | Servidor SSH habilitado |
| **tree** | Visualización de directorios |

### 🟢 Node / Python

| Herramienta | Descripción |
|-------------|-------------|
| **nvm + Node.js LTS** | Gestor de versiones de Node.js |
| **Python3 pip + venv** | Entorno Python completo |
| **Yarn** | Gestor de paquetes Node.js rápido |
| **ESLint** | Linter para JavaScript/TypeScript |

### ☕ Lenguajes / Runtimes

| Herramienta | Descripción |
|-------------|-------------|
| **SDKMAN! + JDK 21** | Gestor de JDKs + Java 21 LTS (Temurin) |
| **Go** | Compilador y herramientas Go |
| **Rust** | rustc + cargo + rustup |

### 🐳 Contenedores

| Herramienta | Descripción |
|-------------|-------------|
| **Docker Engine + Compose** | Contenedores (configurado sin sudo) |
| **Portainer** | GUI web para gestión de Docker |
| **act** | Corré GitHub Actions localmente |

### 🖥️ Editores / IDE

| Herramienta | Descripción |
|-------------|-------------|
| **Visual Studio Code** | Editor de Microsoft con extensiones |
| **Sublime Text 4** | Editor rápido y liviano |
| **Neovim** | Editor CLI moderno |
| **OpenCode** | CLI de IA para asistencia en código |

### 🤖 IA en el Terminal

| Herramienta | Descripción |
|-------------|-------------|
| **Claude Code CLI** | Asistente IA de Anthropic en terminal |

### 🗄️ Bases de Datos

| Herramienta | Descripción |
|-------------|-------------|
| **DBeaver CE** | Gestor de bases de datos universal |
| **psql + sqlite3 + mysql-client** | Clientes CLI para PostgreSQL, SQLite y MySQL |
| **Turso CLI** | CLI para Turso (base de datos edge/libsql) |
| **MongoDB Compass** | GUI oficial para MongoDB |
| **Redis Server + CLI** | Base de datos en memoria clave-valor |
| **Redis Insight** | GUI oficial para administrar Redis |

### ☁️ Cloud / Infra

| Herramienta | Descripción |
|-------------|-------------|
| **AWS CLI v2** | Interfaz de línea de comandos de AWS |
| **GitHub CLI (gh)** | GitHub desde la terminal |
| **Helm** | Package manager para Kubernetes |
| **Terraform** | Infraestructura como código (IaC) |
| **ngrok** | Túnel HTTP para exponer localhost |
| **Ansible** | Automatización y configuración devops |

### ☸️ Kubernetes

| Herramienta | Descripción |
|-------------|-------------|
| **kubectl** | CLI para clústeres Kubernetes |
| **k9s** | TUI interactiva para gestionar Kubernetes |

### 🛠️ Dev Local

| Herramienta | Descripción |
|-------------|-------------|
| **direnv** | Variables de entorno por directorio (.envrc) |
| **mkcert** | Certificados HTTPS locales sin warnings |
| **Zsh + Oh My Zsh** | Shell moderna con plugins y autosuggestions |

### 🚀 Terminales

| Herramienta | Descripción |
|-------------|-------------|
| **Warp Terminal** | Terminal moderna con IA integrada |
| **Tmux** | Multiplexor de sesiones |

### ⚡ CLI Power-ups

| Herramienta | Descripción |
|-------------|-------------|
| **jq** | Procesador JSON en terminal |
| **htop** | Monitor de procesos interactivo |
| **fzf** | Búsqueda fuzzy para CLI |
| **ripgrep (rg)** | grep ultra-rápido |
| **bat** | cat con syntax highlighting |
| **lazygit** | Git con UI interactiva en terminal |
| **eza** | ls con colores, icons y git status |
| **zoxide** | Navegación inteligente de directorios |
| **fd** | find rápido con sintaxis intuitiva |

### 🔌 API Client

| Herramienta | Descripción |
|-------------|-------------|
| **Postman** | Cliente visual para APIs REST |

### 🎨 Sistema / UI

| Herramienta | Descripción |
|-------------|-------------|
| **Dash to Dock** | Dock estilo macOS para GNOME |
| **VLC Media Player** | Reproductor multimedia universal |
| **sudo sin contraseña** | Configura NOPASSWD para tu usuario |

## 🧩 Agregar herramientas

¿Falta alguna herramienta? Hacé un fork, agregala y enviá un PR. Las instalaciones se definen como funciones en el script, es fácil extenderlo.

## 📄 Licencia

MIT — Ver [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Alan Stefanov** — [LinkedIn](https://www.linkedin.com/in/alan-stefanov-87b8721b9/) · [GitHub](https://github.com/AlanStefanov) · [Email](mailto:alan.emanuel.stefanov@gmail.com)

</div>
