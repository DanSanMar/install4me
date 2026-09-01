#!/usr/bin/env bash

# --- INFORMACIÓN DEL PROYECTO ---
V="2.1.1"
DESCRIPCION="Herramienta de instalación de programas por categorías y fuentes híbridas"
AUTOR="DanSanMar"

# --- CONFIGURACIÓN DE COLORES (Normalizados) ---
RESET='\e[0m'
NEGRITA='\e[1m'
VERDE_BRILLANTE='\e[92m'
VERDE='\e[32m'
AMARILLO='\e[33m'
AZUL='\e[34m'
AZUL_BRILLANTE='\e[94m'
CIAN='\e[36m'
MAGENTA='\e[35m'
ROJO='\e[31m'
ROJO_BRILLANTE='\e[91m'
BLANCO='\e[97m'

# --- CONFIGURACIÓN DE LOGS ---
LOG_FILE="/var/log/install4me.log"
LOG_INFO="INFO"
LOG_WARN="WARN"
LOG_ERR="ERROR"

DATE=$(date +"%d/%m/%Y")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

registrar_log() {
    local NIVEL="${1:-INFO}"
    local MENSAJE="${2}"
    local FECHA
    FECHA=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$FECHA] [$NIVEL] [${SUDO_USER:-$USER}] - $MENSAJE" >> "$LOG_FILE"
}

pintar() { 
    local COLOR="$1" 
    local MENSAJE="$2" 
    echo -e "${COLOR}${MENSAJE}${RESET}"
}

# --- COMPROBACIÓN DE SUDO ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO_BRILLANTE}⚠️ Error: Este script requiere privilegios de root.${RESET}"
    echo -e "${AMARILLO}Prueba con: sudo $0${RESET}"
    exit 1
fi

# Inicializar log
if [ ! -f "$LOG_FILE" ]; then
    umask 027
    touch "$LOG_FILE" 2>/dev/null
    chmod 640 "$LOG_FILE" 2>/dev/null
    registrar_log "$LOG_INFO" "Bitácora inicializada - install4me v$V"
fi

# Detección del gestor de paquetes
Package=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-unknown}"
    
    if [ -n "$VERSION" ]; then
        VERSION="$VERSION"
    elif [ -n "$VERSION_ID" ]; then
        VERSION="$VERSION_ID"
    elif [[ "$OS_ID" == "arch" || "$OS_LIKE" == *"arch"* ]]; then
        VERSION="Rolling Release"
    else
        VERSION="unknown"
    fi
fi

case "$OS_ID" in
    debian|ubuntu|linuxmint|pop|kali|raspbian) Package="apt" ;;
    fedora|rhel|centos|rocky|almalinux)        Package="dnf" ;;
    arch|manjaro|endeavouros|garuda)           Package="pacman" ;;
    opensuse*|suse)                            Package="zypper" ;;
    *)
        if [[ "$OS_LIKE" == *"debian"* ]]; then Package="apt"
        elif [[ "$OS_LIKE" == *"fedora"* ]] || [[ "$OS_LIKE" == *"rhel"* ]]; then Package="dnf"
        elif [[ "$OS_LIKE" == *"arch"* ]]; then Package="pacman"
        elif [[ "$OS_LIKE" == *"suse"* ]]; then Package="zypper"
        elif command -v apt &>/dev/null;    then Package="apt"
        elif command -v dnf &>/dev/null;    then Package="dnf"
        elif command -v pacman &>/dev/null; then Package="pacman"
        elif command -v zypper &>/dev/null; then Package="zypper"
        else Package="unknown"; fi
        ;;
esac

# --- LOGO PROPIO DE INSTALL4ME (VERSIÓN CLEAN SIN BORDES) ---
mostrar_logo() {
    echo -e "${AZUL_BRILLANTE}  ██╗███╗   ██╗███████╗████████╗█████╗  ██╗     ██╗     ███╗   ███╗███████╗${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ████╗ ████║██╔════╝${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     ██╔████╔██║█████╗  ${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██║╚██╔╝██║██╔══╝  ${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗██║ ╚═╝ ██║███████╗${RESET}"
    echo -e "${AZUL_BRILLANTE}  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚══════╝${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${VERDE_BRILLANTE}🚀 INSTALL4ME v${V}${RESET}  -  ${AMARILLO}Sistema:${RESET} ${AZUL}${OS_ID:-"Desconocido"}${RESET}  ${AMARILLO}Gestor:${RESET} ${AZUL}${Package:-"Desconocido"}${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# --- DEFINICIÓN DE PAQUETES POR CATEGORÍA ---
declare -A CATEGORIAS

CATEGORIAS["escritorio"]="
firefox|firefox
chromium|chromium
google-chrome|google-chrome
brave-browser|brave-browser
libreoffice|libreoffice
gimp|gimp
inkscape|inkscape
telegram|telegram-desktop
vlc|vlc
mpv|mpv
"

CATEGORIAS["desarrollo"]="
Visual Studio Code|code
Neovim|neovim
Vim|vim
Git|git
GitHub CLI|gh
Docker|docker
Docker Compose|docker-compose
Node.js|nodejs
npm|npm
Python|python3
pip|python3-pip
OpenJDK 17|openjdk-17-jdk
Go|golang
Rust|rustc
Ruby|ruby
"

CATEGORIAS["sistemas"]="
htop|htop
btop|btop
glances|glances
iotop|iotop
ncdu|ncdu
duf|duf
neofetch|neofetch
inxi|inxi
lshw|lshw
gparted|gparted
"

CATEGORIAS["seguridad"]="
Nmap|nmap
Masscan|masscan
Wireshark|wireshark
Tcpdump|tcpdump
Aircrack-ng|aircrack-ng
Hashcat|hashcat
John the Ripper|john
Hydra|hydra
SQLmap|sqlmap
Nikto|nikto
Metasploit|metasploit-framework
ClamAV|clamav
Fail2ban|fail2ban
"

CATEGORIAS["utilidades"]="
FZF|fzf
Ripgrep|ripgrep
FD|fd-find
Bat|bat
Exa|exa
Zoxide|zoxide
Tmux|tmux
Screen|screen
Ranger|ranger
Midnight Commander|mc
Nano|nano
"

CATEGORIAS["scan4me"]="
Masscan|masscan
Nmap|nmap
Gobuster|gobuster
Feroxbuster|feroxbuster
Nikto|nikto
WPScan|wpscan
Sublist3r|sublist3r
Subfinder|subfinder
Nuclei|nuclei
WhatWeb|whatweb
Dnsrecon|dnsrecon
Enum4linux|enum4linux
Smbclient|smbclient
SNMPwalk|snmp
"

CATEGORIAS["stk"]="
FZF|fzf
Xsltproc|xsltproc
Host|host
Tput|tput
Free|free
Curl|curl
Wget|wget
Tar|tar
Hostname|hostname
JS Interpreter|js
JQ|jq
Rsync|rsync
Crontab|crontab
"

# --- OBTENER NOMBRE / METODO DE INSTALACIÓN ---
get_package_name() {
    local tool="$1"
    
    case "$tool" in
        "code") [[ "$Package" == "pacman" ]] && echo "visual-studio-code-bin" || echo "code" ;;
        "gh") [[ "$Package" == "pacman" ]] && echo "github-cli" || echo "gh" ;;
        "docker") [[ "$Package" == "apt" ]] && echo "docker.io" || echo "docker" ;;
        "python3-pip") [[ "$Package" == "pacman" ]] && echo "python-pip" || echo "python3-pip" ;;
        "openjdk-17-jdk")
            case "$Package" in
                apt) echo "openjdk-17-jdk" ;;
                dnf) echo "java-17-openjdk" ;;
                pacman) echo "jdk17-openjdk" ;;
                *) echo "openjdk-17-jdk" ;;
            esac
            ;;
        "golang") [[ "$Package" == "apt" ]] && echo "golang-go" || echo "go" ;;
        "rustc") [[ "$Package" == "apt" ]] && echo "rustc" || echo "rust" ;;
        "fd-find") [[ "$Package" == "pacman" ]] && echo "fd" || echo "fd-find" ;;
        "crontab") [[ "$Package" == "apt" || "$Package" == "zypper" ]] && echo "cron" || echo "cronie" ;;
        "host")
            case "$Package" in
                apt) echo "bind9-dnsutils" ;;
                pacman) echo "bind" ;;
                *) echo "bind-utils" ;;
            esac
            ;;
        "tput") [[ "$Package" == "apt" ]] && echo "ncurses-bin" || echo "ncurses" ;;
        "free") [[ "$Package" == "pacman" ]] && echo "procps-ng" || echo "procps" ;;
        "hostname") [[ "$Package" == "pacman" ]] && echo "inetutils" || echo "hostname" ;;
        "js")
            case "$Package" in
                pacman) echo "js128" ;;
                apt|*) echo "nodejs" ;;
            esac
            ;;
        "snmp") [[ "$Package" == "apt" ]] && echo "snmp" || echo "net-snmp" ;;
        *) echo "$tool" ;;
    esac
}

# --- DESCARGA SEGURA DESDE GITHUB (Scan4me support) ---
instalar_github_release() {
    local repo=$1
    local binary_name=$2
    local asset_pattern=$3
    local is_tgz=${4:-false}

    echo -e "${AZUL}📥 Descargando $binary_name desde GitHub ($repo)...${RESET}"
    local download_url
    download_url=$(curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep "browser_download_url" \
        | grep -iE "$asset_pattern" \
        | head -n 1 \
        | cut -d '"' -f 4)

    if [[ -z "$download_url" ]]; then
        echo -e "${ROJO}❌ Error al resolver release de GitHub para $binary_name.${RESET}"
        return 1
    fi

    local tmp_file="/tmp/${binary_name}_tmp"
    wget -qO "$tmp_file" "$download_url"

    if [ "$is_tgz" = true ]; then
        tar -xzf "$tmp_file" -C /usr/local/bin/ "$binary_name" 2>/dev/null || tar -xzf "$tmp_file" -C /usr/local/bin/
    else
        unzip -o -q "$tmp_file" -d /tmp/
        mv /tmp/"$binary_name" /usr/local/bin/ 2>/dev/null || true
    fi

    chmod +x "/usr/local/bin/$binary_name"
    rm -f "$tmp_file"
    echo -e "${VERDE}✅ $binary_name instalado en /usr/local/bin/${RESET}"
}

# --- FUNCIÓN MEJORADA DE INSTALACIÓN HÍBRIDA ---
instalar_paquetes() {
    local lista_raw="$1"
    local paquetes_a_instalar=()
    local paquetes_especiales=()

    # Separar paquetes estándar de herramientas especiales (Pip/Gem/Git)
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local nombre_paquete="${line##*|}"

        case "$nombre_paquete" in
            wpscan|feroxbuster|subfinder|nuclei|gobuster|whatweb|sublist3r|enum4linux|dnsrecon)
                paquetes_especiales+=("$nombre_paquete")
                ;;
            *)
                local pkg_real
                pkg_real=$(get_package_name "$nombre_paquete")
                paquetes_a_instalar+=("$pkg_real")
                ;;
        esac
    done <<< "$lista_raw"

    # 1. Actualización e Instalación vía Gestor Nativo
    if [ ${#paquetes_a_instalar[@]} -gt 0 ]; then
        echo -e "\n${AZUL}🔄 Actualizando repositorios ($Package)...${RESET}"
        case "$Package" in
            "apt") apt update -y -qq ;;
            "dnf") dnf makecache ;;
            "pacman") pacman -Sy --noconfirm ;;
            "zypper") zypper refresh ;;
        esac

        echo -e "\n${AZUL}📦 Instalando paquetes nativos...${RESET}"
        for pkg in "${paquetes_a_instalar[@]}"; do
            echo -e "${AZUL}   ➜ Instalando $pkg...${RESET}"
            local status=0
            case "$Package" in
                "apt") apt install -y "$pkg" || status=1 ;;
                "dnf") dnf install -y "$pkg" || status=1 ;;
                "pacman") pacman -S --noconfirm "$pkg" || status=1 ;;
                "zypper") zypper install -y "$pkg" || status=1 ;;
            esac

            if [ $status -eq 0 ]; then
                registrar_log "$LOG_INFO" "Paquete instalado nativo: $pkg"
            else
                registrar_log "$LOG_ERR" "Error al instalar nativo: $pkg"
            fi
        done
    fi

    # 2. Instalación de herramientas especiales (Scan4Me / Redes)
    if [ ${#paquetes_especiales[@]} -gt 0 ]; then
        echo -e "\n${MAGENTA}⚙️ Instalando herramientas especializadas/externas...${RESET}"
        
        # Pre-requisitos
        command -v git &>/dev/null || apt install -y git 2>/dev/null || dnf install -y git 2>/dev/null
        command -v wget &>/dev/null || apt install -y wget 2>/dev/null

        for tool in "${paquetes_especiales[@]}"; do
            case "$tool" in
                "wpscan")
                    echo -e "${AZUL}💎 Instalando WPScan vía RubyGems...${RESET}"
                    gem install wpscan --no-document && registrar_log "$LOG_INFO" "wpscan instalado por gem"
                    ;;
                "feroxbuster")
                    instalar_github_release "epi052/feroxbuster" "feroxbuster" "x86_64-linux-feroxbuster.zip" false
                    ;;
                "nuclei")
                    instalar_github_release "projectdiscovery/nuclei" "nuclei" "linux_amd64.zip" false
                    ;;
                "subfinder")
                    instalar_github_release "projectdiscovery/subfinder" "subfinder" "linux_amd64.zip" false
                    ;;
                "gobuster")
                    instalar_github_release "OJ/gobuster" "gobuster" "Linux_x86_64.tar.gz" true
                    ;;
                "whatweb")
                    rm -rf /opt/whatweb
                    git clone --depth 1 https://github.com/urbanadventurer/WhatWeb.git /opt/whatweb
                    ln -sf /opt/whatweb/whatweb /usr/local/bin/whatweb
                    chmod +x /usr/local/bin/whatweb
                    ;;
                "sublist3r")
                    rm -rf /opt/sublist3r
                    git clone --depth 1 https://github.com/aboul3la/Sublist3r.git /opt/sublist3r
                    pip install --break-system-packages -r /opt/sublist3r/requirements.txt 2>/dev/null || pip install -r /opt/sublist3r/requirements.txt
                    ln -sf /opt/sublist3r/sublist3r.py /usr/local/bin/sublist3r
                    chmod +x /usr/local/bin/sublist3r
                    ;;
                "enum4linux")
                    rm -rf /opt/enum4linux
                    git clone --depth 1 https://github.com/CiscoCXSecurity/enum4linux.git /opt/enum4linux
                    ln -sf /opt/enum4linux/enum4linux.pl /usr/local/bin/enum4linux
                    chmod +x /usr/local/bin/enum4linux
                    ;;
                "dnsrecon")
                    rm -rf /opt/dnsrecon
                    git clone --depth 1 https://github.com/darkoperator/dnsrecon.git /opt/dnsrecon
                    pip install --break-system-packages -r /opt/dnsrecon/requirements.txt 2>/dev/null || pip install -r /opt/dnsrecon/requirements.txt
                    ln -sf /opt/dnsrecon/dnsrecon.py /usr/local/bin/dnsrecon
                    chmod +x /usr/local/bin/dnsrecon
                    ;;
            esac
        done
    fi

    # Habilitar servicios si se procesó cron
    if [[ " ${paquetes_a_instalar[*]} " =~ "cron" ]] || [[ " ${paquetes_a_instalar[*]} " =~ "cronie" ]]; then
        systemctl enable --now cron 2>/dev/null || systemctl enable --now cronie 2>/dev/null || true
    fi

    pintar "$VERDE_BRILLANTE" "\n✔ Proceso de instalación finalizado."
}

# --- FUNCIONES DE ESTILO FZF DE STK2 ---
fzf_estilo() {
    local prompt_text="$1"
    local header_text="$2"
    fzf --ansi \
        --height=15 \
        --reverse \
        --border=rounded \
        --prompt="➤ $prompt_text: " \
        --header="$header_text" \
        --color="border:#00ffff,pointer:#92ff92,header:#5fb2ff"
}

fzf_menu_principal() {
    local host_name=$(hostname 2>/dev/null || cat /etc/hostname)
    local kernel_ver=$(uname -r | cut -d- -f1)

    fzf --ansi \
        --height=15 \
        --layout=reverse \
        --border=rounded \
        --prompt=" Seleccione Menú-❯ " \
        --header="--- P A N E L  D E  I N S T A L A C I Ó N ---" \
        --header-lines=1 \
        --color="border:#5fafd7,header:#af87ff,prompt:#5fb2ff,pointer:#afff00" \
        --preview-window="up:25%:border-bottom" \
        --preview="echo -e '\033[1;36mINFORMACIÓN\033[0m | \033[1;33mFecha:\033[0m $DATE | \033[1;33mHost:\033[0m $host_name | \033[1;33mKernel:\033[0m $kernel_ver'"
}

fzf_seleccion_multiple() {
    local prompt_text="$1"
    local header_text="$2"
    fzf --ansi \
        --multi \
        --height=18 \
        --reverse \
        --border=rounded \
        --prompt="➤ $prompt_text: " \
        --header="$header_text (TAB: Seleccionar | Shift+TAB: Desmarcar)" \
        --color="border:#00ffff,pointer:#92ff92,header:#5fb2ff"
}

# --- MENÚ DE SELECCIÓN DE PROGRAMAS CON FZF (Estilo STK2 con TAB y Ayuda) ---
seleccionar_programas() {
    local cat_key="$1"
    local nombre_cat="$2"
    local raw_data="${CATEGORIAS[$cat_key]}"
    
    local opciones=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local nombre_mostrado="${line%%|*}"
        local paquete="${line##*|}"
        opciones+="$nombre_mostrado ($paquete)\n"
    done <<< "$raw_data"

    local seleccionados
    seleccionados=$(echo -e "$opciones" | fzf_seleccion_multiple "Seleccione programas" "PROGRAMAS - $nombre_cat")
    
    if [ -n "$seleccionados" ]; then
        # Mapear las selecciones devueltas con el formato original de raw_data
        local resultado=""
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            local pkg_name=$(echo "$item" | awk -F'(' '{print $2}' | tr -d ')')
            local line_match=$(echo "$raw_data" | grep "|${pkg_name}$")
            if [ -n "$line_match" ]; then
                resultado+="$line_match\n"
            fi
        done <<< "$seleccionados"
        echo -e "$resultado"
    fi
}

# --- MENÚ DE INSTALACIÓN POR CATEGORÍA ---
menu_categoria() {
    local cat_key="$1"
    local nombre_categoria="$2"
    local raw_data="${CATEGORIAS[$cat_key]}"

    while true; do
        clear
        mostrar_logo

        local opciones_cat="1. 🚀 Instalar TODOS los programas
2. 🎯 Seleccionar individualmente (TAB = Selección múltiple)
3. ↩ Volver"

        local accion
        accion=$(echo -e "$opciones_cat" | fzf_estilo "Acción" "CATEGORÍA: $nombre_categoria")
        
        if [[ $? -ne 0 || "$accion" == *"Volver"* || -z "$accion" ]]; then 
            break 
        fi

        case ${accion:0:1} in
            1)
                instalar_paquetes "$raw_data"
                echo ""
                read -p "Presione Enter para continuar..."
                ;;
            2)
                local seleccionados
                seleccionados=$(seleccionar_programas "$cat_key" "$nombre_categoria")
                if [ -n "$seleccionados" ]; then
                    instalar_paquetes "$seleccionados"
                    echo ""
                    read -p "Presione Enter para continuar..."
                fi
                ;;
        esac
    done
}

# --- MENÚ PRINCIPAL CON ESTILO STK2 ---
menu_principal() {
    while true; do
        clear
        mostrar_logo
        
        opciones="ICONO | CATEGORÍA       | DESCRIPCIÓN
1. 🖥️ | ESCRITORIO      | Navegadores, ofimática, multimedia
2. 🔧 | DESARROLLO      | Editores, compiladores, lenguajes
3. 🛠️ | SISTEMAS        | Monitoreo, administración, diagnóstico
4. 🔒 | SEGURIDAD       | Herramientas de seguridad y auditoría
5. 📦 | UTILIDADES      | Herramientas generales del sistema
6. 🔍 | SCAN4ME         | Herramientas de escaneo y reconocimiento
7. 📋 | STK DEPENDENCIAS| Dependencias del STK Toolkit
8. 🔄 | MODO MASIVO     | Instalar TODAS las categorías
0. ❌ | SALIR           | Control+C"

        seleccion=$(echo -e "$opciones" | fzf_menu_principal)

        if [ $? -ne 0 ] || [ -z "$seleccion" ]; then salir; fi

        case ${seleccion%%.*} in
            1) menu_categoria "escritorio" "Escritorio" ;;
            2) menu_categoria "desarrollo" "Desarrollo" ;;
            3) menu_categoria "sistemas" "Sistemas" ;;
            4) menu_categoria "seguridad" "Seguridad" ;;
            5) menu_categoria "utilidades" "Utilidades" ;;
            6) menu_categoria "scan4me" "Scan4Me" ;;
            7) menu_categoria "stk" "STK Dependencias" ;;
            8) 
                clear
                mostrar_logo
                echo -e "\n${AZUL}🔄 Instalando TODAS las categorías...${RESET}"
                echo -e "${ROJO}⚠️  Esto instalará todos los programas de todas las categorías.${RESET}"
                echo -e "${AMARILLO}¿Está seguro? (s/N): ${RESET}"
                read -r confirm
                if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
                    for cat in escritorio desarrollo sistemas seguridad utilidades scan4me stk; do
                        echo -e "\n${CIAN}📦 Instalando categoría: $cat${RESET}"
                        instalar_paquetes "${CATEGORIAS[$cat]}"
                    done
                    pintar "$VERDE_BRILLANTE" "\n✔ ¡Todas las categorías han sido procesadas!"
                fi
                read -p "Presione Enter para continuar..."
                ;;
            0) salir ;;
        esac
    done
}

# --- CAPTURA DE SEÑALES ---
salir() {
    echo ""
    pintar "$VERDE" "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    pintar "$AZUL" "Saliendo de Install4Me..."
    pintar "$VERDE" "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
}
trap salir SIGINT SIGTERM

# --- VERIFICACIÓN DE FZF ---
if ! command -v fzf &>/dev/null; then
    echo -e "${AMARILLO}⚠️  fzf no está instalado. Instalando...${RESET}"
    case "$Package" in
        "apt") apt update -y && apt install -y fzf ;;
        "dnf") dnf install -y fzf ;;
        "pacman") pacman -Sy --noconfirm fzf ;;
        "zypper") zypper install -y fzf ;;
    esac
    if ! command -v fzf &>/dev/null; then
        echo -e "${ROJO}❌ No se pudo instalar fzf. El script requiere fzf para funcionar correctamente.${RESET}"
        exit 1
    fi
fi

# --- EJECUCIÓN PRINCIPAL ---
menu_principal "$@"