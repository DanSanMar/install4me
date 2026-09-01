#!/bin/bash

# --- INFORMACIÓN DEL PROYECTO ---
V="1.0.0"
DESCRIPCION="Herramienta de autoinstalación y gestión de dependencias"
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

# --- LOGO Y ESTILO STK ---
mostrar_logo() {
    echo -e "${CIAN}  ██████  ████████ ██   ██${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██         ██    ██  ██ ${RESET}"
    echo -e "${AZUL}  ██████     ██    █████  ${RESET}"
    echo -e "${AZUL}       ██    ██    ██  ██ ${RESET}"
    echo -e "${AZUL_BRILLANTE}  ██████     ██    ██   ██${RESET}"
    echo -e "${VERDE_BRILLANTE}  INSTALL4ME - STK TOOLKIT    ${RESET}\n${AZUL_BRILLANTE}  v${V}${RESET}"
    echo -e "${AZUL}  By: ${AUTOR}${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${AMARILLO}➤ Sistema detectado:${RESET} ${AZUL}${OS_ID:-"Desconocido"}${RESET}"
    echo -e "${AMARILLO}➤ Gestor de paquetes:${RESET} ${AZUL}${Package:-"Desconocido"}${RESET}"
    echo -e "${AMARILLO}➤ Versión:${RESET} ${AZUL}${VERSION:-"Desconocido"}${RESET}"
    echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

get_package_name() {
    local tool="$1"

    case "$tool" in
        "xsltproc"|"fzf")
            echo "$tool"
            ;;
        "crontab")
            case "$Package" in
                apt) echo "cron" ;;
                *)   echo "cronie" ;;
            esac
            ;;
        "host") 
            case "$Package" in
                apt)    echo "bind9-dnsutils" ;;
                pacman) echo "bind" ;;
                *)      echo "bind-utils" ;;
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
            echo "$tool"
            ;;
    esac
}

install_tools() {
    local tools_to_install=("$@")
    
    echo -e "\n${AZUL}🔄 Actualizando repositorios ($Package)...${RESET}"
    case "$Package" in
        "apt") apt update -y ;;
        "dnf") dnf makecache ;;
        "pacman") pacman -Sy ;;
        "zypper") zypper refresh ;;
    esac

    for tool in "${tools_to_install[@]}"; do
        pkg=$(get_package_name "$tool")
        echo -e "${AZUL}📦 Instalando paquete: $pkg...${RESET}"
        case "$Package" in
            "apt") apt install -y "$pkg" ;;
            "dnf") dnf install -y "$pkg" ;;
            "pacman") pacman -S --noconfirm "$pkg" ;;
            "zypper") zypper install -y "$pkg" ;;
        esac
    done

    if [[ " ${tools_to_install[*]} " =~ " crontab " ]]; then
        case "$Package" in
            "apt")    systemctl enable --now cron &>/dev/null ;;
            "pacman") systemctl enable --now cronie &>/dev/null ;;
            "dnf")    systemctl enable --now crond &>/dev/null ;;
            "zypper") systemctl enable --now cron &>/dev/null ;;
        esac
    fi
}

mostrar_instrucciones() {
    clear
    mostrar_logo
    local pkg_upper
    pkg_upper=$(echo "$Package" | tr '[:lower:]' '[:upper:]')

    echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}"
    echo -e "${BLANCO} 📖 GUÍA DE INSTALACIÓN MANUAL PARA TU SISTEMA (${pkg_upper})${RESET}"
    echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n"

    for tool in "${missing_tools[@]}"; do
        pkg=$(get_package_name "$tool")

        if [[ "$tool" != "$pkg" ]]; then
            echo -e "${AMARILLO}🛠  Comando faltante: ${BLANCO}$tool${AMARILLO} (Paquete: ${BLANCO}$pkg${AMARILLO})${RESET}"
        else
            echo -e "${AMARILLO}🛠  Herramienta: ${BLANCO}$tool${RESET}"
        fi

        case "$Package" in
            pacman)
                echo -e "   ${VERDE}✔ Comando:${RESET} pacman -S $pkg"
                ;;
            apt|dnf|zypper)
                echo -e "   ${VERDE}✔ Comando:${RESET} $Package install -y $pkg"
                ;;
            *)
                echo -e "   ${VERDE}✔ Comando:${RESET} Usa el gestor de tu sistema para instalar: $pkg"
                ;;
        esac
        echo -e "${AZUL}--------------------------------------------------${RESET}"
    done
}

dependencies=(fzf xsltproc host tput free curl wget tar hostname js jq rsync crontab)

check_dependencies() {
    missing_tools=()
    local js_executables=(js js128 js115 qjs gjs node nodejs)

    for tool in "${dependencies[@]}"; do
        if [[ "$tool" == "js" ]]; then
            local found_js=false
            for exe in "${js_executables[@]}"; do
                if command -v "$exe" &>/dev/null; then
                    found_js=true
                    break
                fi
            done
            [[ "$found_js" == false ]] && missing_tools+=("js")
        else
            if ! command -v "$tool" &>/dev/null; then
                missing_tools+=("$tool")
            fi
        fi
    done
}

trap salir SIGINT SIGTERM

salir() {
    echo ""
    pintar "$VERDE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    pintar "$AZUL" "Saliendo de install4me..."
    pintar "$VERDE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
}

main() {
    clear
    mostrar_logo

    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        pintar "$ROJO" "❌ No hay conexión a internet. Algunas instalaciones podrían fallar."
    fi

    check_dependencies

    if [ ${#missing_tools[@]} -eq 0 ]; then
        pintar "$VERDE_BRILLANTE" "✔ ¡Todas las dependencias del ecosistema STK están instaladas!"
        registrar_log "$LOG_INFO" "Comprobación completada: Todas las dependencias presentes."
        echo ""
        exit 0
    fi

    echo -e "${ROJO}❌ Herramientas no encontradas: ${BLANCO}${missing_tools[*]}${RESET}\n"
    echo -e "${CIAN}¿Qué deseas hacer?${RESET}"
    echo -e "   ${BLANCO}s) Intento de instalación automática${RESET}"
    echo -e "   ${BLANCO}i) Mostrar instrucciones de instalación manual${RESET}"
    echo -e "   ${BLANCO}n) Omitir y salir${RESET}"
    echo -ne "\n${AMARILLO}Selecciona una opción: ${RESET}"
    read -r confirm

    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        install_tools "${missing_tools[@]}"
        check_dependencies

        if ! command -v js &>/dev/null; then
            js_candidates=(js128 js115 qjs gjs node nodejs)
            for target in "${js_candidates[@]}"; do
                if command -v "$target" &>/dev/null; then
                    target_path=$(command -v "$target")
                    echo -e "${AMARILLO}🔗 Creando enlace de compatibilidad para 'js' -> $target_path${RESET}"
                    ln -sf "$target_path" /usr/local/bin/js
                    break
                fi
            done
        fi

        if ! command -v fzf &>/dev/null; then
            echo -e "${ROJO}❌ Error crítico: fzf no se pudo instalar o no está en el PATH.${RESET}"
            registrar_log "$LOG_ERR" "Error crítico: fzf no pudo ser instalado."
            exit 1
        fi

        if ! command -v js &>/dev/null; then
            echo -e "${AMARILLO}⚠️ Advertencia: El intérprete 'js' no se encontró o requiere un alias en el PATH.${RESET}"
            registrar_log "$LOG_WARN" "Dependencia 'js' no localizada tras la instalación."
        fi

        if [ ${#missing_tools[@]} -gt 0 ]; then
            echo -e "${ROJO}⚠️ Advertencia: Aún faltan herramientas: ${missing_tools[*]}.${RESET}"
        else
            pintar "$VERDE_BRILLANTE" "\n✔ ¡Todas las dependencias se instalaron con éxito!"
            registrar_log "$LOG_INFO" "Todas las dependencias fueron instaladas con éxito."
        fi

    elif [[ "$confirm" == "i" || "$confirm" == "I" ]]; then
        mostrar_instrucciones
    else
        pintar "$AMARILLO" "\nProceso omitido por el usuario."
    fi
}

main "$@"