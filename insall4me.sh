#!/bin/bash

# --- INFORMACIÓN DEL PROYECTO ---
V="2.0.0"
DESCRIPCION="Herramienta de instalación de programas por categorías"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

registrar_log() {
    local NIVEL="${1:-INFO}"
    local MENSAJE="${2}"
    local FECHA
    FECHA=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$FECHA] [$NIVEL] [$USER] - $MENSAJE" >> "$LOG_FILE"
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
    URL="${HOME_URL:-unknown}"
    
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

# --- LOGO PROPIO DE INSTALL4ME ---
mostrar_logo() {
    echo -e "${CIAN}  ██████  ████████ ██   ██${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██         ██    ██  ██ ${RESET}"
    echo -e "${AZUL}  ██████     ██    █████  ${RESET}"
    echo -e "${AZUL}       ██    ██    ██  ██ ${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██████     ██    ██   ██${RESET}"
    echo -e "${VERDE_BRILLANTE}  INSTALL4ME - INSTALADOR INTELIGENTE${RESET}"
    echo -e "${AZUL_BRILLANTE}  v${V}${RESET}"
    echo -e "${AZUL}  By: ${AUTOR}${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${AMARILLO}➤ Sistema detectado:${RESET} ${AZUL}${OS_ID:-"Desconocido"}${RESET}"
    echo -e "${AMARILLO}➤ Gestor de paquetes:${RESET} ${AZUL}${Package:-"Desconocido"}${RESET}"
    echo -e "${AMARILLO}➤ Versión:${RESET} ${AZUL}${VERSION:-"Desconocido"}${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# --- DEFINICIÓN DE PAQUETES POR CATEGORÍA ---
# Cada categoría tiene un array con los nombres de los paquetes
# El formato es: "nombre_mostrado|nombre_paquete"

declare -A CATEGORIAS

# Categoría: Escritorio
CATEGORIAS["escritorio"]="
firefox|firefox
chromium|chromium
google-chrome|google-chrome
brave-browser|brave-browser
vivaldi|vivaldi
libreoffice|libreoffice
gimp|gimp
inkscape|inkscape
obsidian|obsidian
discord|discord
telegram|telegram-desktop
vlc|vlc
mpv|mpv
spotify|spotify
"

# Categoría: Desarrollo
CATEGORIAS["desarrollo"]="
Visual Studio Code|code
Cursor AI|cursor
Sublime Text|sublime-text
Atom|atom
Neovim|neovim
Vim|vim
Git|git
GitHub CLI|gh
Docker|docker
Docker Compose|docker-compose
Kubernetes|kubectl
Node.js|nodejs
npm|npm
Python|python3
pip|python3-pip
Java|openjdk-17-jdk
Maven|maven
Gradle|gradle
Go|golang
Rust|rustc
Cargo|cargo
PHP|php
Composer|composer
Ruby|ruby
Gem|rubygems
"

# Categoría: Sistemas
CATEGORIAS["sistemas"]="
htop|htop
btop|btop
glances|glances
nmon|nmon
iotop|iotop
ncdu|ncdu
duf|duf
bashtop|bashtop
bpytop|bpytop
neofetch|neofetch
screenfetch|screenfetch
inxi|inxi
lshw|lshw
lspci|pciutils
lsusb|usbutils
lsblk|util-linux
fdisk|fdisk
cfdisk|cfdisk
parted|parted
gparted|gparted
"

# Categoría: Seguridad
CATEGORIAS["seguridad"]="
Nmap|nmap
Masscan|masscan
Wireshark|wireshark
Tcpdump|tcpdump
Aircrack-ng|aircrack-ng
Hashcat|hashcat
John the Ripper|john
Hydra|hydra
Medusa|medusa
SQLmap|sqlmap
Nikto|nikto
OpenVAS|openvas
Metasploit|metasploit-framework
Burp Suite|burpsuite
OWASP ZAP|zap
ClamAV|clamav
Rkhunter|rkhunter
Chkrootkit|chkrootkit
Lynis|lynis
Fail2ban|fail2ban
"

# Categoría: Utilidades
CATEGORIAS["utilidades"]="
FZF|fzf
Ripgrep|ripgrep
FD|fd-find
Bat|bat
Exa|exa
Zoxide|zoxide
Starship|starship
Tmux|tmux
Screen|screen
Ranger|ranger
Midnight Commander|mc
Nano|nano
Micro|micro
Helix|helix
Zellij|zellij
Yazi|yazi
"

# Categoría: Scan4Me
CATEGORIAS["scan4me"]="
Masscan|masscan
Nmap|nmap
Gobuster|gobuster
Dirb|dirb
Nikto|nikto
WPScan|wpscan
Sublist3r|sublist3r
Subfinder|subfinder
Amass|amass
WhatWeb|whatweb
Wappalyzer|wappalyzer
Dnsrecon|dnsrecon
Enum4linux|enum4linux
Smbclient|smbclient
SNMPwalk|snmp
"

# Categoría: STK Dependencias
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

# --- FUNCIÓN PARA OBTENER NOMBRE DE PAQUETE SEGÚN DISTRO ---
get_package_name() {
    local tool="$1"
    
    case "$tool" in
        "firefox") echo "firefox" ;;
        "chromium") echo "chromium" ;;
        "google-chrome") 
            case "$Package" in
                apt) echo "google-chrome-stable" ;;
                dnf) echo "google-chrome" ;;
                pacman) echo "google-chrome" ;;
                *) echo "google-chrome" ;;
            esac
            ;;
        "brave-browser")
            case "$Package" in
                apt) echo "brave-browser" ;;
                dnf) echo "brave-browser" ;;
                pacman) echo "brave" ;;
                *) echo "brave-browser" ;;
            esac
            ;;
        "code") 
            case "$Package" in
                apt) echo "code" ;;
                dnf) echo "code" ;;
                pacman) echo "visual-studio-code-bin" ;;
                *) echo "code" ;;
            esac
            ;;
        "cursor")
            case "$Package" in
                apt) echo "cursor" ;;
                *) echo "cursor" ;;
            esac
            ;;
        "neovim") echo "neovim" ;;
        "vim") echo "vim" ;;
        "git") echo "git" ;;
        "gh") 
            case "$Package" in
                apt) echo "gh" ;;
                dnf) echo "gh" ;;
                pacman) echo "github-cli" ;;
                *) echo "gh" ;;
            esac
            ;;
        "docker")
            case "$Package" in
                apt) echo "docker.io" ;;
                dnf) echo "docker" ;;
                pacman) echo "docker" ;;
                *) echo "docker" ;;
            esac
            ;;
        "docker-compose") 
            case "$Package" in
                apt) echo "docker-compose" ;;
                dnf) echo "docker-compose" ;;
                pacman) echo "docker-compose" ;;
                *) echo "docker-compose" ;;
            esac
            ;;
        "nodejs") 
            case "$Package" in
                apt) echo "nodejs" ;;
                dnf) echo "nodejs" ;;
                pacman) echo "nodejs" ;;
                *) echo "nodejs" ;;
            esac
            ;;
        "npm") 
            case "$Package" in
                apt) echo "npm" ;;
                dnf) echo "npm" ;;
                pacman) echo "npm" ;;
                *) echo "npm" ;;
            esac
            ;;
        "python3") 
            case "$Package" in
                apt) echo "python3" ;;
                dnf) echo "python3" ;;
                pacman) echo "python" ;;
                *) echo "python3" ;;
            esac
            ;;
        "python3-pip")
            case "$Package" in
                apt) echo "python3-pip" ;;
                dnf) echo "python3-pip" ;;
                pacman) echo "python-pip" ;;
                *) echo "python3-pip" ;;
            esac
            ;;
        "openjdk-17-jdk")
            case "$Package" in
                apt) echo "openjdk-17-jdk" ;;
                dnf) echo "java-17-openjdk" ;;
                pacman) echo "jdk17-openjdk" ;;
                *) echo "openjdk-17-jdk" ;;
            esac
            ;;
        "golang") 
            case "$Package" in
                apt) echo "golang-go" ;;
                dnf) echo "go" ;;
                pacman) echo "go" ;;
                *) echo "golang" ;;
            esac
            ;;
        "rustc") 
            case "$Package" in
                apt) echo "rustc" ;;
                dnf) echo "rust" ;;
                pacman) echo "rust" ;;
                *) echo "rustc" ;;
            esac
            ;;
        "htop") echo "htop" ;;
        "btop") 
            case "$Package" in
                apt) echo "btop" ;;
                dnf) echo "btop" ;;
                pacman) echo "btop" ;;
                *) echo "btop" ;;
            esac
            ;;
        "glances") 
            case "$Package" in
                apt) echo "glances" ;;
                dnf) echo "glances" ;;
                pacman) echo "glances" ;;
                *) echo "glances" ;;
            esac
            ;;
        "nmap") 
            case "$Package" in
                apt) echo "nmap" ;;
                dnf) echo "nmap" ;;
                pacman) echo "nmap" ;;
                *) echo "nmap" ;;
            esac
            ;;
        "masscan") 
            case "$Package" in
                apt) echo "masscan" ;;
                dnf) echo "masscan" ;;
                pacman) echo "masscan" ;;
                *) echo "masscan" ;;
            esac
            ;;
        "gobuster") 
            case "$Package" in
                apt) echo "gobuster" ;;
                dnf) echo "gobuster" ;;
                pacman) echo "gobuster" ;;
                *) echo "gobuster" ;;
            esac
            ;;
        "fzf") echo "fzf" ;;
        "ripgrep") 
            case "$Package" in
                apt) echo "ripgrep" ;;
                dnf) echo "ripgrep" ;;
                pacman) echo "ripgrep" ;;
                *) echo "ripgrep" ;;
            esac
            ;;
        "fd-find")
            case "$Package" in
                apt) echo "fd-find" ;;
                dnf) echo "fd-find" ;;
                pacman) echo "fd" ;;
                *) echo "fd-find" ;;
            esac
            ;;
        "bat")
            case "$Package" in
                apt) echo "bat" ;;
                dnf) echo "bat" ;;
                pacman) echo "bat" ;;
                *) echo "bat" ;;
            esac
            ;;
        "exa") 
            case "$Package" in
                apt) echo "exa" ;;
                dnf) echo "exa" ;;
                pacman) echo "exa" ;;
                *) echo "exa" ;;
            esac
            ;;
        "tmux") 
            case "$Package" in
                apt) echo "tmux" ;;
                dnf) echo "tmux" ;;
                pacman) echo "tmux" ;;
                *) echo "tmux" ;;
            esac
            ;;
        "zoxide") 
            case "$Package" in
                apt) echo "zoxide" ;;
                dnf) echo "zoxide" ;;
                pacman) echo "zoxide" ;;
                *) echo "zoxide" ;;
            esac
            ;;
        "starship") 
            case "$Package" in
                apt) echo "starship" ;;
                dnf) echo "starship" ;;
                pacman) echo "starship" ;;
                *) echo "starship" ;;
            esac
            ;;
        "jq") echo "jq" ;;
        "rsync") echo "rsync" ;;
        "crontab")
            case "$Package" in
                apt) echo "cron" ;;
                *) echo "cronie" ;;
            esac
            ;;
        "host") 
            case "$Package" in
                apt) echo "bind9-dnsutils" ;;
                pacman) echo "bind" ;;
                *) echo "bind-utils" ;;
            esac
            ;;
        "tput")
            if [[ "$Package" == "apt" ]]; then
                echo "ncurses-bin"
            else
                echo "ncurses"
            fi
            ;;
        "free")
            if [[ "$Package" == "pacman" ]]; then
                echo "procps-ng"
            else
                echo "procps"
            fi
            ;;
        "hostname")
            if [[ "$Package" == "pacman" ]]; then
                echo "inetutils"
            else
                echo "hostname"
            fi
            ;;
        "js") 
            case "$Package" in
                pacman) echo "js128" ;;
                apt)    echo "nodejs" ;;
                dnf)    echo "mozjs115" ;;
                *)      echo "nodejs" ;;
            esac
            ;;
        *)
            # Si no está en la lista, devolver el mismo nombre
            echo "$tool"
            ;;
    esac
}

# --- FUNCIÓN DE INSTALACIÓN ---
instalar_paquetes() {
    local -n lista="$1"
    local paquetes_a_instalar=()
    
    # Convertir nombres mostrados a nombres de paquetes reales
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local nombre_mostrado="${line%%|*}"
        local nombre_paquete="${line##*|}"
        local pkg_real=$(get_package_name "$nombre_paquete")
        paquetes_a_instalar+=("$pkg_real")
    done <<< "$lista"
    
    if [ ${#paquetes_a_instalar[@]} -eq 0 ]; then
        pintar "$AMARILLO" "No hay paquetes seleccionados para instalar."
        return
    fi
    
    echo -e "\n${AZUL}🔄 Actualizando repositorios ($Package)...${RESET}"
    case "$Package" in
        "apt") apt update -y ;;
        "dnf") dnf makecache ;;
        "pacman") pacman -Sy ;;
        "zypper") zypper refresh ;;
    esac
    
    echo -e "\n${AZUL}📦 Instalando paquetes...${RESET}"
    for pkg in "${paquetes_a_instalar[@]}"; do
        echo -e "${AZUL}   ➜ $pkg${RESET}"
        case "$Package" in
            "apt") apt install -y "$pkg" ;;
            "dnf") dnf install -y "$pkg" ;;
            "pacman") pacman -S --noconfirm "$pkg" ;;
            "zypper") zypper install -y "$pkg" ;;
        esac
        
        if [ $? -eq 0 ]; then
            registrar_log "$LOG_INFO" "Paquete instalado: $pkg"
        else
            registrar_log "$LOG_ERR" "Error al instalar: $pkg"
        fi
    done
    
    # Habilitar servicios si se instaló crontab
    if [[ " ${paquetes_a_instalar[*]} " =~ " cron " ]] || [[ " ${paquetes_a_instalar[*]} " =~ " cronie " ]]; then
        case "$Package" in
            "apt")    systemctl enable --now cron &>/dev/null ;;
            "pacman") systemctl enable --now cronie &>/dev/null ;;
            "dnf")    systemctl enable --now crond &>/dev/null ;;
            "zypper") systemctl enable --now cron &>/dev/null ;;
        esac
    fi
    
    pintar "$VERDE_BRILLANTE" "\n✔ Instalación completada."
}

# --- MENÚ DE SELECCIÓN DE PROGRAMAS CON FZF ---
seleccionar_programas() {
    local categoria="$1"
    local -n lista="$categoria"
    
    # Preparar opciones para fzf
    local opciones=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local nombre_mostrado="${line%%|*}"
        local nombre_paquete="${line##*|}"
        opciones+="$nombre_mostrado|$nombre_paquete\n"
    done <<< "$lista"
    
    local seleccionados
    seleccionados=$(echo -e "$opciones" | fzf --multi \
        --height=20 \
        --reverse \
        --border=rounded \
        --prompt="➤ Seleccione programas (TAB para múltiple): " \
        --header="Seleccione los programas a instalar" \
        --color="border:#00ffff,pointer:#92ff92,header:#5fb2ff")
    
    if [ -z "$seleccionados" ]; then
        return
    fi
    
    # Construir lista de paquetes seleccionados
    local paquetes_seleccionados=""
    while IFS= read -r sel; do
        [ -z "$sel" ] && continue
        local pkg="${sel##*|}"
        paquetes_seleccionados+="$pkg\n"
    done <<< "$seleccionados"
    
    echo -e "$paquetes_seleccionados"
}

# --- MENÚ DE INSTALACIÓN POR CATEGORÍA ---
menu_categoria() {
    local categoria="$1"
    local nombre_categoria="$2"
    
    clear
    mostrar_logo
    
    echo -e "\n${CIAN}══════════════════════════════════════════════════${RESET}"
    echo -e "${BLANCO} 📦 CATEGORÍA: ${VERDE_BRILLANTE}$nombre_categoria${RESET}"
    echo -e "${CIAN}══════════════════════════════════════════════════${RESET}\n"
    
    # Mostrar opciones de la categoría
    local -n lista="$categoria"
    local opciones=""
    local contador=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local nombre_mostrado="${line%%|*}"
        opciones+="  $contador) $nombre_mostrado\n"
        ((contador++))
    done <<< "$lista"
    
    echo -e "$opciones"
    echo -e "\n  ${AZUL}a)${RESET} Instalar TODOS los programas de esta categoría"
    echo -e "  ${AZUL}s)${RESET} Seleccionar programas individualmente (con FZF)"
    echo -e "  ${AZUL}v)${RESET} Volver al menú principal"
    
    echo -ne "\n${AMARILLO}Seleccione una opción: ${RESET}"
    read -r opcion
    
    case "$opcion" in
        a|A)
            local paquetes_seleccionados="$lista"
            instalar_paquetes "$categoria"
            ;;
        s|S)
            local seleccionados
            seleccionados=$(seleccionar_programas "$categoria")
            if [ -n "$seleccionados" ]; then
                # Convertir selección en formato de lista
                local lista_seleccion=""
                while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    # Buscar el nombre mostrado correspondiente
                    while IFS= read -r line; do
                        [ -z "$line" ] && continue
                        local nombre_paquete="${line##*|}"
                        if [[ "$nombre_paquete" == "$pkg" ]]; then
                            lista_seleccion+="$line\n"
                            break
                        fi
                    done <<< "$lista"
                done <<< "$seleccionados"
                
                # Crear array temporal para instalar
                eval "temp_lista=\"$lista_seleccion\""
                instalar_paquetes temp_lista
            fi
            ;;
        v|V)
            return
            ;;
        *)
            pintar "$ROJO" "Opción no válida."
            sleep 2
            ;;
    esac
    
    echo ""
    read -p "Presione Enter para continuar..."
}

# --- MENÚ PRINCIPAL ---
menu_principal() {
    while true; do
        clear
        mostrar_logo
        
        echo -e "\n${CIAN}══════════════════════════════════════════════════${RESET}"
        echo -e "${BLANCO} 📋 CATEGORÍAS DE PROGRAMAS DISPONIBLES${RESET}"
        echo -e "${CIAN}══════════════════════════════════════════════════${RESET}\n"
        
        echo -e "  ${VERDE}1)${RESET} 🖥️  Escritorio - Navegadores, ofimática, multimedia"
        echo -e "  ${VERDE}2)${RESET} 🔧  Desarrollo - Editores, compiladores, lenguajes"
        echo -e "  ${VERDE}3)${RESET} 🛠️  Sistemas - Monitoreo, administración, diagnóstico"
        echo -e "  ${VERDE}4)${RESET} 🔒  Seguridad - Herramientas de seguridad y auditoría"
        echo -e "  ${VERDE}5)${RESET} 📦  Utilidades - Herramientas generales del sistema"
        echo -e "  ${VERDE}6)${RESET} 🔍  Scan4Me - Herramientas de escaneo y reconocimiento"
        echo -e "  ${VERDE}7)${RESET} 📋  STK Dependencias - Dependencias del STK Toolkit"
        echo -e "  ${VERDE}8)${RESET} 🔄  Instalar TODAS las categorías (Instalación masiva)"
        echo -e "  ${VERDE}0)${RESET} ❌  Salir"
        
        echo -ne "\n${AMARILLO}Seleccione una opción: ${RESET}"
        read -r opcion
        
        case "$opcion" in
            1) menu_categoria "escritorio" "Escritorio" ;;
            2) menu_categoria "desarrollo" "Desarrollo" ;;
            3) menu_categoria "sistemas" "Sistemas" ;;
            4) menu_categoria "seguridad" "Seguridad" ;;
            5) menu_categoria "utilidades" "Utilidades" ;;
            6) menu_categoria "scan4me" "Scan4Me" ;;
            7) menu_categoria "stk" "STK Dependencias" ;;
            8) 
                echo -e "\n${AZUL}🔄 Instalando TODAS las categorías...${RESET}"
                echo -e "${ROJO}⚠️  Esto instalará todos los programas de todas las categorías.${RESET}"
                echo -e "${AMARILLO}¿Está seguro? (s/N): ${RESET}"
                read -r confirm
                if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
                    for cat in escritorio desarrollo sistemas seguridad utilidades scan4me stk; do
                        echo -e "\n${CIAN}📦 Instalando categoría: $cat${RESET}"
                        instalar_paquetes "$cat"
                    done
                    pintar "$VERDE_BRILLANTE" "\n✔ ¡Todas las categorías han sido instaladas!"
                fi
                read -p "Presione Enter para continuar..."
                ;;
            0) 
                pintar "$VERDE" "¡Gracias por usar Install4Me!"
                exit 0
                ;;
            *)
                pintar "$ROJO" "Opción no válida."
                sleep 2
                ;;
        esac
    done
}

# --- CAPTURA DE SEÑALES ---
trap salir SIGINT SIGTERM

salir() {
    echo ""
    pintar "$VERDE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    pintar "$AZUL" "Saliendo de Install4Me..."
    pintar "$VERDE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
}

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