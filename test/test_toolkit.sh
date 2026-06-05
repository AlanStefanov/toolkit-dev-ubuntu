#!/usr/bin/env bash
# ============================================================
#  test_toolkit.sh
#  Suite de tests para toolkit-devops-install.sh
#  Corre en Docker para no afectar el sistema anfitrión.
#
#  Uso:
#    ./test/test_toolkit.sh              # test completo
#    ./test/test_toolkit.sh --quick      # solo syntax + helpers
#    ./test/test_toolkit.sh --image 24.04 # imagen Ubuntu específica
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/toolkit-devops-install.sh"
IMAGE="ubuntu:24.04"
QUICK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick) QUICK=true ;;
        --image) shift; IMAGE="$1" ;;
        *) echo "Uso: $0 [--quick] [--image <tag>]"; exit 1 ;;
    esac
    shift
done

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo -e "  \e[32m✓\e[0m $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  \e[31m✗\e[0m $1"; }

echo -e "\e[36m╔══════════════════════════════════════════════════╗\e[0m"
echo -e "\e[36m║      Toolkit Dev & DevOps — Test Suite          ║\e[0m"
echo -e "\e[36m╚══════════════════════════════════════════════════╝\e[0m"
echo "  Script: $TARGET_SCRIPT"
echo "  Image:  $IMAGE"
echo ""

# ─── 1. Syntax check (local) ──────────────────────────────────
echo -e "\e[1m━ 1. Sintaxis Bash ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
if bash -n "$TARGET_SCRIPT" 2>/dev/null; then
    ok "bash -n syntax check"
else
    fail "bash -n syntax check"
fi

# ─── 2. ShellCheck ────────────────────────────────────────────
echo -e "\e[1m━ 2. ShellCheck ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
if command -v shellcheck &>/dev/null; then
    if shellcheck -x "$TARGET_SCRIPT" 2>/dev/null; then
        ok "shellcheck passed"
    else
        fail "shellcheck warnings"
    fi
else
    echo -e "  \e[33m- shellcheck no instalado, salteando\e[0m"
fi

# ─── 3. Unit tests ────────────────────────────────────────────
echo -e "\e[1m━ 3. Unit tests en Docker ($IMAGE) ━━━━━━━\e[0m"

cat > /tmp/tk-unit-test.sh << 'TESTSCRIPT'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Copiar script y eliminar la llamada a main para solo tener las funciones
cp /opt/toolkit/toolkit-devops-install.sh /tmp/tk-full.sh
# Comentar la línea main "$@" (puede tener varios formatos)
sed -i 's/^main "$@"/# main "$@" # desactivado para tests/' /tmp/tk-full.sh
sed -i 's/^main $@/# main $@ # desactivado para tests/' /tmp/tk-full.sh
source /tmp/tk-full.sh

LOG_FILE=/tmp/unit-test.log
SUDO=""

OK()   { echo -e "  \e[32m✓\e[0m $1"; }
FAIL() { echo -e "  \e[31m✗\e[0m $1"; }
ERRS=0

# Preparar apt
apt-get update -qq > /dev/null 2>&1

# --- 3a. ensure_sudo ---
ensure_sudo 2>/dev/null
OK "ensure_sudo ejecutado sin error"

# --- 3b. apt_install ---
for pkg in tree jq; do
    if apt_install "$pkg" 2>/dev/null; then
        OK "apt_install $pkg"
    else
        FAIL "apt_install $pkg"; ERRS=$((ERRS+1))
    fi
done

# --- 3c. is_cmd ---
is_cmd tree && OK "is_cmd tree (existe)"   || { FAIL "is_cmd tree"; ERRS=$((ERRS+1)); }
is_cmd nonexistent999 && { FAIL "is_cmd nonexistent (falso +)"; ERRS=$((ERRS+1)); } || OK "is_cmd nonexistent (no existe)"

# --- 3d. pkg_installed ---
pkg_installed tree && OK "pkg_installed tree" || { FAIL "pkg_installed tree"; ERRS=$((ERRS+1)); }
pkg_installed pkg-xyzzy-999 && { FAIL "pkg_installed nonexistent"; ERRS=$((ERRS+1)); } || OK "pkg_installed nonexistent"

# --- 3e. ensure_base_deps ---
ensure_base_deps 2>/dev/null && OK "ensure_base_deps" || { FAIL "ensure_base_deps"; ERRS=$((ERRS+1)); }

# --- 3f. print_header ---
TERM_COLS=80
if print_header > /dev/null 2>&1; then
    OK "print_header renderiza"
else
    FAIL "print_header falló"; ERRS=$((ERRS+1))
fi

# --- 3g. build_flat_list ---
build_flat_list 2>/dev/null
[[ ${#FLAT_ITEMS[@]} -gt 0 ]] && OK "build_flat_list: ${#FLAT_ITEMS[@]} items" || { FAIL "build_flat_list vacío"; ERRS=$((ERRS+1)); }

# --- 3h. toggle_category ---
toggle_category "BASE DEL SISTEMA" 2>/dev/null
OK "toggle_category ejecutado sin error"

# --- 3i. install_step (simulado con una función dummy) ---
dummy_ok() { return 0; }
if install_step "test-dummy" dummy_ok > /dev/null 2>&1; then
    OK "install_step con éxito"
else
    FAIL "install_step con éxito"; ERRS=$((ERRS+1))
fi

echo ""
[[ $ERRS -eq 0 ]] && echo -e "   \e[32mUnit tests: OK\e[0m" || echo -e "   \e[31mUnit tests: $ERRS fallos\e[0m"
exit $ERRS
TESTSCRIPT

chmod +x /tmp/tk-unit-test.sh
if docker run --rm -v "$SCRIPT_DIR:/opt/toolkit:ro" -v /tmp/tk-unit-test.sh:/tmp/test.sh:ro "$IMAGE" bash /tmp/test.sh 2>&1; then
    ok "unit tests en Docker"
else
    fail "unit tests en Docker"
fi

# ─── 4. Instalación real (saltear si --quick) ────────────────
if [[ "$QUICK" == false ]]; then
    echo -e "\e[1m━ 4. Instalación real de herramientas ━━━━━━━━\e[0m"

    cat > /tmp/tk-real-test.sh << 'REALTEST'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LOG_FILE=/tmp/real-test.log

apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq curl wget gpg ca-certificates tar xz-utils > /dev/null 2>&1

is_cmd() { command -v "$1" &>/dev/null; }
apt_install() { local pkg=$1
    if dpkg -s "$pkg" &>/dev/null 2>&1; then return 0; fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
}

OK()   { echo -e "  \e[32m✓\e[0m $1"; }
FAIL() { echo -e "  \e[31m✗\e[0m $1"; }
ERRS=0

# --- 4a. apt packages preinstalados ---
for pkg in git curl wget; do
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
        OK "$pkg presente"
    else
        FAIL "$pkg ausente"; ERRS=$((ERRS+1))
    fi
done

# --- 4b. Go ---
GO_VER=$(curl -fsSL https://go.dev/VERSION?m=text 2>/dev/null | head -1)
[[ -n "$GO_VER" ]] && OK "Go versión: $GO_VER" || { FAIL "No se pudo obtener Go version"; ERRS=$((ERRS+1)); }
curl -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz 2>/dev/null
tar -C /usr/local -xzf /tmp/go.tar.gz 2>/dev/null
/usr/local/go/bin/go version 2>/dev/null && OK "Go instalado y funciona" || { FAIL "Go no funciona"; ERRS=$((ERRS+1)); }
rm -f /tmp/go.tar.gz

# --- 4c. Rust ---
curl -fsSL https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
source "$HOME/.cargo/env" 2>/dev/null
rustc --version 2>/dev/null && OK "Rustc funciona" || { FAIL "Rustc no funciona"; ERRS=$((ERRS+1)); }
cargo --version 2>/dev/null && OK "Cargo funciona" || { FAIL "Cargo no funciona"; ERRS=$((ERRS+1)); }

# --- 4d. eza ---
apt_install eza 2>/dev/null
eza --version 2>/dev/null && OK "eza funciona" || { FAIL "eza no funciona"; ERRS=$((ERRS+1)); }

# --- 4e. Python3 ---
apt_install python3 2>/dev/null
python3 --version 2>/dev/null && OK "Python3 funciona" || { FAIL "Python3 no funciona"; ERRS=$((ERRS+1)); }

# --- 4f. tree, jq ---
for pkg in tree jq; do
    apt_install "$pkg" 2>/dev/null
done
tree --version > /dev/null 2>&1 && OK "tree funciona" || { FAIL "tree no funciona"; ERRS=$((ERRS+1)); }
jq --version > /dev/null 2>&1 && OK "jq funciona" || { FAIL "jq no funciona"; ERRS=$((ERRS+1)); }

echo ""
[[ $ERRS -eq 0 ]] && echo -e "   \e[32mReal install tests: OK\e[0m" || echo -e "   \e[31mReal install tests: $ERRS fallos\e[0m"
exit $ERRS
REALTEST

    chmod +x /tmp/tk-real-test.sh
    if docker run --rm -v "$SCRIPT_DIR:/opt/toolkit:ro" -v /tmp/tk-real-test.sh:/tmp/real-test.sh:ro "$IMAGE" bash /tmp/real-test.sh 2>&1; then
        ok "instalación real de herramientas"
    else
        fail "instalación real de herramientas"
    fi
fi

# ─── Resumen ──────────────────────────────────────────────────
echo ""
echo -e "\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[1mResultado:\e[0m $PASS \e[32mok\e[0m · $FAIL \e[31mfallos\e[0m"
if [[ $FAIL -eq 0 ]]; then
    echo -e "\e[32m✓ Todos los tests pasaron\e[0m"
else
    echo -e "\e[31m✗ Algunos tests fallaron\e[0m"
    exit 1
fi
