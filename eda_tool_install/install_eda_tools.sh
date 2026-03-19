#!/usr/bin/env bash
# ==============================================================================
# EDA Open-Source Tool Installer  v1.0
# ASIC Multi-Agent Framework — RTL→GDSII Toolchain Setup
#
# Tools covered:
#   Simulation   : Verilator, Icarus Verilog (iverilog), GTKWave
#   Synthesis    : Yosys (+ ABC), SymbiYosys (sby)
#   P&R / STA    : OpenROAD (includes OpenSTA, TritonCTS, TritonRoute, PSM)
#   Phys Verif   : Magic, Netgen, KLayout
#   Automation   : LibreLane (OpenLane 2)
#   PDK          : sky130B, GF180MCU  (via volare)
#
# Supported OS  : macOS 12+, Ubuntu 20.04/22.04/24.04, Debian 11/12,
#                 Fedora 36+, RHEL/Rocky/Alma 8/9, Arch Linux
# Install modes : Docker (recommended) | Local (native packages + source builds)
# ==============================================================================

set -euo pipefail

# ── Colour palette ─────────────────────────────────────────────────────────────
RED=$'\e[0;31m'; YELLOW=$'\e[0;33m'; GREEN=$'\e[0;32m'
CYAN=$'\e[0;36m'; BOLD=$'\e[1m'; DIM=$'\e[2m'; RESET=$'\e[0m'

# ── Helpers ────────────────────────────────────────────────────────────────────
info()    { echo "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo "${RED}[ERROR]${RESET} $*" >&2; }
hdr()     { echo; echo "${BOLD}${CYAN}══ $* ══${RESET}"; echo; }
confirm() {
    local prompt="${1:-Continue?} [y/N] "
    local reply
    read -r -p "$prompt" reply
    [[ "${reply,,}" =~ ^y(es)?$ ]]
}

# ── Tool registry ──────────────────────────────────────────────────────────────
# Format: "display_name|binary|version_flag|stage|notes"
declare -a TOOLS=(
    "Verilator|verilator|--version|Sim/Lint|Cycle-accurate sim + lint"
    "Icarus Verilog|iverilog|-V|Simulation|Event-based Verilog sim"
    "GTKWave|gtkwave|--version|Waveform|VCD/FST waveform viewer"
    "Yosys|yosys|--version|Synthesis|Open-source synthesis + ABC"
    "SymbiYosys|sby|--help|Formal|Formal verification framework"
    "OpenROAD|openroad|--version|P&R/STA|Full PnR suite + OpenSTA + PSM"
    "OpenSTA|sta|--version|STA|Standalone static timing (also in OpenROAD)"
    "Magic|magic|--version|Phys-Verif|DRC, extraction, GDS stream-out"
    "Netgen|netgen|-batch|LVS|Layout vs Schematic"
    "KLayout|klayout|--version|GDS View|GDS/OASIS viewer + DRC scripting"
    "LibreLane|librelane|--version|Automation|Full RTL→GDSII automation"
    "Volare|volare|--version|PDK Mgr|OpenPDK version manager"
)

# Docker images (all-in-one + standalone fallbacks)
DOCKER_LIBRELANE="ghcr.io/efabless/librelane:latest"
DOCKER_OPENLANE2="efabless/openlane2:latest"
DOCKER_KLAYOUT="ghcr.io/efabless/klayout:latest"

# ── OS detection ───────────────────────────────────────────────────────────────
detect_os() {
    OS_TYPE=""
    OS_ID=""
    OS_VER=""
    PKG_MGR=""

    if [[ "$OSTYPE" == darwin* ]]; then
        OS_TYPE="macos"
        OS_VER=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
        OS_ID="macos"
        PKG_MGR="brew"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VER="${VERSION_ID:-unknown}"
        case "$ID" in
            ubuntu|debian|linuxmint|pop)
                OS_TYPE="debian"
                PKG_MGR="apt"
                ;;
            fedora)
                OS_TYPE="fedora"
                PKG_MGR="dnf"
                ;;
            rhel|centos|rocky|almalinux)
                OS_TYPE="rhel"
                PKG_MGR="dnf"
                ;;
            arch|manjaro|endeavouros)
                OS_TYPE="arch"
                PKG_MGR="pacman"
                ;;
            *)
                OS_TYPE="linux-other"
                PKG_MGR="unknown"
                ;;
        esac
    else
        OS_TYPE="unknown"
        PKG_MGR="unknown"
    fi
}

# ── Docker detection ───────────────────────────────────────────────────────────
detect_docker() {
    DOCKER_AVAILABLE=false
    DOCKER_VERSION=""
    DOCKER_RUNNING=false

    if command -v docker &>/dev/null; then
        DOCKER_AVAILABLE=true
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        if docker info &>/dev/null 2>&1; then
            DOCKER_RUNNING=true
        fi
    fi
}

# ── Per-tool detection ─────────────────────────────────────────────────────────
detect_tools() {
    declare -gA TOOL_STATUS   # "found" | "missing"
    declare -gA TOOL_VERSION

    for entry in "${TOOLS[@]}"; do
        IFS='|' read -r name binary vflag _stage _notes <<< "$entry"
        if command -v "$binary" &>/dev/null; then
            TOOL_STATUS["$name"]="found"
            # Try to grab version (suppress errors — not all tools behave the same)
            local ver
            ver=$(eval "$binary $vflag 2>&1" | head -1 | grep -oE '[0-9]+\.[0-9]+[^ ]*' | head -1 || true)
            TOOL_VERSION["$name"]="${ver:-?}"
        else
            TOOL_STATUS["$name"]="missing"
            TOOL_VERSION["$name"]="-"
        fi
    done
}

# ── Environment vars check ─────────────────────────────────────────────────────
detect_env_vars() {
    declare -gA ENV_STATUS
    local vars=("OPENROAD_HOME" "YOSYS_ROOT" "PDK_ROOT" "LIBRELANE_ROOT" "VOLARE_ROOT")
    for v in "${vars[@]}"; do
        ENV_STATUS["$v"]="${!v:-}"
    done
}

# ── PDK detection ──────────────────────────────────────────────────────────────
detect_pdks() {
    PDK_ROOT_PATH="${PDK_ROOT:-/opt/pdk}"
    declare -ga PDK_FOUND=()
    for pdk in sky130A sky130B gf180mcuC gf180mcuD ihp-sg13g2; do
        if [[ -d "${PDK_ROOT_PATH}/${pdk}" ]]; then
            PDK_FOUND+=("$pdk")
        fi
    done
}

# ── Homebrew presence ──────────────────────────────────────────────────────────
detect_brew() {
    BREW_AVAILABLE=false
    if command -v brew &>/dev/null; then
        BREW_AVAILABLE=true
    fi
}

# ── Status dashboard ───────────────────────────────────────────────────────────
print_dashboard() {
    clear
    echo "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║          EDA Open-Source Tool Installer — ASIC Multi-Agent Framework        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo

    # ── OS & Docker ──────────────────────────────────────────────────────────────
    hdr "Environment"
    printf "  %-20s %s\n" "OS:" "${BOLD}${OS_ID} ${OS_VER}${RESET}  (type: ${OS_TYPE}, pkg: ${PKG_MGR})"
    if $DOCKER_AVAILABLE; then
        if $DOCKER_RUNNING; then
            printf "  %-20s %s\n" "Docker:" "${GREEN}${BOLD}running${RESET}  (${DOCKER_VERSION})"
        else
            printf "  %-20s %s\n" "Docker:" "${YELLOW}installed but daemon not running${RESET}  (${DOCKER_VERSION})"
        fi
    else
        printf "  %-20s %s\n" "Docker:" "${RED}not found${RESET}"
    fi

    # ── Tool status table ─────────────────────────────────────────────────────
    hdr "Tool Status"
    printf "  ${BOLD}%-22s %-12s %-10s %-30s${RESET}\n" "Tool" "Stage" "Version" "Status"
    echo "  ──────────────────────────────────────────────────────────────────────────"
    for entry in "${TOOLS[@]}"; do
        IFS='|' read -r name _bin _vflag stage notes <<< "$entry"
        local status="${TOOL_STATUS[$name]:-missing}"
        local ver="${TOOL_VERSION[$name]:--}"
        if [[ "$status" == "found" ]]; then
            local tag="${GREEN}✔ installed (${ver})${RESET}"
        else
            local tag="${RED}✘ not found${RESET}"
        fi
        printf "  %-22s ${DIM}%-12s${RESET} %-10s %b\n" "$name" "$stage" "$ver" "$tag"
    done

    # ── PDKs ──────────────────────────────────────────────────────────────────
    hdr "Open PDKs  (PDK_ROOT=${PDK_ROOT_PATH})"
    if [[ ${#PDK_FOUND[@]} -eq 0 ]]; then
        echo "  ${YELLOW}No PDKs found at ${PDK_ROOT_PATH}${RESET}"
    else
        for p in "${PDK_FOUND[@]}"; do
            echo "  ${GREEN}✔${RESET} $p"
        done
    fi

    # ── Env vars ─────────────────────────────────────────────────────────────
    hdr "Key Environment Variables"
    for v in OPENROAD_HOME YOSYS_ROOT PDK_ROOT LIBRELANE_ROOT VOLARE_ROOT; do
        local val="${ENV_STATUS[$v]:-}"
        if [[ -n "$val" ]]; then
            printf "  ${GREEN}✔${RESET} %-20s = %s\n" "$v" "$val"
        else
            printf "  ${DIM}○${RESET} %-20s   ${DIM}(not set)${RESET}\n" "$v"
        fi
    done
    echo
}

# ── Summary counts ─────────────────────────────────────────────────────────────
count_missing() {
    local n=0
    for entry in "${TOOLS[@]}"; do
        IFS='|' read -r name _ _ _ _ <<< "$entry"
        [[ "${TOOL_STATUS[$name]:-missing}" == "missing" ]] && ((n++)) || true
    done
    echo "$n"
}

# ══════════════════════════════════════════════════════════════════════════════
#  DOCKER INSTALL PATHS
# ══════════════════════════════════════════════════════════════════════════════

start_docker_daemon_hint() {
    if ! $DOCKER_RUNNING; then
        warn "Docker daemon is not running."
        if [[ "$OS_TYPE" == "macos" ]]; then
            warn "Start Docker Desktop, then re-run this script."
        else
            warn "Run: sudo systemctl start docker"
            warn "     sudo usermod -aG docker \$USER   (then log out/in)"
        fi
        return 1
    fi
    return 0
}

install_docker_librelane() {
    hdr "Pulling LibreLane (all-in-one) Docker image"
    info "Image: ${DOCKER_LIBRELANE}"
    info "Includes: Yosys, OpenROAD, OpenSTA, KLayout, Magic, Netgen, iverilog, Verilator"
    echo
    start_docker_daemon_hint || return 1

    info "Pulling — this may take 10-20 min on first run (~5 GB)..."
    docker pull "${DOCKER_LIBRELANE}"
    ok "LibreLane image pulled."

    # Install wrapper script into ~/bin
    local wrapper_dir="$HOME/.local/bin"
    mkdir -p "$wrapper_dir"
    cat > "$wrapper_dir/librelane" <<'WRAPPER'
#!/usr/bin/env bash
# LibreLane Docker wrapper
IMAGE="ghcr.io/efabless/librelane:latest"
exec docker run --rm -it \
    -v "$PWD:/work" \
    -v "${PDK_ROOT:-/opt/pdk}:/pdk" \
    -e PDK_ROOT=/pdk \
    -w /work \
    "$IMAGE" "$@"
WRAPPER
    chmod +x "$wrapper_dir/librelane"
    ok "Wrapper installed: ${wrapper_dir}/librelane"
    info "Add ${wrapper_dir} to PATH if not already present."

    # Drop-in shell alias helper
    cat > "$wrapper_dir/eda-shell" <<'SHELL_WRAP'
#!/usr/bin/env bash
# Launch interactive EDA shell inside LibreLane container
IMAGE="ghcr.io/efabless/librelane:latest"
echo "Entering EDA shell (LibreLane Docker)…  type 'exit' to leave."
exec docker run --rm -it \
    -v "$PWD:/work" \
    -v "${PDK_ROOT:-/opt/pdk}:/pdk" \
    -e PDK_ROOT=/pdk \
    -w /work \
    "$IMAGE" bash
SHELL_WRAP
    chmod +x "$wrapper_dir/eda-shell"
    ok "Interactive shell wrapper installed: ${wrapper_dir}/eda-shell"
}

install_docker_standalone() {
    hdr "Pulling Standalone EDA Docker Images"
    start_docker_daemon_hint || return 1

    declare -A STANDALONE_IMAGES=(
        ["KLayout"]="ghcr.io/efabless/klayout:latest"
        ["OpenROAD"]="openroadproject/openroad:latest"
        ["Yosys"]="hdlc/yosys:latest"
        ["Verilator"]="hdlc/verilator:latest"
    )

    for tool in "${!STANDALONE_IMAGES[@]}"; do
        local img="${STANDALONE_IMAGES[$tool]}"
        info "Pulling ${tool} → ${img}"
        docker pull "$img" && ok "${tool} pulled." || warn "Pull failed for ${tool} (image may have moved — check Docker Hub)."
    done
}

install_docker_pdk() {
    hdr "Installing PDKs via Volare (Docker)"
    start_docker_daemon_hint || return 1

    local pdk_dir="${PDK_ROOT:-$HOME/pdk}"
    mkdir -p "$pdk_dir"
    info "PDK_ROOT will be: ${pdk_dir}"
    echo
    echo "  Supported PDKs:"
    echo "    1) sky130B   — SkyWater 130 nm (most complete OSS PDK)"
    echo "    2) sky130A   — SkyWater 130 nm (alternative variant)"
    echo "    3) gf180mcuC — GlobalFoundries 180 nm MCU"
    echo "    4) gf180mcuD — GlobalFoundries 180 nm MCU (extended)"
    echo "    5) All of the above"
    echo "    0) Skip PDK install"
    echo
    read -r -p "  Select PDK to install [1-5, 0 to skip]: " pdk_choice

    declare -a pdks_to_install=()
    case "$pdk_choice" in
        1) pdks_to_install=("sky130B") ;;
        2) pdks_to_install=("sky130A") ;;
        3) pdks_to_install=("gf180mcuC") ;;
        4) pdks_to_install=("gf180mcuD") ;;
        5) pdks_to_install=("sky130B" "sky130A" "gf180mcuC" "gf180mcuD") ;;
        0) info "Skipping PDK install."; return 0 ;;
        *) warn "Invalid choice, skipping PDK install."; return 0 ;;
    esac

    for pdk in "${pdks_to_install[@]}"; do
        info "Installing ${pdk} via LibreLane Docker..."
        docker run --rm \
            -v "${pdk_dir}:/pdk" \
            "${DOCKER_LIBRELANE}" \
            bash -c "pip install volare -q && volare enable --pdk ${pdk%[ABCD]} ${pdk}" \
            && ok "${pdk} installed to ${pdk_dir}/${pdk}" \
            || warn "PDK install for ${pdk} failed — try manually: volare enable --pdk ${pdk%[ABCD]} ${pdk}"
    done

    info "Set PDK_ROOT=${pdk_dir} in your shell profile (.bashrc / .zshrc)"
    info "  echo 'export PDK_ROOT=${pdk_dir}' >> ~/.zshrc"
}

# ══════════════════════════════════════════════════════════════════════════════
#  LOCAL INSTALL PATHS
# ══════════════════════════════════════════════════════════════════════════════

require_root() {
    if [[ "$EUID" -ne 0 && "$OS_TYPE" != "macos" ]]; then
        warn "Some packages require sudo. You may be prompted for your password."
    fi
}

# ── macOS ──────────────────────────────────────────────────────────────────────
install_local_macos() {
    hdr "macOS Local Install via Homebrew"

    if ! $BREW_AVAILABLE; then
        warn "Homebrew not found."
        if confirm "Install Homebrew now?"; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            BREW_AVAILABLE=true
        else
            err "Cannot proceed without Homebrew on macOS."
            return 1
        fi
    fi

    info "Updating Homebrew..."
    brew update

    info "Installing simulation tools..."
    brew install icarus-verilog verilator || true
    brew install --cask gtkwave || brew install gtkwave || true

    info "Installing synthesis tools..."
    brew install yosys || true

    info "Installing SymbiYosys and solvers..."
    brew install symbiyosys yices z3 boolector || true

    info "Installing KLayout..."
    brew install --cask klayout 2>/dev/null || brew install klayout || true

    info "Installing OpenROAD..."
    # OpenROAD has a Homebrew tap
    brew tap The-OpenROAD-Project/homebrew-openroad 2>/dev/null || true
    brew install openroad || {
        warn "OpenROAD brew install failed. Trying prebuilt binary..."
        _install_openroad_prebuilt_macos
    }

    info "Installing Magic..."
    brew install magic 2>/dev/null || {
        warn "magic not in Homebrew — building from source..."
        _build_magic_macos
    }

    info "Installing Netgen..."
    brew install netgen 2>/dev/null || {
        warn "netgen not in Homebrew — building from source..."
        _build_netgen_macos
    }

    info "Installing Python utilities (volare, LibreLane)..."
    pip3 install --user volare librelane 2>/dev/null || \
    pip3 install volare librelane 2>/dev/null || \
    warn "pip install failed — try: pip3 install volare librelane"

    ok "macOS local install complete."
    _print_env_export_hint
}

_install_openroad_prebuilt_macos() {
    local url="https://github.com/The-OpenROAD-Project/OpenROAD/releases/latest"
    warn "Prebuilt OpenROAD macOS binary must be downloaded from:"
    warn "  ${url}"
    warn "Or use Docker mode for guaranteed compatibility."
}

_build_magic_macos() {
    warn "Building Magic from source (requires Xcode CLT, Tcl, Cairo)..."
    brew install tcl-tk cairo || true
    local build_dir="$HOME/.local/src/magic"
    mkdir -p "$build_dir"
    if confirm "Clone and build Magic from github.com/RTimothyEdwards/magic?"; then
        git clone --depth 1 https://github.com/RTimothyEdwards/magic.git "$build_dir" || \
        ( cd "$build_dir" && git pull )
        cd "$build_dir"
        ./configure --prefix="$HOME/.local" && make -j"$(sysctl -n hw.logicalcpu)" && make install
        ok "Magic built and installed to ~/.local/bin/magic"
    fi
}

_build_netgen_macos() {
    local build_dir="$HOME/.local/src/netgen"
    mkdir -p "$build_dir"
    if confirm "Clone and build Netgen from github.com/RTimothyEdwards/netgen?"; then
        git clone --depth 1 https://github.com/RTimothyEdwards/netgen.git "$build_dir" || \
        ( cd "$build_dir" && git pull )
        cd "$build_dir"
        ./configure --prefix="$HOME/.local" && make -j"$(sysctl -n hw.logicalcpu)" && make install
        ok "Netgen built and installed to ~/.local/bin/netgen"
    fi
}

# ── Ubuntu / Debian ────────────────────────────────────────────────────────────
install_local_debian() {
    hdr "Ubuntu/Debian Local Install"
    require_root

    info "Updating package lists..."
    sudo apt-get update -q

    info "Installing base dependencies..."
    sudo apt-get install -y --no-install-recommends \
        build-essential git wget curl python3 python3-pip \
        tcl-dev tk-dev libcairo2-dev libx11-dev \
        flex bison libfl2 libreadline-dev \
        libffi-dev libboost-all-dev pkg-config \
        cmake ninja-build swig lld || true

    info "Installing simulation tools..."
    sudo apt-get install -y iverilog gtkwave || true
    # Verilator — prefer newer than what's in apt
    if ! command -v verilator &>/dev/null || [[ "$(verilator --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+')" < "5.0" ]]; then
        info "Installing Verilator 5.x from source..."
        _build_verilator_linux
    else
        ok "Verilator already meets minimum version."
    fi

    info "Installing Yosys..."
    sudo apt-get install -y yosys 2>/dev/null || _build_yosys_linux

    info "Installing SymbiYosys..."
    sudo apt-get install -y yosys-smtbmc symbiyosys 2>/dev/null || {
        pip3 install --user symbiyosys 2>/dev/null || true
        sudo apt-get install -y z3 yices2 boolector 2>/dev/null || true
    }

    info "Installing KLayout..."
    _install_klayout_deb

    info "Installing OpenROAD..."
    _install_openroad_prebuilt_linux || _build_openroad_linux

    info "Installing Magic..."
    sudo apt-get install -y magic 2>/dev/null || _build_magic_linux

    info "Installing Netgen..."
    sudo apt-get install -y netgen 2>/dev/null || _build_netgen_linux

    info "Installing Python utilities (volare, LibreLane)..."
    pip3 install --user volare librelane 2>/dev/null || true

    ok "Debian/Ubuntu local install complete."
    _print_env_export_hint
}

_build_verilator_linux() {
    local src="$HOME/.local/src/verilator"
    mkdir -p "$src"
    git clone --depth 1 https://github.com/verilator/verilator.git "$src" 2>/dev/null || \
    ( cd "$src" && git pull )
    cd "$src"
    autoconf && ./configure --prefix="$HOME/.local"
    make -j"$(nproc)" && make install
    ok "Verilator built → ~/.local/bin/verilator"
}

_build_yosys_linux() {
    warn "Yosys not in apt — building from source..."
    local src="$HOME/.local/src/yosys"
    mkdir -p "$src"
    git clone --depth 1 https://github.com/YosysHQ/yosys.git "$src" 2>/dev/null || \
    ( cd "$src" && git pull )
    cd "$src"
    make config-gcc && make -j"$(nproc)" && sudo make install
    ok "Yosys built."
}

_install_klayout_deb() {
    local os_ver="${OS_VER%%.*}"
    local deb_url=""
    # KLayout provides .deb on their release page; detect Ubuntu major version
    case "$os_ver" in
        24) deb_url="https://www.klayout.org/downloads/Ubuntu-24/klayout_0.29.8-1_amd64.deb" ;;
        22) deb_url="https://www.klayout.org/downloads/Ubuntu-22/klayout_0.29.8-1_amd64.deb" ;;
        20) deb_url="https://www.klayout.org/downloads/Ubuntu-20/klayout_0.29.8-1_amd64.deb" ;;
        *)  deb_url="" ;;
    esac

    if [[ -n "$deb_url" ]]; then
        local deb_file="/tmp/klayout.deb"
        info "Downloading KLayout .deb from klayout.org..."
        wget -q -O "$deb_file" "$deb_url" && \
        sudo dpkg -i "$deb_file" && \
        sudo apt-get install -f -y && \
        ok "KLayout installed." || warn "KLayout .deb install failed — try manually from https://www.klayout.org/build.html"
    else
        warn "KLayout .deb URL not determined for OS version ${OS_VER}."
        warn "Download manually: https://www.klayout.org/build.html"
    fi
}

_install_openroad_prebuilt_linux() {
    # OpenROAD provides prebuilt .deb for Ubuntu
    local or_url="https://github.com/The-OpenROAD-Project/OpenROAD/releases/latest"
    info "Attempting OpenROAD prebuilt package..."
    local latest_deb
    latest_deb=$(curl -s https://api.github.com/repos/The-OpenROAD-Project/OpenROAD/releases/latest \
        | grep "browser_download_url.*ubuntu.*\.deb" | head -1 | cut -d '"' -f 4 || true)
    if [[ -n "$latest_deb" ]]; then
        wget -q -O /tmp/openroad.deb "$latest_deb" && \
        sudo dpkg -i /tmp/openroad.deb && sudo apt-get install -f -y && \
        ok "OpenROAD installed from prebuilt package." && return 0
    fi
    warn "Prebuilt OpenROAD package not found via API."
    return 1
}

_build_openroad_linux() {
    warn "Building OpenROAD from source (takes 30-60 min, needs ~8 GB disk)..."
    if ! confirm "Proceed with OpenROAD source build?"; then
        warn "Skipping OpenROAD. Use Docker mode for easiest install."
        return 0
    fi
    local src="$HOME/.local/src/openroad"
    mkdir -p "$src"
    git clone --recurse-submodules https://github.com/The-OpenROAD-Project/OpenROAD.git "$src" 2>/dev/null || \
    ( cd "$src" && git pull --recurse-submodules )
    cd "$src"
    sudo bash etc/DependencyInstaller.sh
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DCMAKE_BUILD_TYPE=Release
    make -j"$(nproc)" && make install
    ok "OpenROAD built → ~/.local/bin/openroad"
}

_build_magic_linux() {
    local src="$HOME/.local/src/magic"
    mkdir -p "$src"
    git clone --depth 1 https://github.com/RTimothyEdwards/magic.git "$src" 2>/dev/null || \
    ( cd "$src" && git pull )
    cd "$src"
    ./configure --prefix="$HOME/.local" && make -j"$(nproc)" && make install
    ok "Magic built → ~/.local/bin/magic"
}

_build_netgen_linux() {
    local src="$HOME/.local/src/netgen"
    mkdir -p "$src"
    git clone --depth 1 https://github.com/RTimothyEdwards/netgen.git "$src" 2>/dev/null || \
    ( cd "$src" && git pull )
    cd "$src"
    ./configure --prefix="$HOME/.local" && make -j"$(nproc)" && make install
    ok "Netgen built → ~/.local/bin/netgen"
}

# ── Fedora / RHEL ──────────────────────────────────────────────────────────────
install_local_fedora_rhel() {
    hdr "Fedora / RHEL Local Install"
    require_root

    info "Installing base deps..."
    sudo dnf groupinstall -y "Development Tools" || true
    sudo dnf install -y \
        git wget curl python3 python3-pip \
        tcl-devel tk-devel cairo-devel libX11-devel \
        flex bison readline-devel libffi-devel \
        boost-devel cmake ninja-build swig lld || true

    info "Installing simulation tools..."
    sudo dnf install -y iverilog gtkwave || true
    _build_verilator_linux

    info "Installing Yosys..."
    sudo dnf install -y yosys 2>/dev/null || _build_yosys_linux

    info "Installing KLayout..."
    local rpm_url
    rpm_url=$(curl -s https://api.github.com/repos/KLayout/klayout/releases/latest \
        | grep "browser_download_url.*\.rpm" | grep -v debug | head -1 | cut -d '"' -f 4 || true)
    if [[ -n "$rpm_url" ]]; then
        wget -q -O /tmp/klayout.rpm "$rpm_url" && sudo dnf install -y /tmp/klayout.rpm && ok "KLayout installed."
    else
        warn "KLayout RPM not found — download from https://www.klayout.org/build.html"
    fi

    info "Installing Magic and Netgen from source..."
    _build_magic_linux
    _build_netgen_linux

    info "Installing OpenROAD..."
    _build_openroad_linux

    info "Installing Python utilities..."
    pip3 install --user volare librelane || true

    ok "Fedora/RHEL local install complete."
    _print_env_export_hint
}

# ── Arch Linux ─────────────────────────────────────────────────────────────────
install_local_arch() {
    hdr "Arch Linux Local Install"
    require_root

    info "Updating system..."
    sudo pacman -Syu --noconfirm || true

    info "Installing packages from official repos + AUR..."
    sudo pacman -S --noconfirm --needed \
        base-devel git wget curl python python-pip \
        tcl tk cairo libx11 \
        flex bison readline libffi boost cmake ninja swig || true

    # Official packages
    sudo pacman -S --noconfirm --needed \
        iverilog gtkwave yosys verilator || true

    # AUR packages (requires yay or paru)
    local aur_helper=""
    command -v yay  &>/dev/null && aur_helper="yay"
    command -v paru &>/dev/null && aur_helper="paru"

    if [[ -n "$aur_helper" ]]; then
        info "Using AUR helper: ${aur_helper}"
        $aur_helper -S --noconfirm openroad klayout magic netgen symbiyosys || true
    else
        warn "No AUR helper (yay/paru) found. Building AUR packages manually..."
        for pkg in openroad klayout magic netgen; do
            local aur_dir="/tmp/aur_${pkg}"
            git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$aur_dir" && \
            cd "$aur_dir" && makepkg -si --noconfirm && ok "${pkg} installed from AUR." || \
            warn "${pkg} AUR build failed."
        done
    fi

    info "Installing Python utilities..."
    pip3 install --user volare librelane || true

    ok "Arch Linux local install complete."
    _print_env_export_hint
}

# ── PDK install (local via volare) ─────────────────────────────────────────────
install_local_pdks() {
    hdr "Installing Open PDKs via Volare"

    if ! command -v volare &>/dev/null; then
        info "Installing volare..."
        pip3 install --user volare 2>/dev/null || pip3 install volare 2>/dev/null || {
            err "Could not install volare. Install Python 3 + pip first."
            return 1
        }
    fi

    local pdk_dir="${PDK_ROOT:-$HOME/pdk}"
    mkdir -p "$pdk_dir"
    info "PDK_ROOT: ${pdk_dir}"

    echo
    echo "  Supported PDKs:"
    echo "    1) sky130B   — SkyWater 130 nm (recommended)"
    echo "    2) sky130A   — SkyWater 130 nm variant"
    echo "    3) gf180mcuC — GlobalFoundries 180 nm"
    echo "    4) gf180mcuD — GlobalFoundries 180 nm (extended)"
    echo "    5) All of the above"
    echo "    0) Skip"
    echo
    read -r -p "  Select PDK [1-5, 0]: " pdk_choice

    declare -a pdks=()
    case "$pdk_choice" in
        1) pdks=("sky130B") ;;
        2) pdks=("sky130A") ;;
        3) pdks=("gf180mcuC") ;;
        4) pdks=("gf180mcuD") ;;
        5) pdks=("sky130B" "sky130A" "gf180mcuC" "gf180mcuD") ;;
        0) info "Skipping PDKs."; return 0 ;;
        *) warn "Invalid choice."; return 0 ;;
    esac

    for pdk in "${pdks[@]}"; do
        local family="${pdk%[ABCD]}"
        info "Fetching ${pdk} (family: ${family})..."
        PDK_ROOT="$pdk_dir" volare enable --pdk "$family" "$pdk" && \
        ok "${pdk} installed to ${pdk_dir}/${pdk}" || \
        warn "${pdk} install failed — try: PDK_ROOT=${pdk_dir} volare enable --pdk ${family} ${pdk}"
    done
}

# ── Shell profile export hint ──────────────────────────────────────────────────
_print_env_export_hint() {
    local profile="${HOME}/.zshrc"
    [[ "$SHELL" == *bash* ]] && profile="${HOME}/.bashrc"

    echo
    hdr "Recommended Shell Profile Additions"
    echo "  Add the following to ${profile}:"
    echo
    echo "  ${DIM}# EDA Toolchain${RESET}"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo '  export PDK_ROOT="${PDK_ROOT:-$HOME/pdk}"'
    echo '  export OPENROAD_HOME="${OPENROAD_HOME:-$HOME/.local}"'
    echo '  export YOSYS_ROOT="${YOSYS_ROOT:-$HOME/.local}"'
    echo '  export LIBRELANE_ROOT="${LIBRELANE_ROOT:-$HOME/.local}"'
    echo
    if confirm "Write these exports to ${profile} now?"; then
        {
            echo ""
            echo "# EDA Toolchain (added by install_eda_tools.sh)"
            echo 'export PATH="$HOME/.local/bin:$PATH"'
            echo 'export PDK_ROOT="${PDK_ROOT:-$HOME/pdk}"'
            echo 'export OPENROAD_HOME="${OPENROAD_HOME:-$HOME/.local}"'
            echo 'export YOSYS_ROOT="${YOSYS_ROOT:-$HOME/.local}"'
            echo 'export LIBRELANE_ROOT="${LIBRELANE_ROOT:-$HOME/.local}"'
        } >> "$profile"
        ok "Exports written to ${profile}. Run: source ${profile}"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  INTERACTIVE MENU
# ══════════════════════════════════════════════════════════════════════════════

main_menu() {
    local missing
    missing=$(count_missing)

    echo "${BOLD}${CYAN}"
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│                    Installation Options                          │"
    echo "└─────────────────────────────────────────────────────────────────┘${RESET}"
    echo
    echo "  ${BOLD}${missing} tool(s) not yet installed.${RESET}"
    echo

    local docker_note=""
    if $DOCKER_AVAILABLE && $DOCKER_RUNNING; then
        docker_note="${GREEN}(Docker available ✔)${RESET}"
    elif $DOCKER_AVAILABLE; then
        docker_note="${YELLOW}(Docker installed but not running)${RESET}"
    else
        docker_note="${RED}(Docker not found)${RESET}"
    fi

    echo "  ${BOLD}1)${RESET} Docker — all-in-one LibreLane image  ${docker_note}"
    echo "       Pulls ghcr.io/efabless/librelane  (Yosys, OpenROAD, KLayout, Magic, Netgen, …)"
    echo "       Easiest, fully reproducible, no build-from-source needed."
    echo
    echo "  ${BOLD}2)${RESET} Docker — standalone images per tool"
    echo "       Pulls individual containers: OpenROAD, Yosys, Verilator, KLayout"
    echo
    echo "  ${BOLD}3)${RESET} Local install (native packages / source builds)"
    echo "       Installs directly into host OS via ${PKG_MGR} + builds from source as needed."
    echo "       Takes longer; tools available system-wide without Docker."
    echo
    echo "  ${BOLD}4)${RESET} Install / update Open PDKs only"
    echo "       sky130B, sky130A, gf180mcuC, gf180mcuD  via volare"
    echo
    echo "  ${BOLD}5)${RESET} Re-scan environment  (refresh tool status)"
    echo
    echo "  ${BOLD}0)${RESET} Exit"
    echo
    read -r -p "  Enter choice [0-5]: " choice
    echo

    case "$choice" in
        1)
            if ! $DOCKER_AVAILABLE; then
                err "Docker is not installed on this system."
                echo
                echo "  Install Docker first:"
                if [[ "$OS_TYPE" == "macos" ]]; then
                    echo "  → https://docs.docker.com/desktop/mac/install/"
                else
                    echo "  → https://docs.docker.com/engine/install/"
                fi
                echo
                confirm "Return to menu?" && main_menu
            else
                install_docker_librelane
                echo
                if confirm "Also install Open PDKs (via Docker)?"; then
                    install_docker_pdk
                fi
                _print_env_export_hint
            fi
            ;;
        2)
            if ! $DOCKER_AVAILABLE; then
                err "Docker not available. Choose local install (option 3) instead."
                confirm "Return to menu?" && main_menu
            else
                install_docker_standalone
            fi
            ;;
        3)
            echo "  ${YELLOW}Note: local install may require sudo for system packages.${RESET}"
            echo "  Proceed with native install for: ${BOLD}${OS_ID} ${OS_VER}${RESET}"
            echo
            if ! confirm "Continue with local install?"; then
                main_menu; return
            fi
            case "$OS_TYPE" in
                macos)          install_local_macos ;;
                debian)         install_local_debian ;;
                fedora|rhel)    install_local_fedora_rhel ;;
                arch)           install_local_arch ;;
                *)
                    err "Unsupported OS (${OS_TYPE}). Use Docker mode instead."
                    ;;
            esac
            echo
            if confirm "Also install Open PDKs?"; then
                install_local_pdks
            fi
            ;;
        4)
            if $DOCKER_RUNNING; then
                echo "  PDK install mode:"
                echo "    a) via Docker (LibreLane container)"
                echo "    b) via volare directly on host"
                read -r -p "  Choose [a/b]: " pdk_mode
                case "${pdk_mode,,}" in
                    a) install_docker_pdk ;;
                    b) install_local_pdks ;;
                    *) warn "Invalid choice."; main_menu ;;
                esac
            else
                install_local_pdks
            fi
            ;;
        5)
            info "Re-scanning environment..."
            detect_tools
            detect_env_vars
            detect_pdks
            print_dashboard
            main_menu
            ;;
        0)
            echo
            ok "Exiting. Run ${BOLD}source ~/.zshrc${RESET} (or ~/.bashrc) if you updated your shell profile."
            echo
            exit 0
            ;;
        *)
            warn "Invalid choice: '${choice}'"
            main_menu
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

main() {
    echo
    info "Detecting environment..."
    detect_os
    detect_docker
    detect_brew
    detect_tools
    detect_env_vars
    detect_pdks

    print_dashboard
    main_menu
}

main "$@"
