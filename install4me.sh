#!/usr/bin/env bash

# --- INFORMACIÓN DEL PROYECTO ---
V="2.1.3 la reforma logo + menú"
DESCRIPCION="Herramienta de instalación de programas por categorías y fuentes híbridas"
AUTOR="DanSanMar"

# --- CONFIGURACIÓN DE COLORES ---
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

mostrar_logo() {
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    # Animación fluida de 0.5 segundos (10 fotogramas)
    for i in "${!frames[@]}"; do
        echo -ne "\033[H" # Mueve el cursor a la esquina superior izquierda sin parpadeos
        echo -e "${AZUL_BRILLANTE}  ┌─────────────────────────────────────────┐${RESET}"
        echo -e "${AZUL_BRILLANTE}  │ ${BLANCO}${NEGRITA}I N S T A L L  4  M E${RESET}${AZUL_BRILLANTE}   [${VERDE_BRILLANTE}${frames[$i]}${AZUL_BRILLANTE}] AutoInstall │${RESET}"
        echo -e "${AZUL_BRILLANTE}  └─────────────────────────────────────────┘${RESET}"
        echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "  ${VERDE_BRILLANTE}🚀 v${V}${RESET} - ${AMARILLO}OS:${RESET} ${AZUL}${OS_ID:-"N/A"}${RESET} | ${AMARILLO}Pkg:${RESET} ${AZUL}${Package:-"N/A"}${RESET}"
        echo -e "${CIAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""
        sleep 0.05
    done
}


# --- DEFINICIÓN DE PAQUETES (FORMATO 2 PARÁMETROS: paquete|descripción) ---
declare -A CATEGORIAS

CATEGORIAS["escritorio"]="
firefox|Navegador web de código abierto rápido y privado
chromium|Navegador web código abierto base de Chrome
google-chrome|Navegador web oficial de Google
brave-browser|Navegador enfocado en privacidad y bloqueo de publicidad
libreoffice|Suite ofimática completa (procesador, tablas, presentaciones)
gimp|Editor de imágenes y manipulación fotográfica avanzado
inkscape|Editor de gráficos vectoriales SVG
telegram|Cliente oficial de la mensajería Telegram
vlc|Reproductor multimedia universal para audio y vídeo
mpv|Reproductor de medios ligero pero potente por línea de comandos
"

CATEGORIAS["desarrollo"]="
code|Editor Visual Studio Code
neovim|Editor de texto extensible basado en Vim
vim|Editor de texto clásico interactivo para terminal
git|Sistema de control de versiones distribuido
gh|Herramienta oficial de línea de comandos para GitHub
docker|Plataforma de despliegue de contenedores de software
docker-compose|Herramienta para definir y ejecutar aplicaciones Docker multicontenedor
nodejs|Entorno de ejecución para JavaScript en el servidor
npm|Gestor de paquetes predeterminado para Node.js
python3|Lenguaje de programación interpretado de propósito general
python3-pip|Gestor de paquetes y librerías para Python
openjdk-17-jdk|Entorno de desarrollo de Java (LTS)
golang|Lenguaje de programación de código abierto compilado y eficiente
rustc|Compilador del lenguaje de programación Rust
ruby|Lenguaje de programación dinámico y orientado a objetos
"

CATEGORIAS["sistemas"]="
htop|Visualizador interactivo de procesos en tiempo real
btop|Monitor de recursos del sistema en terminal con interfaz moderna
glances|Herramienta de monitorización completa en terminal
iotop|Monitor de uso de disco e I/O por proceso
ncdu|Analizador de uso de disco en terminal con interfaz ncurses
duf|Utilidad mejorada para ver el espacio y uso de disco
neofetch|Herramienta para mostrar información del sistema y logo OS
inxi|Script de información completa del hardware y sistema
lshw|Listador detallado del hardware de la máquina
gparted|Editor gráfico de particiones de disco
"

CATEGORIAS["seguridad"]="
nmap|Escáner de redes y auditoría de seguridad de puertos
masscan|Escáner masivo de puertos IP a alta velocidad
wireshark|Analizador de tráfico y protocolos de red
tcpdump|Capturador y analizador de paquetes por línea de comandos
aircrack-ng|Suite de auditoría para redes inalámbricas Wi-Fi
hashcat|Herramienta avanzada de recuperación y cracking de contraseñas
john|Cracker de contraseñas rápido y multisistema
hydra|Herramienta de ataque por fuerza bruta a servicios de red
sqlmap|Herramienta automatizada de detección y explotación de SQLi
nikto|Escáner de vulnerabilidades en servidores web
metasploit-framework|Framework para pruebas de penetración y explotación
clamav|Motor antivirus de código abierto para Linux
fail2ban|Prevención de intrusiones mediante bloqueo de IPs
"

CATEGORIAS["utilidades"]="
fzf|Buscador difuso interactivo por línea de comandos
ripgrep|Buscador de texto ultra rápido en archivos
fd-find|Alternativa simple, rápida y amigable al comando find
bat|Clon de cat con resaltado de sintaxis y manejo de git
exa|Reemplazo moderno para el comando ls con colores y árbol
zoxide|Navegación rápida entre directorios frecuentes (cd mejorado)
tmux|Multiplexor de terminales para sesiones persistentes
screen|Multiplexor de terminal clásico
ranger|Gestor de archivos para terminal con atajos tipo Vim
mc|Gestor de archivos en consola de doble panel
nano|Editor de texto sencillo y directo en consola
"

CATEGORIAS["scan4me"]="
masscan|Escáner masivo de puertos IP a alta velocidad
nmap|Escáner de redes y puertos de alto rendimiento
gobuster|Bruteforce de URLs, directorios y subdominios DNS
feroxbuster|Herramienta rápida de descubrimiento recursivo de contenido web
nikto|Escáner de vulnerabilidades de servidores web
wpscan|Escáner de seguridad especializado en WordPress
sublist3r|Enumeración de subdominios mediante OSINT
subfinder|Descubrimiento pasivo de subdominios rápido
nuclei|Escáner de vulnerabilidades basado en plantillas YAML
whatweb|Reconocimiento de tecnologías web e identificación de CMS
dnsrecon|Herramienta de enumeración y reconocimiento DNS
enum4linux|Herramienta de extracción de datos de equipos SMB/Windows
smbclient|Cliente de consola para acceso a recursos compartidos SMB
snmp|Consultas y extracción de datos vía protocolo SNMP
"

CATEGORIAS["stk"]="
fzf|Buscador difuso interactivo
xsltproc|Procesador de hojas de estilo XSLT
host|Utilidad de búsqueda de nombres de dominio DNS
tput|Herramienta de inicialización y control de terminal
free|Visualizador del uso de memoria RAM y Swap
curl|Cliente de transferencia de datos con sintaxis URL
wget|Descargador de archivos no interactivo desde la web
tar|Utilidad para empaquetar y desempaquetar archivos
hostname|Muestra o configura el nombre del sistema
js|Intérprete de motor JavaScript
jq|Procesador y filtrador de datos JSON por terminal
rsync|Sincronización rápida y eficiente de archivos locales o remotos
crontab|Gestor de tareas programadas en tiempo real
"

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

instalar_paquetes() {
    local lista_raw="$1"
    local paquetes_a_instalar=()
    local paquetes_especiales=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Extraer correctamente los 2 campos (paquete|descripción)
        local nombre_paquete="${line%%|*}"

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

    if [ ${#paquetes_especiales[@]} -gt 0 ]; then
        echo -e "\n${MAGENTA}⚙️ Instalando herramientas especializadas/externas...${RESET}"
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

    if [[ " ${paquetes_a_instalar[*]} " =~ "cron" ]] || [[ " ${paquetes_a_instalar[*]} " =~ "cronie" ]]; then
        systemctl enable --now cron 2>/dev/null || systemctl enable --now cronie 2>/dev/null || true
    fi

    pintar "$VERDE_BRILLANTE" "\n✔ Proceso de instalación finalizado."
}

# --- SELECCIÓN INDIVIDUAL Y DIRECTA CON FZF ---
seleccionar_programas() {
    local cat_key="$1"
    local nombre_cat="$2"
    local raw_data="${CATEGORIAS[$cat_key]}"

    if [ -z "$raw_data" ]; then
        echo -e "\033[31mError: No hay datos para la categoría '$cat_key'\033[0m" >&2
        return 1
    fi

    local seleccionados
    seleccionados=$(echo "$raw_data" | sed '/^[[:space:]]*$/d' | fzf --ansi \
        --multi \
        --height=18 \
        --reverse \
        --border=rounded \
        --delimiter="|" \
        --with-nth=1 \
        --prompt="➤ Seleccione programas: " \
        --header="PROGRAMAS - $nombre_cat (TAB: Marcar | Shift+TAB: Desmarcar)" \
        --color="border:#00ffff,pointer:#92ff92,header:#5fb2ff" \
        --preview-window="right:50%:wrap" \
        --preview='
            echo -e "\033[1;36mDETALLES DEL PROGRAMA\033[0m\n"
            echo -e "\033[1;33m➜\033[0m {2..}"
        ')
    
    if [ -n "$seleccionados" ]; then
        echo "$seleccionados"
    fi
}

menu_categoria() {
    local cat_key="$1"
    local nombre_categoria="$2"
    
    clear
    mostrar_logo
    
    local seleccionados
    seleccionados=$(seleccionar_programas "$cat_key" "$nombre_categoria")
    
    if [ -n "$seleccionados" ]; then
        instalar_paquetes "$seleccionados"
        echo ""
        read -p "Presione Enter para continuar..."
    fi
}

menu_principal() {
    while true; do
        clear
        mostrar_logo
        
        local opciones="1. 🖥️  ESCRITORIO      - Navegadores, ofimática, multimedia
2. 🔧  DESARROLLO      - Editores, compiladores, lenguajes
3. 🛠️  SISTEMAS        - Monitoreo, administración, diagnóstico
4. 🔒  SEGURIDAD       - Herramientas de seguridad y auditoría
5. 📦  UTILIDADES      - Herramientas generales del sistema
6. 🔍  SCAN4ME         - Herramientas de escaneo y reconocimiento
7. 📋  STK DEPENDENCIAS- Dependencias del STK Toolkit
8. 🔄  MODO MASIVO     - Instalar TODAS las categorías
0. ❌  SALIR           - Salir del script"

        local seleccion
        seleccion=$(echo -e "$opciones" | fzf --ansi --height=15 --reverse --border=rounded --prompt=" Seleccione Opción ❯ ")

        [ -z "$seleccion" ] && salir

        local opcion_num
        opcion_num=$(echo "$seleccion" | grep -oE '^[0-9]+')

        case "$opcion_num" in
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
                echo -en "${AMARILLO}¿Está seguro? (s/N): ${RESET}"
                read -r confirm
                if [[ "$confirm" =~ ^[sS]$ ]]; then
                    for cat in escritorio desarrollo sistemas seguridad utilidades scan4me stk; do
                        echo -e "\n${CIAN}📦 Instalando categoría: $cat${RESET}"
                        instalar_paquetes "${CATEGORIAS[$cat]}"
                    done
                    pintar "$VERDE_BRILLANTE" "\n✔ ¡Todas las categorías han sido procesadas!"
                fi
                read -p "Presione Enter para continuar..."
                ;;
            0) salir ;;
            *) echo "Opción no válida"; sleep 1 ;;
        esac
    done
}

salir() {
    echo ""
    pintar "$VERDE" "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    pintar "$AZUL" "Saliendo de Install4Me..."
    pintar "$VERDE" "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
}
trap salir SIGINT SIGTERM

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

menu_principal "$@"