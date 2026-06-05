#!/usr/bin/env bash
# ============================================================
#  TOOLKIT DEV & DEVOPS — ECOSISTEMA .deb
#  Instalador interactivo para Ubuntu/Debian
#  Por Alan Stefanov
#  Repositorio: https://github.com/AlanStefanov/toolkit-dev-ubuntu
# ============================================================
#  Licencia MIT - Ver LICENSE para más detalles
# ============================================================

set -euo pipefail

VERSION="2.0.0"
LOG_FILE="/tmp/toolkit-install-$(date +%Y%m%d-%H%M%S).log"
INSTALLED=()
SKIPPED=()
FAILED=()
SUDO=""

# ─── Colores & estilos ──────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
M='\033[0;35m'
W='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'
BG_DARK='\033[48;5;235m'
BG_SEL='\033[48;5;24m'
BG_HEADER='\033[48;5;17m'
FG_MUTED='\033[38;5;244m'
FG_ACCENT='\033[38;5;39m'
FG_GREEN='\033[38;5;82m'
FG_YELLOW='\033[38;5;220m'
FG_RED='\033[38;5;196m'
FG_WHITE='\033[38;5;255m'

# ─── Logging ────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
info() { echo -e " ${FG_ACCENT}→${NC} $*"; }
ok()   { echo -e " ${FG_GREEN}✓${NC} $*"; }
warn() { echo -e " ${FG_YELLOW}⚠${NC}  $*"; }
err()  { echo -e " ${FG_RED}✗${NC} $*"; }

cleanup() {
    stty echo 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    rm -f /tmp/toolkit-*.deb /tmp/toolkit-*.zip /tmp/toolkit-*.tar.gz \
          /tmp/kubectl /tmp/lazygit.tar.gz /tmp/awscliv2.zip 2>/dev/null || true
    rm -rf /tmp/awscliv2 2>/dev/null || true
}
trap cleanup EXIT

# ─── Helpers de sistema ─────────────────────────────────────
ensure_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
        if ! sudo -n true 2>/dev/null; then
            echo -e "${Y}Se necesita sudo. Ingresá tu contraseña:${NC}"
            sudo -v
        fi
    fi
}

apt_install() {
    local pkg=$1
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
        return 0
    fi
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
}

is_cmd() {
    command -v "$1" &>/dev/null
}

pkg_installed() {
    dpkg -s "$1" &>/dev/null 2>&1
}

# install_step: ejecuta función, registra resultado
# No agrega a INSTALLED si ya estaba (la función retorna 0 sin hacer nada)
install_step() {
    local label=$1
    local func=$2
    shift 2

    # Guardar estado antes
    local before_count
    before_count=$(dpkg --get-selections 2>/dev/null | wc -l || echo 0)

    echo -ne "  ${FG_ACCENT}◆${NC} ${FG_WHITE}${label}${NC}${DIM}...${NC}"

    if $func "$@" >> "$LOG_FILE" 2>&1; then
        echo -e "\r  ${FG_GREEN}✔${NC} ${FG_WHITE}${label}${NC}$(printf '%*s' $((50 - ${#label})) '')${FG_GREEN}OK${NC}"
        log "OK: $label"
        INSTALLED+=("$label")
    else
        echo -e "\r  ${FG_RED}✘${NC} ${FG_WHITE}${label}${NC}$(printf '%*s' $((50 - ${#label})) '')${FG_RED}FALLÓ${NC}"
        log "FAIL: $label"
        FAILED+=("$label")
    fi
}

# ─── Instaladores ──────────────────────────────────────────
# Orden de dependencias:
#   1. Base: git, curl, wget, build-essential, make, gpg, unzip  (apt — siempre en repos)
#   2. Python, OpenSSH, tree, jq, htop, fzf, ripgrep, bat        (apt)
#   3. NVM + Node                                                  (curl | bash)
#   4. Docker                                                      (curl | sh oficial)
#   5. Todo lo que depende de Docker: Portainer, act
#   6. Herramientas con repo propio: VS Code, Sublime, DBeaver, GH CLI, Terraform, ngrok
#   7. Binarios directos: kubectl, k9s, lazygit, AWS CLI, Helm, mkcert
#   8. Instaladores remotos: Claude Code, OpenCode, Turso, Warp, Alacritty, Tmux
#   9. Shell: Zsh + Oh My Zsh
#  10. Postman (snap / flatpak), Gnome Dock, VLC, Neovim, direnv, sudoers

# ── Helpers de apt ──────────────────────────────────────────

# Asegura que gpg, curl, wget y unzip están disponibles antes de cualquier otra cosa
ensure_base_deps() {
    for pkg in curl wget gpg unzip ca-certificates apt-transport-https lsb-release software-properties-common; do
        dpkg -s "$pkg" &>/dev/null 2>&1 || \
            $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1 || true
    done
}

# Agrega repo con GPG key y lista apt, luego instala el paquete
add_apt_repo() {
    local key_url=$1      # URL de la GPG key
    local key_path=$2     # destino en /usr/share/keyrings/
    local repo_line=$3    # línea deb completa
    local list_file=$4    # nombre del archivo en /etc/apt/sources.list.d/
    local pkg=$5          # paquete a instalar

    # Descargar e instalar GPG key
    curl -fsSL "$key_url" | gpg --dearmor | $SUDO tee "$key_path" > /dev/null

    # Agregar repo
    echo "$repo_line" | $SUDO tee "/etc/apt/sources.list.d/${list_file}" > /dev/null

    # Update solo ese repo para ser rápido
    $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1

    # Instalar
    apt_install "$pkg"
}

# ── 1. Fundamentos (apt) ────────────────────────────────────

install_git_curl_wget() {
    apt_install git
    apt_install curl
    apt_install wget
}

install_build_essential() {
    apt_install build-essential
    apt_install gcc
    apt_install g++
}

install_make() {
    apt_install make
}

install_python() {
    apt_install python3
    apt_install python3-pip
    apt_install python3-venv
    apt_install python3-dev || true
}

install_openssh() {
    apt_install openssh-server
    $SUDO systemctl enable ssh 2>/dev/null \
        || $SUDO systemctl enable openssh-server 2>/dev/null || true
    $SUDO systemctl start ssh 2>/dev/null \
        || $SUDO systemctl start openssh-server 2>/dev/null || true
}

install_tree() {
    apt_install tree
}

install_jq() {
    is_cmd jq && { log "jq ya instalado"; return 0; }
    apt_install jq
}

install_htop() {
    is_cmd htop && { log "htop ya instalado"; return 0; }
    apt_install htop
}

install_fzf() {
    is_cmd fzf && { log "fzf ya instalado"; return 0; }
    apt_install fzf
}

install_ripgrep() {
    is_cmd rg && { log "ripgrep ya instalado"; return 0; }
    apt_install ripgrep
}

install_bat() {
    if is_cmd bat || is_cmd batcat; then
        log "bat ya instalado"
    else
        # En Ubuntu/Mint el paquete se llama 'bat' en 22.04+ y 'batcat' en anteriores
        apt_install bat 2>/dev/null || apt_install batcat 2>/dev/null || true
    fi
    # En Ubuntu bat se instala como batcat; crear symlink persistente
    if is_cmd batcat && ! is_cmd bat; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        # Agregar al PATH si no está
        local profile="$HOME/.bashrc"
        grep -q '\.local/bin' "$profile" 2>/dev/null \
            || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile"
    fi
}

install_tmux() {
    is_cmd tmux && { log "Tmux ya instalado"; return 0; }
    apt_install tmux
}

install_neovim() {
    is_cmd nvim && { log "Neovim ya instalado"; return 0; }
    # Intentar PPA oficial para versión más reciente que la de Ubuntu base
    if $SUDO add-apt-repository -y ppa:neovim-ppa/stable >> "$LOG_FILE" 2>&1; then
        $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1
    fi
    apt_install neovim
}

install_vlc() {
    is_cmd vlc && { log "VLC ya instalado"; return 0; }
    apt_install vlc
}

# ── 2. NVM + Node (script oficial, no apt) ──────────────────
# apt tiene versiones muy viejas de node; nvm es el método correcto

install_nvm_node() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

    if [[ -d "$NVM_DIR" ]]; then
        # shellcheck source=/dev/null
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if is_cmd node; then
            log "nvm + Node ya instalado ($(node --version))"
            return 0
        fi
    fi

    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install --lts >> "$LOG_FILE" 2>&1
    nvm use --lts     >> "$LOG_FILE" 2>&1
    nvm alias default 'lts/*' >> "$LOG_FILE" 2>&1
}

# ── 3. Docker (script oficial get.docker.com) ───────────────
# NO usar el docker de apt (docker.io) — es viejo y sin compose plugin

install_docker() {
    if is_cmd docker; then
        log "Docker ya instalado ($(docker --version 2>/dev/null))"
        local target_user="${SUDO_USER:-$USER}"
        [[ "$target_user" != "root" ]] && $SUDO usermod -aG docker "$target_user" 2>/dev/null || true
        $SUDO systemctl enable docker >> "$LOG_FILE" 2>&1 || true
        $SUDO systemctl start  docker >> "$LOG_FILE" 2>&1 || true
        return 0
    fi

    # Remover versiones viejas si existen
    for old in docker.io docker-doc docker-compose podman-docker containerd runc; do
        $SUDO apt-get remove -y "$old" >> "$LOG_FILE" 2>&1 || true
    done

    curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1

    local target_user="${SUDO_USER:-$USER}"
    [[ "$target_user" != "root" ]] && $SUDO usermod -aG docker "$target_user" 2>/dev/null || true

    $SUDO systemctl enable docker >> "$LOG_FILE" 2>&1
    $SUDO systemctl start  docker >> "$LOG_FILE" 2>&1

    # Compose plugin viene incluido con get.docker.com en versiones modernas
    # pero lo aseguramos por si acaso
    apt_install docker-compose-plugin 2>/dev/null || true
}

# ── 4. Portainer (depende de Docker) ────────────────────────

install_portainer() {
    if ! is_cmd docker; then
        log "Portainer requiere Docker — instalalo primero"
        return 1
    fi

    # Docker puede recién haber sido instalado; esperar que el daemon levante
    local retries=10
    while ! $SUDO docker info >> "$LOG_FILE" 2>&1; do
        (( retries-- )) || { log "Docker daemon no responde"; return 1; }
        sleep 2
    done

    if $SUDO docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
        log "Portainer ya instalado"
        return 0
    fi

    $SUDO docker volume create portainer_data >> "$LOG_FILE" 2>&1
    $SUDO docker run -d \
        --name portainer \
        --restart always \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest >> "$LOG_FILE" 2>&1
}

# ── 5. VS Code (repo Microsoft) ─────────────────────────────

install_vscode() {
    is_cmd code && { log "VS Code ya instalado"; return 0; }
    add_apt_repo \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "/usr/share/keyrings/packages.microsoft.gpg" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        "vscode.list" \
        "code"
}

# ── 6. Sublime Text (repo oficial) ──────────────────────────

install_sublime() {
    is_cmd subl && { log "Sublime ya instalado"; return 0; }
    add_apt_repo \
        "https://download.sublimetext.com/sublimehq-pub.gpg" \
        "/usr/share/keyrings/sublimehq.gpg" \
        "deb [signed-by=/usr/share/keyrings/sublimehq.gpg] https://download.sublimetext.com/ apt/stable/" \
        "sublime-text.list" \
        "sublime-text"
}

# ── 7. GitHub CLI (repo oficial) ────────────────────────────

install_gh() {
    is_cmd gh && { log "GitHub CLI ya instalado"; return 0; }
    add_apt_repo \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "/usr/share/keyrings/githubcli.gpg" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
        "github-cli.list" \
        "gh"
}

# ── 8. Terraform (repo HashiCorp) ───────────────────────────

install_terraform() {
    is_cmd terraform && { log "Terraform ya instalado"; return 0; }
    local codename
    codename=$(lsb_release -cs 2>/dev/null || echo "focal")
    add_apt_repo \
        "https://apt.releases.hashicorp.com/gpg" \
        "/usr/share/keyrings/hashicorp.gpg" \
        "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${codename} main" \
        "hashicorp.list" \
        "terraform"
}

# ── 9. DBeaver CE (repo oficial + Java) ─────────────────────

install_dbeaver() {
    is_cmd dbeaver && { log "DBeaver ya instalado"; return 0; }
    # DBeaver requiere Java
    apt_install default-jre
    add_apt_repo \
        "https://dbeaver.io/debs/dbeaver.gpg.key" \
        "/usr/share/keyrings/dbeaver.gpg" \
        "deb [signed-by=/usr/share/keyrings/dbeaver.gpg] https://dbeaver.io/debs/ /" \
        "dbeaver.list" \
        "dbeaver-ce"
}

install_db_clients() {
    apt_install postgresql-client
    apt_install sqlite3
    # mysql-client tiene distintos nombres según distro/versión
    apt_install mysql-client 2>/dev/null \
        || apt_install default-mysql-client 2>/dev/null \
        || apt_install mariadb-client 2>/dev/null || true
}

# ── 10. kubectl (binario oficial de k8s.io) ─────────────────
# NO usar el de snap (versión desactualizada) ni el de apt sin repo

install_kubectl() {
    is_cmd kubectl && { log "kubectl ya instalado"; return 0; }
    local ver
    ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl" -o /tmp/kubectl
    # Verificar checksum
    curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl.sha256" -o /tmp/kubectl.sha256
    echo "$(cat /tmp/kubectl.sha256) /tmp/kubectl" | sha256sum --check >> "$LOG_FILE" 2>&1
    $SUDO install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl /tmp/kubectl.sha256
}

# ── 11. Helm (script oficial) ────────────────────────────────

install_helm() {
    is_cmd helm && { log "Helm ya instalado"; return 0; }
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >> "$LOG_FILE" 2>&1
}

# ── 12. AWS CLI v2 (instalador oficial de Amazon) ───────────
# NO usar el de apt (es v1, obsoleto) ni el de pip

install_awscli() {
    if is_cmd aws && aws --version 2>&1 | grep -q "aws-cli/2"; then
        log "AWS CLI v2 ya instalado"
        return 0
    fi
    apt_install unzip  # dependencia del instalador
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -qo /tmp/awscliv2.zip -d /tmp/awscliv2
    $SUDO /tmp/awscliv2/aws/install --update >> "$LOG_FILE" 2>&1
    rm -rf /tmp/awscliv2 /tmp/awscliv2.zip
}

# ── 13. Lazygit (binario desde GitHub Releases) ─────────────

install_lazygit() {
    is_cmd lazygit && { log "lazygit ya instalado"; return 0; }
    local ver
    ver=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
          | grep -Po '"tag_name":\s*"v\K[^"]*' | head -1)
    if [[ -z "$ver" ]]; then
        log "No se pudo obtener versión de lazygit desde GitHub API"
        return 1
    fi
    curl -fsSLo /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_x86_64.tar.gz"
    $SUDO tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
    rm -f /tmp/lazygit.tar.gz
}

# ── 14. Alacritty (apt — disponible en Ubuntu 22.04+) ───────

install_alacritty() {
    is_cmd alacritty && { log "Alacritty ya instalado"; return 0; }
    # En Ubuntu < 22.04 no está en repos base; usar PPA
    if apt_install alacritty 2>/dev/null; then
        return 0
    fi
    # Fallback: PPA unofficial (Ubuntu < 22.04)
    $SUDO add-apt-repository -y ppa:aslatter/ppa >> "$LOG_FILE" 2>&1
    $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install alacritty
}

# ── 15. Warp Terminal (.deb directo desde releases.warp.dev) ─

install_warp() {
    is_cmd warp-terminal && { log "Warp ya instalado"; return 0; }
    local deb="/tmp/toolkit-warp.deb"
    curl -fsSL "https://releases.warp.dev/linux/stable/warp-terminal.deb" -o "$deb"
    # dpkg -i puede fallar por dependencias faltantes; apt-get install -f las resuelve
    $SUDO dpkg -i "$deb" >> "$LOG_FILE" 2>&1 || true
    $SUDO apt-get install -fy -qq >> "$LOG_FILE" 2>&1
    rm -f "$deb"
}

# ── 16. OpenCode (script oficial opencode.ai) ────────────────

install_opencode() {
    is_cmd opencode && { log "OpenCode ya instalado"; return 0; }
    # Requiere Node.js — verificar
    if ! is_cmd node; then
        log "OpenCode requiere Node.js — instalá NVM+Node primero"
        return 1
    fi
    curl -fsSL https://opencode.ai/install.sh | sh >> "$LOG_FILE" 2>&1
}

# ── 17. Turso CLI (script oficial turso.tech) ────────────────

install_turso() {
    is_cmd turso && { log "Turso ya instalado"; return 0; }
    curl -fsSL https://get.turso.tech/install.sh | sh >> "$LOG_FILE" 2>&1
}


# ── 17b. Claude Code (instalador nativo oficial Anthropic) ──
# Método recomendado: nativo sin dependencia de Node.js
# Fallback: npm global (requiere Node instalado)

install_claude_code() {
    is_cmd claude && { log "Claude Code ya instalado ($(claude --version 2>/dev/null || echo '?'))"; return 0; }

    # Método 1: instalador nativo (recomendado, sin deps)
    if curl -fsSL https://claude.ai/install.sh | sh >> "$LOG_FILE" 2>&1; then
        log "Claude Code instalado via nativo"
        return 0
    fi

    # Método 2: APT repo oficial (bueno para sistemas gestionados)
    log "Intentando via APT repo oficial..."
    $SUDO tee /etc/apt/sources.list.d/claude-code.sources > /dev/null << 'EOF'
Types: deb
URIs: https://downloads.claude.ai/claude-code/apt/latest
Suites: latest
Components: main
EOF
    curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
        | $SUDO tee /usr/share/keyrings/claude-code.asc > /dev/null
    $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1
    if apt_install claude-code; then
        log "Claude Code instalado via APT"
        return 0
    fi

    # Método 3: npm global (requiere Node)
    if is_cmd npm; then
        log "Intentando via npm..."
        npm install -g @anthropic-ai/claude-code >> "$LOG_FILE" 2>&1
        return $?
    fi

    log "No se pudo instalar Claude Code por ningún método"
    return 1
}

# ── 17c. Zsh + Oh My Zsh ─────────────────────────────────────
# Shell moderna con autocompletado, plugins y temas

install_zsh() {
    apt_install zsh

    # Cambiar shell por defecto al usuario actual
    local target_user="${SUDO_USER:-$USER}"
    local zsh_path
    zsh_path=$(command -v zsh)
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | $SUDO tee -a /etc/shells > /dev/null
    fi
    $SUDO chsh -s "$zsh_path" "$target_user" 2>/dev/null || true

    # Oh My Zsh (instalador oficial)
    local omz_dir="${HOME}/.oh-my-zsh"
    if [[ ! -d "$omz_dir" ]]; then
        RUNZSH=no CHSH=no \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            >> "$LOG_FILE" 2>&1
    else
        log "Oh My Zsh ya instalado"
    fi

    # Plugin: zsh-autosuggestions
    local plugin_dir="${omz_dir}/custom/plugins/zsh-autosuggestions"
    [[ -d "$plugin_dir" ]] || \
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir" >> "$LOG_FILE" 2>&1 || true

    # Plugin: zsh-syntax-highlighting
    local hl_dir="${omz_dir}/custom/plugins/zsh-syntax-highlighting"
    [[ -d "$hl_dir" ]] || \
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$hl_dir" >> "$LOG_FILE" 2>&1 || true
}

# ── 17d. direnv (carga .envrc por directorio) ────────────────
# Esencial para manejar variables de entorno por proyecto

install_direnv() {
    is_cmd direnv && { log "direnv ya instalado"; return 0; }
    apt_install direnv

    # Hook automático para bash y zsh
    local bashrc="$HOME/.bashrc"
    grep -q 'direnv hook bash' "$bashrc" 2>/dev/null \
        || echo 'eval "$(direnv hook bash)"' >> "$bashrc"

    local zshrc="$HOME/.zshrc"
    [[ -f "$zshrc" ]] && {
        grep -q 'direnv hook zsh' "$zshrc" 2>/dev/null \
            || echo 'eval "$(direnv hook zsh)"' >> "$zshrc"
    }
}

# ── 17e. mkcert (certificados SSL locales) ───────────────────
# Genera certificados HTTPS para localhost sin warnings en el browser

install_mkcert() {
    is_cmd mkcert && { log "mkcert ya instalado"; return 0; }
    apt_install libnss3-tools  # necesario para instalar en el browser

    local ver
    ver=$(curl -fsSL "https://api.github.com/repos/FiloSottile/mkcert/releases/latest" \
          | grep -Po '"tag_name":\s*"v\K[^"]*' | head -1)
    if [[ -z "$ver" ]]; then
        log "No se pudo obtener versión de mkcert"
        return 1
    fi
    curl -fsSLo /tmp/mkcert \
        "https://github.com/FiloSottile/mkcert/releases/download/v${ver}/mkcert-v${ver}-linux-amd64"
    $SUDO install -o root -g root -m 0755 /tmp/mkcert /usr/local/bin/mkcert
    rm -f /tmp/mkcert

    # Instalar CA local
    mkcert -install >> "$LOG_FILE" 2>&1 || true
}

# ── 17f. act (corre GitHub Actions localmente) ───────────────
# Requiere Docker

install_act() {
    is_cmd act && { log "act ya instalado"; return 0; }
    if ! is_cmd docker; then
        log "act requiere Docker — instalalo primero"
        return 1
    fi
    curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh \
        | $SUDO bash >> "$LOG_FILE" 2>&1
}

# ── 17g. k9s (TUI para Kubernetes) ───────────────────────────
# Requiere kubectl configurado

install_k9s() {
    is_cmd k9s && { log "k9s ya instalado"; return 0; }
    local ver
    ver=$(curl -fsSL "https://api.github.com/repos/derailed/k9s/releases/latest" \
          | grep -Po '"tag_name":\s*"v\K[^"]*' | head -1)
    if [[ -z "$ver" ]]; then
        log "No se pudo obtener versión de k9s"
        return 1
    fi
    curl -fsSLo /tmp/k9s.tar.gz \
        "https://github.com/derailed/k9s/releases/download/v${ver}/k9s_Linux_amd64.tar.gz"
    $SUDO tar xf /tmp/k9s.tar.gz -C /usr/local/bin k9s
    rm -f /tmp/k9s.tar.gz
}

# ── 17h. ngrok (túneles HTTP para localhost) ─────────────────
# Expone puertos locales a internet — útil para webhooks y demos

install_ngrok() {
    is_cmd ngrok && { log "ngrok ya instalado"; return 0; }
    curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
        | gpg --dearmor \
        | $SUDO tee /usr/share/keyrings/ngrok.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" \
        | $SUDO tee /etc/apt/sources.list.d/ngrok.list > /dev/null
    $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install ngrok
}

# ── 18. Postman (snap preferido; flatpak como fallback) ──────

install_postman() {
    is_cmd postman && { log "Postman ya instalado"; return 0; }
    if is_cmd snap; then
        $SUDO snap install postman >> "$LOG_FILE" 2>&1 && return 0
    fi
    # Fallback: Flatpak
    apt_install flatpak
    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo >> "$LOG_FILE" 2>&1 || true
    flatpak install -y --noninteractive flathub com.getpostman.Postman >> "$LOG_FILE" 2>&1
}

# ── 19. Gnome Dash to Dock ───────────────────────────────────

install_gnome_dock() {
    apt_install gnome-shell-extension-dash-to-dock
    if is_cmd gnome-extensions; then
        gnome-extensions enable dash-to-dock@micxgx.gmail.com >> "$LOG_FILE" 2>&1 || true
    fi
}

# ── 20. Sudoers sin contraseña ───────────────────────────────

install_sudoers() {
    local target_user="${SUDO_USER:-$USER}"
    [[ "$target_user" == "root" ]] && { log "Usuario root, omitiendo sudoers"; return 0; }
    local sudoers_file="/etc/sudoers.d/${target_user}"
    if [[ -f "$sudoers_file" ]]; then
        log "sudoers ya configurado para $target_user"
        return 0
    fi
    echo "${target_user} ALL=(ALL) NOPASSWD:ALL" | $SUDO tee "$sudoers_file" > /dev/null
    $SUDO chmod 0440 "$sudoers_file"
    # Validar antes de dejar el archivo
    $SUDO visudo -c -f "$sudoers_file" >> "$LOG_FILE" 2>&1 || {
        $SUDO rm -f "$sudoers_file"
        log "visudo rechazó el archivo sudoers — revertido"
        return 1
    }
}

# ── 21. SDKMAN! + JDK (gestor de JDKs, Maven, Gradle) ────────
# SDKMAN! es el equivalente a nvm para el ecosistema Java

install_sdkman_jdk() {
    local sdkman_dir="${SDKMAN_DIR:-$HOME/.sdkman}"

    if [[ ! -d "$sdkman_dir" ]]; then
        curl -fsSL "https://get.sdkman.io" | bash >> "$LOG_FILE" 2>&1
    fi

    # Sourced en una subshell para que sdk esté disponible
    source "$sdkman_dir/bin/sdkman-init.sh" 2>/dev/null || true

    if ! command -v sdk &>/dev/null; then
        log "SDKMAN! no se pudo instalar"
        return 1
    fi

    # Instalar JDK 21 (última LTS) vía Temurin
    if ! sdk list java 2>/dev/null | grep -q "21.*installed"; then
        sdk install java 21.0.1-tem >> "$LOG_FILE" 2>&1 || \
        sdk install java 17.0.9-tem >> "$LOG_FILE" 2>&1 || true
    fi
}

# ── 22. Go (golang.org) ───────────────────────────────────────
# Compilador oficial desde go.dev

install_go() {
    is_cmd go && { log "Go ya instalado"; return 0; }

    local ver
    ver=$(curl -fsSL https://go.dev/VERSION?m=text 2>/dev/null | head -1)
    [[ -z "$ver" ]] && ver="go1.23.0"

    curl -fsSL "https://go.dev/dl/${ver}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz

    # Agregar al PATH
    local bashrc="$HOME/.bashrc"
    grep -q '/usr/local/go/bin' "$bashrc" 2>/dev/null \
        || echo 'export PATH="$PATH:/usr/local/go/bin"' >> "$bashrc"
}

# ── 23. Rust (rustup.rs) ──────────────────────────────────────
# Instalador oficial con rustup

install_rust() {
    is_cmd rustc && { log "Rust ya instalado"; return 0; }
    curl -fsSL https://sh.rustup.rs | sh -s -- -y >> "$LOG_FILE" 2>&1
}

# ── 24. eza (ls moderno con colores y git) ────────────────────
# Reemplazo de ls con soporte para icons, colores y git status

install_eza() {
    is_cmd eza && { log "eza ya instalado"; return 0; }
    apt_install eza 2>/dev/null || {
        # Fallback: cargo (requiere Rust)
        if is_cmd cargo; then
            cargo install eza >> "$LOG_FILE" 2>&1
        fi
    } || true
}

# ── 25. zoxide (cd inteligente) ───────────────────────────────
# Aprende qué directorios visitás y te lleva con pocas teclas

install_zoxide() {
    is_cmd zoxide && { log "zoxide ya instalado"; return 0; }
    curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >> "$LOG_FILE" 2>&1

    # Hook para bash
    local bashrc="$HOME/.bashrc"
    grep -q 'zoxide init' "$bashrc" 2>/dev/null \
        || echo 'eval "$(zoxide init bash)"' >> "$bashrc"
}

# ── 26. fd (find rápido) ──────────────────────────────────────
# Alternativa moderna a find con sintaxis intuitiva

install_fd() {
    is_cmd fd && { log "fd ya instalado"; return 0; }
    apt_install fd-find 2>/dev/null || {
        if is_cmd cargo; then
            cargo install fd-find >> "$LOG_FILE" 2>&1
        fi
    } || true
    # En Ubuntu el binario se llama fdfind; crear symlink
    if is_cmd fdfind && ! is_cmd fd; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
}

# ── 27. Yarn (gestor de paquetes Node) ────────────────────────
# Alternativa rápida y determinista a npm

install_yarn() {
    is_cmd yarn && { log "Yarn ya instalado"; return 0; }
    if ! is_cmd npm; then
        log "Yarn requiere Node.js + npm — instalá NVM+Node primero"
        return 1
    fi
    npm install -g yarn >> "$LOG_FILE" 2>&1
}

# ── 28. Ansible (automatización devops) ───────────────────────
# Aprovisionamiento, configuración y orquestación

install_ansible() {
    is_cmd ansible && { log "Ansible ya instalado"; return 0; }
    apt_install ansible
}

# ── 29. ESLint (linting JS/TS) ────────────────────────────────
# Analizador estático de código JavaScript/TypeScript

install_eslint() {
    is_cmd eslint && { log "ESLint ya instalado"; return 0; }
    if ! is_cmd npm; then
        log "ESLint requiere Node.js + npm"
        return 1
    fi
    npm install -g eslint >> "$LOG_FILE" 2>&1
}

# ── 30. MongoDB Compass (GUI MongoDB) ────────────────────────
# Interfaz gráfica oficial para MongoDB

install_compass() {
    is_cmd mongodb-compass && { log "MongoDB Compass ya instalado"; return 0; }
    local deb="/tmp/mongodb-compass.deb"
    curl -fsSLo "$deb" "https://downloads.mongodb.com/compass/mongodb-compass_latest_amd64.deb" || {
        log "No se pudo descargar MongoDB Compass"
        return 1
    }
    $SUDO dpkg -i "$deb" >> "$LOG_FILE" 2>&1 || true
    $SUDO apt-get install -fy -qq >> "$LOG_FILE" 2>&1
    rm -f "$deb"
}

# ── 31. Redis Server + CLI ────────────────────────────────────
# Base de datos en memoria, clave-valor, con redis-cli

install_redis() {
    is_cmd redis-server && { log "Redis ya instalado"; return 0; }
    apt_install redis-server
    $SUDO systemctl enable redis-server >> "$LOG_FILE" 2>&1 || true
    $SUDO systemctl start redis-server >> "$LOG_FILE" 2>&1 || true
}

# ── 32. Redis Insight (GUI oficial de Redis) ─────────────────
# Navegador visual y administrador de Redis

install_redis_insight() {
    is_cmd redis-insight && { log "Redis Insight ya instalado"; return 0; }
    local deb="/tmp/redis-insight.deb"
    curl -fsSLo "$deb" "https://s3.amazonaws.com/redis-insight/download/latest/redis-insight-linux-amd64.deb" || {
        log "No se pudo descargar Redis Insight"
        return 1
    }
    $SUDO dpkg -i "$deb" >> "$LOG_FILE" 2>&1 || true
    $SUDO apt-get install -fy -qq >> "$LOG_FILE" 2>&1
    rm -f "$deb"
}

# ─── TUI Custom ─────────────────────────────────────────────

# Definición de herramientas: "KEY|Nombre para mostrar|Descripción|on/off"
declare -A TOOL_FUNC=(
    [VS_Code]="install_vscode"
    [Sublime_Text]="install_sublime"
    [Neovim]="install_neovim"
    [OpenCode]="install_opencode"
    [Alacritty]="install_alacritty"
    [Warp]="install_warp"
    [Tmux]="install_tmux"
    [DBeaver]="install_dbeaver"
    [DB_Clients]="install_db_clients"
    [Turso_CLI]="install_turso"
    [AWS_CLI]="install_awscli"
    [GH_CLI]="install_gh"
    [Kubectl]="install_kubectl"
    [Helm]="install_helm"
    [Terraform]="install_terraform"
    [Docker]="install_docker"
    [Portainer]="install_portainer"
    [NVM_Node]="install_nvm_node"
    [Python]="install_python"
    [Build_Essential]="install_build_essential"
    [Git_Curl_Wget]="install_git_curl_wget"
    [Make]="install_make"
    [OpenSSH]="install_openssh"
    [Tree]="install_tree"
    [JQ]="install_jq"
    [Htop]="install_htop"
    [FZF]="install_fzf"
    [Ripgrep]="install_ripgrep"
    [Bat]="install_bat"
    [Lazygit]="install_lazygit"
    [Postman]="install_postman"
    [Gnome_Dock]="install_gnome_dock"
    [Sudoers]="install_sudoers"
    [VLC]="install_vlc"
    [Claude_Code]="install_claude_code"
    [Zsh_OhMyZsh]="install_zsh"
    [Direnv]="install_direnv"
    [Mkcert]="install_mkcert"
    [Act]="install_act"
    [K9s]="install_k9s"
    [Ngrok]="install_ngrok"
    [SDKMAN_JDK]="install_sdkman_jdk"
    [Go]="install_go"
    [Rust]="install_rust"
    [Eza]="install_eza"
    [Zoxide]="install_zoxide"
    [Fd]="install_fd"
    [Yarn]="install_yarn"
    [Ansible]="install_ansible"
    [ESLint]="install_eslint"
    [Compass]="install_compass"
    [Redis]="install_redis"
    [Redis_Insight]="install_redis_insight"
)

# Categorías en ORDEN DE DEPENDENCIAS (así se instalan)
# El menú las muestra en este mismo orden.
CATEGORIES=(
    "BASE DEL SISTEMA"
    "NODE / PYTHON"
    "LENGUAJES / RUNTIMES"
    "CONTENEDORES"
    "EDITORES / IDE"
    "IA EN EL TERMINAL"
    "BASES DE DATOS"
    "CLOUD / INFRA"
    "KUBERNETES"
    "DEV LOCAL"
    "TERMINALES"
    "CLI POWER-UPS"
    "API CLIENT"
    "SISTEMA / UI"
)

declare -A CAT_TOOLS=(
    # 1. Fundamentos: sin estos muchos instaladores fallan
    ["BASE DEL SISTEMA"]="Git_Curl_Wget Build_Essential Make OpenSSH Tree"
    # 2. Runtimes: nvm/node antes que OpenCode; python independiente
    ["NODE / PYTHON"]="NVM_Node Python Yarn ESLint"
    # 3. Lenguajes: SDKMAN (Java) + Go + Rust — sin dependencias entre sí
    ["LENGUAJES / RUNTIMES"]="SDKMAN_JDK Go Rust"
    # 4. Docker primero, luego Portainer y act que lo necesitan
    ["CONTENEDORES"]="Docker Portainer Act"
    # 4. Editores: OpenCode requiere Node (ya instalado)
    ["EDITORES / IDE"]="VS_Code Sublime_Text Neovim OpenCode"
    # 5. IA CLI: Claude Code y OpenCode van juntos
    ["IA EN EL TERMINAL"]="Claude_Code"
    # 6. BD: DBeaver requiere Java; clientes son puro apt
    ["BASES DE DATOS"]="DBeaver DB_Clients Turso_CLI Compass Redis Redis_Insight"
    # 7. Cloud/infra: todos con repos propios o binarios
    ["CLOUD / INFRA"]="AWS_CLI GH_CLI Helm Terraform Ngrok Ansible"
    # 8. Kubernetes: kubectl primero, luego k9s que lo usa
    ["KUBERNETES"]="Kubectl K9s"
    # 9. Dev local: herramientas de entorno de desarrollo
    ["DEV LOCAL"]="Direnv Mkcert Zsh_OhMyZsh"
    # 10. Terminales
    ["TERMINALES"]="Alacritty Warp Tmux"
    # 11. CLI tools: puros apt o binarios, sin dependencias cruzadas
    ["CLI POWER-UPS"]="JQ Htop FZF Ripgrep Bat Lazygit Eza Zoxide Fd"
    # 12. API client
    ["API CLIENT"]="Postman"
    # 13. Sistema/UI: lo último, puede requerir sesión gráfica activa
    ["SISTEMA / UI"]="Gnome_Dock VLC Sudoers"
)

declare -A TOOL_LABEL=(
    [VS_Code]="Visual Studio Code"
    [Sublime_Text]="Sublime Text 4"
    [Neovim]="Neovim"
    [OpenCode]="OpenCode (CLI IA)"
    [Alacritty]="Alacritty (GPU)"
    [Warp]="Warp Terminal"
    [Tmux]="Tmux"
    [DBeaver]="DBeaver CE"
    [DB_Clients]="psql + sqlite3 + mysql"
    [Turso_CLI]="Turso CLI"
    [AWS_CLI]="AWS CLI v2"
    [GH_CLI]="GitHub CLI (gh)"
    [Kubectl]="kubectl"
    [Helm]="Helm"
    [Terraform]="Terraform"
    [Docker]="Docker + Compose"
    [Portainer]="Portainer (GUI Docker)"
    [NVM_Node]="nvm + Node.js LTS"
    [Python]="Python3 pip + venv"
    [Build_Essential]="build-essential"
    [Git_Curl_Wget]="git + curl + wget"
    [Make]="GNU Make"
    [OpenSSH]="OpenSSH Server"
    [Tree]="tree"
    [JQ]="jq"
    [Htop]="htop"
    [FZF]="fzf"
    [Ripgrep]="ripgrep (rg)"
    [Bat]="bat (cat con colores)"
    [Lazygit]="lazygit"
    [Postman]="Postman"
    [Gnome_Dock]="Dash to Dock"
    [Sudoers]="sudo sin contraseña"
    [VLC]="VLC Media Player"
    [Claude_Code]="Claude Code CLI"
    [Zsh_OhMyZsh]="Zsh + Oh My Zsh"
    [Direnv]="direnv"
    [Mkcert]="mkcert"
    [Act]="act"
    [K9s]="k9s"
    [Ngrok]="ngrok"
    [SDKMAN_JDK]="SDKMAN! + JDK 21"
    [Go]="Go"
    [Rust]="Rust"
    [Eza]="eza (ls moderno)"
    [Zoxide]="zoxide (cd inteligente)"
    [Fd]="fd (find rápido)"
    [Yarn]="Yarn"
    [Ansible]="Ansible"
    [ESLint]="ESLint"
    [Compass]="MongoDB Compass"
    [Redis]="Redis Server + CLI"
    [Redis_Insight]="Redis Insight (GUI)"
)

declare -A TOOL_DESC=(
    [VS_Code]="Editor Microsoft con extensiones"
    [Sublime_Text]="Editor rápido y liviano"
    [Neovim]="Editor modal moderno en CLI"
    [OpenCode]="Agente de IA para tu código"
    [Alacritty]="Terminal acelerada por GPU"
    [Warp]="Terminal moderna con IA integrada"
    [Tmux]="Multiplexor de sesiones"
    [DBeaver]="Gestor universal de bases de datos"
    [DB_Clients]="Clientes CLI para postgres/sqlite/mysql"
    [Turso_CLI]="BD SQLite distribuida en el edge"
    [AWS_CLI]="Manejo de servicios AWS desde CLI"
    [GH_CLI]="GitHub desde la terminal"
    [Kubectl]="CLI para clústeres Kubernetes"
    [Helm]="Package manager para Kubernetes"
    [Terraform]="Infraestructura como código (IaC)"
    [Docker]="Contenedores + Docker Compose"
    [Portainer]="Panel web para gestionar Docker"
    [NVM_Node]="Gestor de versiones de Node.js"
    [Python]="Entorno Python con pip y venv"
    [Build_Essential]="GCC, G++, Make y más"
    [Git_Curl_Wget]="Control de versiones y descarga"
    [Make]="Automatización de builds"
    [OpenSSH]="Servidor SSH habilitado"
    [Tree]="Visualización de directorios"
    [JQ]="Procesador JSON en terminal"
    [Htop]="Monitor de procesos interactivo"
    [FZF]="Búsqueda fuzzy para CLI"
    [Ripgrep]="grep ultra-rápido (rg)"
    [Bat]="cat con syntax highlighting"
    [Lazygit]="Git con UI interactiva en terminal"
    [Postman]="Cliente visual para APIs REST"
    [Gnome_Dock]="Dock estilo macOS para GNOME"
    [Sudoers]="sudo sin pedir contraseña"
    [VLC]="Reproductor multimedia universal"
    [Claude_Code]="Asistente IA de Anthropic en terminal"
    [Zsh_OhMyZsh]="Shell moderna + plugins + autosuggestions"
    [Direnv]="Variables de entorno por directorio (.envrc)"
    [Mkcert]="Certificados HTTPS locales sin warnings"
    [Act]="Corre GitHub Actions en tu máquina local"
    [K9s]="TUI interactiva para gestionar Kubernetes"
    [Ngrok]="Túnel HTTP para exponer localhost a internet"
    [SDKMAN_JDK]="Gestor de JDKs + Java 21 LTS"
    [Go]="Compilador y herramientas Go"
    [Rust]="Compilador rustc + cargo + rustup"
    [Eza]="ls con colores, icons y git status"
    [Zoxide]="Navegación inteligente de directorios"
    [Fd]="find rápido con sintaxis intuitiva"
    [Yarn]="Gestor de paquetes Node.js rápido"
    [Ansible]="Automatización y configuración devops"
    [ESLint]="Linter para JavaScript/TypeScript"
    [Compass]="GUI oficial para MongoDB"
    [Redis]="Base de datos en memoria clave-valor"
    [Redis_Insight]="GUI oficial para administrar Redis"
)

# Estado inicial: todos ON
declare -A TOOL_SEL
for key in "${!TOOL_LABEL[@]}"; do
    TOOL_SEL[$key]=1
done

# ─── TUI interactivo ────────────────────────────────────────

TERM_COLS=$(tput cols 2>/dev/null || echo 80)
TERM_ROWS=$(tput lines 2>/dev/null || echo 24)

# Construir lista plana de items (categorías + herramientas)
build_flat_list() {
    FLAT_ITEMS=()
    FLAT_TYPES=()  # "cat" o "tool"
    for cat in "${CATEGORIES[@]}"; do
        FLAT_ITEMS+=("$cat")
        FLAT_TYPES+=("cat")
        read -ra tools <<< "${CAT_TOOLS[$cat]}"
        for tool in "${tools[@]}"; do
            FLAT_ITEMS+=("$tool")
            FLAT_TYPES+=("tool")
        done
    done
}

print_header() {
    local box_w=58
    echo -e "${FG_ACCENT}"
    echo "  ╔$(printf '═%.0s' $(seq 1 $box_w))╗"
    local line1="  TOOLKIT DEV & DEVOPS — v${VERSION}  "
    local line2="       por Alan Stefanov              "
    printf "  ║%*s%s%*s║\n" $(( (box_w - ${#line1}) / 2 )) "" "$line1" $(( box_w - ${#line1} - (box_w - ${#line1}) / 2 )) ""
    printf "  ║%*s%s%*s║\n" $(( (box_w - ${#line2}) / 2 )) "" "$line2" $(( box_w - ${#line2} - (box_w - ${#line2}) / 2 )) ""
    echo "  ╚$(printf '═%.0s' $(seq 1 $box_w))╝"
    echo -e "${NC}"
}

pad_right() {
    local str="$1"
    local width=$2
    local len=${#str}
    local pad=$(( width - len ))
    [[ $pad -lt 0 ]] && pad=0
    printf '%s%*s' "$str" "$pad" ""
}

draw_menu() {
    local cursor=$1
    local scroll_offset=$2
    local visible_rows=$(( TERM_ROWS - 14 ))
    [[ $visible_rows -lt 5 ]] && visible_rows=5

    clear

    print_header

    # Leyenda de controles
    echo -e "  ${FG_MUTED}↑↓ Mover   ESPACIO Marcar/desmarcar   A Todos   N Ninguno   ENTER Instalar   Q Salir${NC}"
    echo -e "  ${FG_MUTED}$(printf '─%.0s' $(seq 1 $(( TERM_COLS - 4 ))))${NC}"
    echo ""

    local total=${#FLAT_ITEMS[@]}
    local shown=0
    local desc_width=$(( TERM_COLS - 46 ))
    [[ $desc_width -lt 10 ]] && desc_width=10

    for (( i=scroll_offset; i<total && shown<visible_rows; i++ )); do
        local item="${FLAT_ITEMS[$i]}"
        local type="${FLAT_TYPES[$i]}"
        local is_cursor=0
        [[ $i -eq $cursor ]] && is_cursor=1

        if [[ "$type" == "cat" ]]; then
            read -ra cat_tools <<< "${CAT_TOOLS[$item]}"
            local sel_count=0
            for t in "${cat_tools[@]}"; do
                [[ "${TOOL_SEL[$t]}" -eq 1 ]] && (( sel_count++ )) || true
            done
            local total_count=${#cat_tools[@]}
            local counter="${sel_count}/${total_count}"
            local label_padded
            label_padded=$(pad_right "$item" 36)

            if [[ $is_cursor -eq 1 ]]; then
                echo -e "  ${BG_SEL}${FG_WHITE}${BOLD} ▸ ${label_padded}  ${counter} ${NC}"
            else
                echo -e "  ${FG_YELLOW}${BOLD} ▸ ${label_padded}  ${counter}${NC}"
            fi
        else
            local label="${TOOL_LABEL[$item]}"
            local desc="${TOOL_DESC[$item]}"
            local sel="${TOOL_SEL[$item]}"
            local checkbox chk_col
            local label_padded
            label_padded=$(pad_right "$label" 28)
            local desc_cut="${desc:0:$desc_width}"

            if [[ $sel -eq 1 ]]; then
                checkbox="◉"
                chk_col="${FG_GREEN}"
            else
                checkbox="○"
                chk_col="${FG_MUTED}"
            fi

            if [[ $is_cursor -eq 1 ]]; then
                echo -e "  ${BG_SEL}${FG_WHITE}  ${chk_col}${checkbox}${FG_WHITE}${BOLD} ${label_padded}${NC}${BG_SEL}${FG_MUTED}  ${desc_cut}${NC}"
            else
                echo -e "    ${chk_col}${checkbox}${NC} ${label_padded}${FG_MUTED}  ${desc_cut}${NC}"
            fi
        fi
        (( shown++ )) || true
    done

    echo ""
    local total_tools=0
    local sel_tools=0
    for key in "${!TOOL_LABEL[@]}"; do
        (( total_tools++ )) || true
        [[ "${TOOL_SEL[$key]}" -eq 1 ]] && (( sel_tools++ )) || true
    done

    echo -e "  ${FG_MUTED}$(printf '─%.0s' $(seq 1 $(( TERM_COLS - 4 ))))${NC}"
    echo -e "  ${FG_ACCENT}${BOLD}${sel_tools}${NC}${FG_ACCENT} herramientas seleccionadas de ${total_tools}${NC}"
}

toggle_category() {
    local cat_name=$1
    read -ra tools <<< "${CAT_TOOLS[$cat_name]}"
    # Si todos están on → apagar; si alguno está off → encender todos
    local all_on=1
    for t in "${tools[@]}"; do
        [[ "${TOOL_SEL[$t]}" -eq 0 ]] && all_on=0 && break
    done
    for t in "${tools[@]}"; do
        if [[ $all_on -eq 1 ]]; then
            TOOL_SEL[$t]=0
        else
            TOOL_SEL[$t]=1
        fi
    done
}

run_interactive_menu() {
    build_flat_list
    local cursor=1  # Empezar en la primera herramienta (no categoría)
    local scroll=0
    local visible_rows=$(( TERM_ROWS - 14 ))
    [[ $visible_rows -lt 5 ]] && visible_rows=5

    tput civis  # ocultar cursor
    stty -echo  # desactivar echo a nivel driver

    while true; do
        draw_menu "$cursor" "$scroll"

        # Leer tecla
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2 || true
            key="${key}${key2}"
        fi

        local total=${#FLAT_ITEMS[@]}

        case "$key" in
            $'\x1b[A'|k)  # Arriba
                (( cursor-- )) || true
                [[ $cursor -lt 0 ]] && cursor=$(( total - 1 ))
                [[ $cursor -lt $scroll ]] && scroll=$cursor
                ;;
            $'\x1b[B'|j)  # Abajo
                (( cursor++ )) || true
                [[ $cursor -ge $total ]] && cursor=0
                [[ $cursor -ge $(( scroll + visible_rows )) ]] && (( scroll++ )) || true
                [[ $cursor -lt $scroll ]] && scroll=0
                ;;
            ' ')  # Espacio: toggle
                local item="${FLAT_ITEMS[$cursor]}"
                local type="${FLAT_TYPES[$cursor]}"
                if [[ "$type" == "cat" ]]; then
                    toggle_category "$item"
                else
                    if [[ "${TOOL_SEL[$item]}" -eq 1 ]]; then
                        TOOL_SEL[$item]=0
                    else
                        TOOL_SEL[$item]=1
                    fi
                fi
                ;;
            a|A)  # Todos
                for key2 in "${!TOOL_LABEL[@]}"; do TOOL_SEL[$key2]=1; done
                ;;
            n|N)  # Ninguno
                for key2 in "${!TOOL_LABEL[@]}"; do TOOL_SEL[$key2]=0; done
                ;;
            '')  # Enter
                stty echo
                tput cnorm
                return 0
                ;;
            q|Q)
                stty echo
                tput cnorm
                clear
                echo -e "${Y}Instalación cancelada.${NC}"
                exit 0
                ;;
        esac

        [[ $scroll -lt 0 ]] && scroll=0
        [[ $cursor -lt $scroll ]] && scroll=$cursor
        [[ $cursor -ge $(( scroll + visible_rows )) ]] && scroll=$(( cursor - visible_rows + 1 ))
    done
}

# ─── Instalación ────────────────────────────────────────────

run_installation() {
    clear
    print_header

    # ── apt update (antes que nada para que los installs funcionen) ──
    echo -ne "  ${FG_ACCENT}◆${NC} ${FG_WHITE}Actualizando lista de paquetes${NC}${DIM}...${NC}"
    if $SUDO apt-get update -qq >> "$LOG_FILE" 2>&1; then
        echo -e "\r  ${FG_GREEN}✔${NC} ${FG_WHITE}Lista de paquetes actualizada${NC}$(printf '%*s' 22 '')${FG_GREEN}OK${NC}"
        log "apt-get update OK"
    else
        echo -e "\r  ${FG_RED}✘${NC} ${FG_WHITE}apt-get update falló${NC} — continuando igual..."
        log "apt-get update FALLÓ"
    fi

    # ── dependencias base (curl, gpg, unzip, etc.) ─────────
    echo -ne "  ${FG_ACCENT}◆${NC} ${FG_WHITE}Instalando dependencias base${NC}${DIM}...${NC}"
    ensure_base_deps
    echo -e "
  ${FG_GREEN}✔${NC} ${FG_WHITE}Dependencias base listas${NC}$(printf '%*s' 29 '')${FG_GREEN}OK${NC}"

    # ── apt upgrade ─────────────────────────────────────────
    echo -ne "  ${FG_ACCENT}◆${NC} ${FG_WHITE}Actualizando paquetes del sistema${NC}${DIM}...${NC}"
    if $SUDO DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            >> "$LOG_FILE" 2>&1; then
        echo -e "\r  ${FG_GREEN}✔${NC} ${FG_WHITE}Sistema actualizado${NC}$(printf '%*s' 35 '')${FG_GREEN}OK${NC}"
        log "apt-get upgrade OK"
    else
        echo -e "\r  ${FG_YELLOW}⚠${NC}  ${FG_WHITE}apt-get upgrade con advertencias${NC} — revisá el log si algo falla"
        log "apt-get upgrade con errores/advertencias"
    fi

    echo ""

    local selected=()
    for key in "${!TOOL_SEL[@]}"; do
        [[ "${TOOL_SEL[$key]}" -eq 1 ]] && selected+=("$key")
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        warn "No seleccionaste ninguna herramienta."
        exit 0
    fi

    # Ordenar según orden original
    local ordered=()
    for cat in "${CATEGORIES[@]}"; do
        read -ra tools <<< "${CAT_TOOLS[$cat]}"
        for tool in "${tools[@]}"; do
            for sel in "${selected[@]}"; do
                [[ "$sel" == "$tool" ]] && ordered+=("$tool") && break
            done
        done
    done

    local total=${#ordered[@]}
    local current=0

    echo -e "  ${FG_WHITE}${BOLD}Instalando ${total} herramientas${NC}"
    echo -e "  ${FG_MUTED}$(printf '─%.0s' $(seq 1 58))${NC}"
    echo ""

    for tool in "${ordered[@]}"; do
        (( current++ )) || true
        local label="${TOOL_LABEL[$tool]}"
        local func="${TOOL_FUNC[$tool]}"

        # Progress indicator
        local pct=$(( current * 100 / total ))
        echo -ne "  ${FG_MUTED}[$(printf "%3d" "$pct")%]${NC} "

        install_step "$label" "$func"
    done
}

show_summary() {
    echo ""
    echo -e "  ${FG_ACCENT}$(printf '═%.0s' $(seq 1 60))${NC}"
    echo -e "  ${FG_WHITE}${BOLD}  RESUMEN DE INSTALACIÓN${NC}"
    echo -e "  ${FG_ACCENT}$(printf '═%.0s' $(seq 1 60))${NC}"
    echo ""

    if [[ ${#INSTALLED[@]} -gt 0 ]]; then
        echo -e "  ${FG_GREEN}✔  Instaladas correctamente (${#INSTALLED[@]}):${NC}"
        for item in "${INSTALLED[@]}"; do
            echo -e "    ${FG_MUTED}·${NC} $item"
        done
        echo ""
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "  ${FG_RED}✘  Fallaron (${#FAILED[@]}):${NC}"
        for item in "${FAILED[@]}"; do
            echo -e "    ${FG_MUTED}·${NC} $item"
        done
        echo ""
        echo -e "  ${FG_YELLOW}→  Revisá el log para más detalles:${NC}"
        echo -e "     ${BOLD}$LOG_FILE${NC}"
        echo ""
    fi

    echo -e "  ${FG_ACCENT}$(printf '─%.0s' $(seq 1 60))${NC}"
    echo ""
    echo -e "  ${FG_GREEN}✔  ¡Listo! Cerrá sesión y volvé a iniciarla para que${NC}"
    echo -e "     ${FG_GREEN}todos los cambios surtan efecto.${NC}"
    echo ""
    echo -e "  ${FG_MUTED}(Docker y sudoers requieren re-login)${NC}"
    echo ""
    echo -e "  ${BOLD}${FG_WHITE}Alan Stefanov${NC}"
    echo -e "  ${FG_ACCENT}https://github.com/AlanStefanov/toolkit-dev-ubuntu${NC}"
    echo ""
}

# ─── Main ───────────────────────────────────────────────────

main() {
    # Verificar bash 4+ (necesario para declare -A)
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo "Se requiere Bash 4+. Instalá una versión reciente." >&2
        exit 1
    fi

    # Verificar OS
    if ! grep -qiE "ubuntu|debian|mint|pop" /etc/os-release 2>/dev/null; then
        warn "Este script está optimizado para Ubuntu/Debian/Mint."
        warn "Continuar en otro sistema puede causar errores."
    fi

    ensure_sudo

    run_interactive_menu
    run_installation
    show_summary
}

main "$@"
