#!/usr/bin/env bash
#
# ████████╗ ██████╗  ██████╗ ██╗     ██╗  ██╗██╗████████╗
# ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██║ ██╔╝██║╚══██╔══╝
#    ██║   ██║   ██║██║   ██║██║     █████╔╝ ██║   ██║
#    ██║   ██║   ██║██║   ██║██║     ██╔═██╗ ██║   ██║
#    ██║   ╚██████╔╝╚██████╔╝███████╗██║  ██╗██║   ██║
#    ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝
#
#  ██████╗ ███████╗██╗   ██╗     ██████╗ ██████╗ ███████╗
#  ██╔══██╗██╔════╝██║   ██║    ██╔═══██╗██╔══██╗██╔════╝
#  ██║  ██║█████╗  ██║   ██║    ██║   ██║██████╔╝███████╗
#  ██║  ██║██╔══╝  ╚██╗ ██╔╝    ██║   ██║██╔══██╗╚════██║
#  ██████╔╝███████╗ ╚████╔╝     ╚██████╔╝██║  ██║███████║
#  ╚═════╝ ╚══════╝  ╚═══╝       ╚═════╝ ╚═╝  ╚═╝╚══════╝
#
# ============================================================
#  TOOLKIT DEV & DEVOPS — ECOSISTEMA .deb
#  Instalador interactivo para Ubuntu/Debian
#  Por Alan Stefanov
#  Repositorio: https://github.com/AlanStefanov/toolkit-dev-ubuntu
# ============================================================
#  Licencia MIT - Ver LICENSE para más detalles
# ============================================================

set -euo pipefail

VERSION="1.0.0"
LOG_FILE="/tmp/toolkit-install-$(date +%Y%m%d-%H%M%S).log"
INSTALLED=()
SKIPPED=()
FAILED=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
info() { echo -e "${CYAN}ℹ${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }

cleanup() {
    rm -f /tmp/toolkit-*.deb /tmp/toolkit-*.zip /tmp/toolkit-*.tar.gz 2>/dev/null || true
}
trap cleanup EXIT

ensure_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
    fi
}

apt_install() {
    local pkg=$1
    if dpkg -s "$pkg" &>/dev/null; then
        return 0
    fi
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" &>> "$LOG_FILE"
}

is_installed() {
    command -v "$1" &>/dev/null
}

install_step() {
    local label=$1
    shift
    echo -ne "${CYAN}[ ]${NC} $label... "
    if "$@" &>> "$LOG_FILE"; then
        echo -e "\r${GREEN}[✓]${NC} $label"
        INSTALLED+=("$label")
    else
        echo -e "\r${RED}[✗]${NC} $label"
        FAILED+=("$label")
    fi
}

# ─── Instaladores ──────────────────────────────────────────

install_vscode() {
    is_installed code && return 0
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg &>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list &>/dev/null
    $SUDO apt-get update -qq && apt_install code
}

install_dbeaver() {
    is_installed dbeaver-ce && return 0
    $SUDO apt-get install -y openjdk-21-jre &>> "$LOG_FILE"
    wget -qO- https://dbeaver.io/debs/dbeaver.gpg.key | gpg --dearmor | $SUDO tee /usr/share/keyrings/dbeaver.gpg &>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg] https://dbeaver.io/debs/ /" | $SUDO tee /etc/apt/sources.list.d/dbeaver.list &>/dev/null
    $SUDO apt-get update -qq && apt_install dbeaver-ce
}

install_opencode() {
    is_installed opencode && return 0
    curl -fsSL https://opencode.ai/install.sh | sh
}

install_alacritty() {
    is_installed alacritty && return 0
    apt_install alacritty
}

install_warp() {
    is_installed warp-terminal && return 0
    local deb="/tmp/toolkit-warp.deb"
    curl -fsSL "https://releases.warp.dev/linux/stable/warp-terminal.deb" -o "$deb"
    $SUDO dpkg -i "$deb" &>/dev/null || $SUDO apt-get install -fy -qq &>/dev/null
}

install_tmux() {
    is_installed tmux && return 0
    apt_install tmux
}

install_gnome_dock() {
    apt_install gnome-shell-extension-dash-to-dock
    is_installed gnome-extensions && gnome-extensions enable dash-to-dock@micxgx.gmail.com &>/dev/null || true
}

install_sublime() {
    is_installed subl && return 0
    wget -qO- https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | $SUDO tee /usr/share/keyrings/sublimehq.gpg &>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/sublimehq.gpg] https://download.sublimetext.com/ apt/stable/" | $SUDO tee /etc/apt/sources.list.d/sublime-text.list &>/dev/null
    $SUDO apt-get update -qq && apt_install sublime-text
}

install_awscli() {
    is_installed aws && aws --version | grep -q "aws-cli/2" && return 0
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -qo /tmp/awscliv2.zip -d /tmp/awscliv2
    $SUDO /tmp/awscliv2/aws/install --update
}

install_gh() {
    is_installed gh && return 0
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor | $SUDO tee /usr/share/keyrings/githubcli.gpg &>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list &>/dev/null
    $SUDO apt-get update -qq && apt_install gh
}

install_turso() {
    is_installed turso && return 0
    curl -fsSL https://get.turso.tech/install.sh | sh
}

install_db_clients() {
    apt_install postgresql-client
    apt_install sqlite3
    apt_install mysql-client || true
}

install_docker() {
    is_installed docker && return 0
    curl -fsSL https://get.docker.com | sh
    $SUDO usermod -aG docker "$USER" 2>/dev/null || true
    apt_install docker-compose-plugin || true
}

install_sudoers() {
    local user="${SUDO_USER:-$USER}"
    [[ "$user" == "root" ]] && return 0
    [[ -f "/etc/sudoers.d/$user" ]] && return 0
    echo "$user ALL=(ALL) NOPASSWD:ALL" | $SUDO tee "/etc/sudoers.d/$user" &>/dev/null
    $SUDO chmod 0440 "/etc/sudoers.d/$user"
}

install_portainer() {
    if docker inspect portainer &>/dev/null 2>&1; then
        return 0
    fi
    docker volume create portainer_data &>/dev/null || true
    docker run -d --name portainer --restart always \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest &>/dev/null
}

install_vlc() {
    is_installed vlc && return 0
    apt_install vlc
}

install_kubectl() {
    is_installed kubectl && return 0
    local ver
    ver=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -fsSL "https://dl.k8s.io/release/$ver/bin/linux/amd64/kubectl" -o /tmp/kubectl
    $SUDO install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
}

install_helm() {
    is_installed helm && return 0
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_terraform() {
    is_installed terraform && return 0
    $SUDO apt-get install -y gnupg software-properties-common &>> "$LOG_FILE"
    wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | $SUDO tee /usr/share/keyrings/hashicorp.gpg &>/dev/null
    $SUDO apt-add-repository -y "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" &>/dev/null
    $SUDO apt-get update -qq && apt_install terraform
}

install_python() {
    apt_install python3-pip
    apt_install python3-venv
    apt_install python3-dev || true
}

install_build_essential() {
    apt_install build-essential
}

install_jq() {
    is_installed jq && return 0
    apt_install jq
}

install_htop() {
    is_installed htop && return 0
    apt_install htop
}

install_fzf() {
    is_installed fzf && return 0
    apt_install fzf
}

install_ripgrep() {
    is_installed rg && return 0
    apt_install ripgrep
}

install_bat() {
    is_installed bat && return 0
    apt_install bat
    # En Ubuntu, bat se instala como batcat, crear alias
    if is_installed batcat && ! is_installed bat; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat" 2>/dev/null || true
    fi
}

install_lazygit() {
    is_installed lazygit && return 0
    local ver
    ver=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -fsLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${ver}_Linux_x86_64.tar.gz"
    $SUDO tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit 2>/dev/null
}

install_nvm_node() {
    if [[ -d "$HOME/.nvm" ]]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        is_installed node && return 0
    fi
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts &>/dev/null || true
}

install_openssh() {
    apt_install openssh-server
    $SUDO systemctl enable ssh &>/dev/null || true
    $SUDO systemctl start ssh &>/dev/null || true
}

install_git_curl_wget() {
    apt_install git
    apt_install curl
    apt_install wget
}

install_make() {
    apt_install make
}

install_tree() {
    apt_install tree
}

install_neovim() {
    is_installed nvim && return 0
    apt_install neovim
}

install_postman() {
    is_installed postman && return 0
    apt_install flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null || true
    flatpak install -y --noninteractive flathub com.getpostman.Postman &>/dev/null || true
}

# ─── UI ────────────────────────────────────────────────────

check_whiptail() {
    is_installed whiptail && return 0
    $SUDO apt-get install -y whiptail &>/dev/null
}

show_welcome() {
    whiptail --title "Toolkit Dev & DevOps — Ecosistema .deb" --msgbox "\
Bienvenido al Toolkit Dev & DevOps para ecosistema .deb

Versión: $VERSION
Autor: Alan Stefanov

Este instalador te guiará en la configuración de tu entorno
Ubuntu/Debian con las mejores herramientas para desarrollo
y operaciones.

Podés seleccionar qué herramientas instalar. Cada una se
instalará de forma independiente.

¿Comenzamos?" 16 60
}

show_checklist() {
    whiptail --title "Toolkit Dev & DevOps — Ecosistema .deb" --checklist "\
Seleccioná las herramientas a instalar (ESPACIO para marcar):" 30 80 22 \
        "--- EDITORES / IDE ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "VS_Code"          "Visual Studio Code"                           on \
        "Sublime_Text"     "Sublime Text 4"                               on \
        "Neovim"           "Neovim (editor CLI moderno)"                 on \
        "OpenCode"         "OpenCode (CLI de IA para código)"            on \
        "--- TERMINALES ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "Alacritty"        "Alacritty (terminal GPU)"                     on \
        "Warp"             "Warp Terminal (moderna + AI)"                on \
        "Tmux"             "Tmux (multiplexor de terminal)"              on \
        "--- BASES DE DATOS ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "DBeaver"          "DBeaver CE (gestor BD universal)"             on \
        "DB_Clients"       "psql + sqlite3 + mysql client"               on \
        "Turso_CLI"        "Turso CLI (base de datos edge)"              on \
        "--- CLOUD / INFRA ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "AWS_CLI"          "AWS CLI v2"                                   on \
        "GH_CLI"           "GitHub CLI (gh)"                              on \
        "Kubectl"          "kubectl (Kubernetes)"                         on \
        "Helm"             "Helm (package manager K8s)"                  on \
        "Terraform"        "Terraform (Infrastructure as Code)"          on \
        "--- CONTENEDORES ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "Docker"           "Docker Engine + Compose (sin sudo)"          on \
        "Portainer"        "Portainer (GUI Docker)"                       on \
        "--- DEV ESSENTIALS ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "NVM_Node"         "nvm + Node.js LTS"                            on \
        "Python"           "python3-pip + venv + dev"                     on \
        "Build_Essential"  "build-essential (gcc, make, etc)"            on \
        "Git_Curl_Wget"    "git + curl + wget"                            on \
        "Make"             "GNU Make"                                     on \
        "OpenSSH"          "OpenSSH Server"                               on \
        "Tree"             "tree (lista directorios)"                     on \
        "--- CLI POWER-UPS ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "JQ"               "jq (procesador JSON en CLI)"                  on \
        "Htop"             "htop (monitor de procesos)"                   on \
        "FZF"              "fzf (fuzzy finder)"                           on \
        "Ripgrep"          "ripgrep / rg (búsqueda rápida)"               on \
        "Bat"              "bat (cat con syntax highlighting)"            on \
        "Lazygit"          "lazygit (UI para git en terminal)"            on \
        "--- API CLIENT ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "Postman"          "Postman (API client via Flatpak)"             on \
        "--- SISTEMA / UI ---" "━━━━━━━━━━━━━━━━━━━━━━━━━" off \
        "Gnome_Dock"       "Dash to Dock (dock tipo macOS)"               on \
        "Sudoers"          "sudo sin contraseña para tu usuario"          on \
        "VLC"              "VLC Media Player"                             on \
        3>&1 1>&2 2>&3
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "████████╗ ██████╗  ██████╗ ██╗     ██╗  ██╗██╗████████╗"
    echo "╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██║ ██╔╝██║╚══██╔══╝"
    echo "   ██║   ██║   ██║██║   ██║██║     █████╔╝ ██║   ██║"
    echo "   ██║   ██║   ██║██║   ██║██║     ██╔═██╗ ██║   ██║"
    echo "   ██║   ╚██████╔╝╚██████╔╝███████╗██║  ██╗██║   ██║"
    echo "   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝"
    echo -e "${NC}"
    echo -e "${BOLD}${MAGENTA}  DEV & DEVOPS${NC} — ${CYAN}Ecosistema .deb${NC}"
    echo -e "  ${YELLOW}Por Alan Stefanov${NC}"
    echo -e "  ${GREEN}Versión: ${VERSION}${NC}"
    echo ""
}

run_installation() {
    local selections=("$@")
    print_banner
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${CYAN}Iniciando instalación de ${#selections[@]} herramientas...${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== INICIO INSTALACIÓN ==="
    log "Usuario: $USER | Herramientas: ${selections[*]}"

    for selection in "${selections[@]}"; do
        case "$selection" in
            VS_Code)         install_step "Visual Studio Code"         install_vscode ;;
            Sublime_Text)    install_step "Sublime Text"               install_sublime ;;
            Neovim)          install_step "Neovim"                    install_neovim ;;
            OpenCode)        install_step "OpenCode"                  install_opencode ;;
            Alacritty)       install_step "Alacritty"                 install_alacritty ;;
            Warp)            install_step "Warp Terminal"             install_warp ;;
            Tmux)            install_step "Tmux"                      install_tmux ;;
            DBeaver)         install_step "DBeaver CE"                install_dbeaver ;;
            DB_Clients)      install_step "psql + sqlite3 + mysql"     install_db_clients ;;
            Turso_CLI)       install_step "Turso CLI"                 install_turso ;;
            AWS_CLI)         install_step "AWS CLI v2"               install_awscli ;;
            GH_CLI)          install_step "GitHub CLI (gh)"            install_gh ;;
            Kubectl)         install_step "kubectl"                   install_kubectl ;;
            Helm)            install_step "Helm"                      install_helm ;;
            Terraform)       install_step "Terraform"                 install_terraform ;;
            Docker)          install_step "Docker + Compose"           install_docker ;;
            Portainer)       install_step "Portainer"                 install_portainer ;;
            NVM_Node)        install_step "nvm + Node.js LTS"         install_nvm_node ;;
            Python)          install_step "Python3 pip + venv"         install_python ;;
            Build_Essential) install_step "build-essential"            install_build_essential ;;
            Git_Curl_Wget)   install_step "git + curl + wget"          install_git_curl_wget ;;
            Make)            install_step "GNU Make"                  install_make ;;
            OpenSSH)         install_step "OpenSSH Server"            install_openssh ;;
            Tree)            install_step "tree"                      install_tree ;;
            JQ)              install_step "jq"                        install_jq ;;
            Htop)            install_step "htop"                      install_htop ;;
            FZF)             install_step "fzf"                       install_fzf ;;
            Ripgrep)         install_step "ripgrep (rg)"              install_ripgrep ;;
            Bat)             install_step "bat"                       install_bat ;;
            Lazygit)         install_step "lazygit"                   install_lazygit ;;
            Postman)         install_step "Postman"                   install_postman ;;
            Gnome_Dock)      install_step "Dash to Dock"              install_gnome_dock ;;
            Sudoers)         install_step "sudo sin contraseña"        install_sudoers ;;
            VLC)             install_step "VLC Media Player"           install_vlc ;;
        esac
    done
    log "=== FIN INSTALACIÓN ==="
}

show_summary() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${GREEN}RESUMEN DE INSTALACIÓN${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    [[ ${#INSTALLED[@]} -gt 0 ]] && { echo -e "${GREEN}✅ Instaladas (${#INSTALLED[@]}):${NC}"; for item in "${INSTALLED[@]}"; do echo "   • $item"; done; echo ""; }
    [[ ${#SKIPPED[@]} -gt 0 ]] && { echo -e "${YELLOW}⏭️  Omitidas (${#SKIPPED[@]}):${NC}"; for item in "${SKIPPED[@]}"; do echo "   • $item"; done; echo ""; }
    [[ ${#FAILED[@]} -gt 0 ]] && { echo -e "${RED}❌ Fallaron (${#FAILED[@]}):${NC}"; for item in "${FAILED[@]}"; do echo "   • $item"; done; echo ""; }

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " Log: ${BOLD}$LOG_FILE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}¡Entorno listo! Cerrá sesión y volvé a iniciarla para que${NC}"
    echo -e "${GREEN}todos los cambios surtan efecto (especialmente Docker y sudoers).${NC}"
    echo ""
    echo -e "  ${BOLD}Alan Stefanov${NC}"
    echo -e "  ${CYAN}https://github.com/AlanStefanov/toolkit-dev-ubuntu${NC}"
    echo ""

    [[ ${#FAILED[@]} -gt 0 ]] && warn "Algunas herramientas fallaron. Revisá el log: $LOG_FILE"
}

main() {
    ensure_sudo
    check_whiptail

    info "Actualizando repositorios..."
    $SUDO apt-get update -qq &>/dev/null

    print_banner
    show_welcome

    local selections
    selections=$(show_checklist)

    if [[ -z "$selections" ]]; then
        echo ""
        warn "No se seleccionó ninguna herramienta. Saliendo."
        exit 0
    fi

    eval "run_installation $selections"
    show_summary
}

main "$@"
