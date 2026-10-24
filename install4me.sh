#!/usr/bin/env bash

# --- INFORMACIÓN DEL PROYECTO ---
V="2.2.2"
DESCRIPCION="Herramienta de instalación de programas por categorías y fuentes híbridas"
AUTOR="DanSanMar"

# --- CONFIGURACIÓN DE COLORES EXTENDIDA ---
RESET='\e[0m'
NEGRITA='\e[1m'
VERDE_BRILLANTE='\e[92m'
VERDE='\e[32m'
AMARILLO_BRILLANTE='\e[93m'
AMARILLO='\e[33m'
AZUL_BRILLANTE='\e[94m'
AZUL_CLARO='\e[96m'
AZUL_OSCURO='\e[34m'
AZUL='\e[34m'
CIAN_BRILLANTE='\e[96m'
CIAN='\e[36m'
MAGENTA='\e[35m'
ROJO_BRILLANTE='\e[91m'
ROJO='\e[31m'
BLANCO_NEGRITA='\e[1;97m'
BLANCO='\e[97m'
GRIS_CLARO='\e[37m'

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

obtener_color_unico() {
    local indice=$1
    shift
    local colores_usados=("$@")
    local paleta=(
        "$AZUL_BRILLANTE" "$VERDE_BRILLANTE" "$AMARILLO_BRILLANTE" 
        "$CIAN_BRILLANTE" "$ROJO_BRILLANTE" "$AZUL_CLARO" 
        "$VERDE" "$AMARILLO" "$CIAN" "$ROJO"
    )

    local color_propuesto="${paleta[$((indice % ${#paleta[@]}))]}"

    # Si el color ya se usó en esta iteración, tomamos el siguiente en la paleta
    for usado in "${colores_usados[@]}"; do
        if [[ "$color_propuesto" == "$usado" ]]; then
            color_propuesto="${paleta[$(((indice + 1) % ${#paleta[@]}))]}"
            break
        fi
    done

    echo "$color_propuesto"
}

# Elimina colores ANSI para medir la longitud real visible
medir_texto() {
    local texto="$1"
    echo -e "$texto" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\e\[[0-9;]*[a-zA-Z]//g' | wc -m
}

# Imprime con echo -e añadiendo el margen exacto a la izquierda
imprimir_centrado() {
    local texto="$1"
    local ancho_terminal
    ancho_terminal=$(tput cols 2>/dev/null || echo 80)
    
    local largo_real
    largo_real=$(medir_texto "$texto")
    
    local margen=$(( (ancho_terminal - largo_real) / 2 ))
    [ $margen -lt 0 ] && margen=0
    
    # Genera los espacios del margen de forma limpia
    local espacios=""
    if [ $margen -gt 0 ]; then
        espacios=$(printf '%*s' "$margen" "")
    fi
    
    echo -e "${espacios}${texto}"
}

mostrar_logo() {
    local HORA_ACTUAL SEGUNDOS
    HORA_ACTUAL=$(date +"%H:%M:%S")
    SEGUNDOS=$(date +"%S")

    # Índices base desfasados
    local idx_install=$(( 10#$SEGUNDOS % 10 ))
    local idx_num4=$(( (10#$SEGUNDOS + 3) % 10 ))
    local idx_me=$(( (10#$SEGUNDOS + 6) % 10 ))
    local idx_ver=$(( (10#$SEGUNDOS + 8) % 10 ))

    # Asignación de colores
    local C_INSTALL C_4 C_ME C_VER
    C_INSTALL=$(obtener_color_unico "$idx_install")
    C_4=$(obtener_color_unico "$idx_num4" "$C_INSTALL")
    C_ME=$(obtener_color_unico "$idx_me" "$C_INSTALL" "$C_4")
    C_VER=$(obtener_color_unico "$idx_ver" "$C_INSTALL" "$C_4" "$C_ME")

    # Líneas construidas
    local linea_titulo="${AZUL_BRILLANTE}--- ⚡ ${C_INSTALL}INSTALL${C_4}4${C_ME}ME${RESET} ${AZUL_OSCURO}| ${C_VER}v${V}${RESET} ${AZUL_OSCURO}| ${BLANCO}:${HORA_ACTUAL}: ${AZUL_BRILLANTE}⚡---${RESET}"
    local linea_info="${VERDE_BRILLANTE}OS:${RESET} ${AZUL}${OS_ID:-"N/A"}${RESET} | ${AMARILLO}Pkg:${RESET} ${AZUL}${Package:-"N/A"}${RESET} | ${CIAN}User:${RESET} ${BLANCO}${SUDO_USER:-$USER}${RESET}"
    local linea_divisor="${AZUL_BRILLANTE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Renderizado centrado
    imprimir_centrado "$linea_titulo"
    imprimir_centrado "$linea_info"
    imprimir_centrado "$linea_divisor"
    echo ""
}

# --- DEFINICIÓN DE PAQUETES ---
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

CATEGORIAS["admin4me"]="
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

CATEGORIAS["stop4me"]="
fzf|Buscador difuso interactivo para la gestión y menús
ufw|Cortafuegos simple y gestor de reglas de red
host|Utilidad para resolución DNS inversa de IPs atacantes
awk|Procesador de texto y analizador de métricas en logs
grep|Filtrador de patrones de texto para trazas de tráfico
journalctl|Consultor de registros y eventos del sistema systemd
"

CATEGORIAS["note4me"]="
obsidian|Nota y gestión de conocimiento personal
markdown|Herramientas de edición markdown
"

CATEGORIAS["docker4me"]="
docker|Plataforma de contenedores
docker-compose|Herramienta de orquestación multicontenedor
"

CATEGORIAS["move4me"]="
rsync|Sincronización y transferencia de archivos
rclone|Herramienta de sincronización con almacenamiento en la nube
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

# --- NUEVA FUNCIÓN: INSTALAR GESTORES ADICIONALES ---
menu_gestores_paquetes() {
    while true; do
        clear
        mostrar_logo
        local opciones="1. 🧊 Flatpak + Flathub  - Sistema de paquetes sandbox universal
2. 📦 Snapcraft           - Gestor de paquetes canónico (Ubuntu/Debian/Fedora)
3. 🚀 AppImage Runtime    - Soporte Fuse para ejecutables portátiles
4. 🏹 AUR Helper (yay)    - Para distros basadas en Arch Linux
0. ⬅️ Volver al menú principal"

        local seleccion
        seleccion=$(echo -e "$opciones" | fzf --ansi --height=15 --reverse --border=rounded --prompt=" Seleccione Gestor ❯ ")
        [ -z "$seleccion" ] && return

        local opcion_num
        opcion_num=$(echo "$seleccion" | grep -oE '^[0-9]+')

        case "$opcion_num" in
            1)
                echo -e "${AZUL}📦 Instalando Flatpak...${RESET}"
                case "$Package" in
                    apt) apt update && apt install -y flatpak ;;
                    dnf) dnf install -y flatpak ;;
                    pacman) pacman -S --noconfirm flatpak ;;
                    zypper) zypper install -y flatpak ;;
                esac
                flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
                echo -e "${VERDE}✅ Flatpak configurado con Flathub.${RESET}"
                sleep 2
                ;;
            2)
                echo -e "${AZUL}📦 Instalando Snap...${RESET}"
                case "$Package" in
                    apt) apt update && apt install -y snapd ;;
                    dnf) dnf install -y snapd && systemctl enable --now snapd.socket ;;
                    pacman) pacman -S --noconfirm snapd && systemctl enable --now snapd.socket ;;
                    zypper) zypper install -y snapd && systemctl enable --now snapd ;;
                esac
                ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
                echo -e "${VERDE}✅ Snapd instalado correctamente.${RESET}"
                sleep 2
                ;;
            3)
                echo -e "${AZUL}📦 Instalando soporte FUSE para AppImage...${RESET}"
                case "$Package" in
                    apt) apt update && apt install -y libfuse2 fuse3 ;;
                    dnf) dnf install -y fuse fuse3 ;;
                    pacman) pacman -S --noconfirm fuse2 fuse3 ;;
                    zypper) zypper install -y fuse fuse3 ;;
                esac
                echo -e "${VERDE}✅ Soporte AppImage instalado.${RESET}"
                sleep 2
                ;;
            4)
                if [[ "$Package" != "pacman" ]]; then
                    echo -e "${ROJO}⚠️ 'yay' solo se puede instalar en distribuciones basadas en Arch Linux.${RESET}"
                else
                    echo -e "${AZUL}📦 Instalando dependencias e instalando yay...${RESET}"
                    pacman -S --needed --noconfirm git base-devel
                    local target_user="${SUDO_USER:-$USER}"
                    su - "$target_user" -c "cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"
                    echo -e "${VERDE}✅ Helper AUR 'yay' instalado correctamente.${RESET}"
                fi
                sleep 2
                ;;
            0) return ;;
        esac
    done
}

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

menu_all4me() {
    while true; do
        clear
        mostrar_logo
        local opciones="1. 🔍 SCAN4ME    - Herramientas de escaneo y auditoría
2. ⚙️  ADMIN4ME   - Herramientas de administración de sistemas
3. 🛑 STOP4ME    - Herramientas de seguridad y bloqueo
4. 📝 NOTE4ME    - Notas y documentación
5. 🐳 DOCKER4ME  - Contenedores y orquestación
6. 🔄 MOVE4ME    - Transferencia y sincronización
0. ⬅️ VOLVER     - Volver al menú principal"

        local seleccion
        seleccion=$(echo -e "$opciones" | fzf --ansi --height=18 --reverse --border=rounded --prompt=" Seleccione Opción ❯ ")

        [ -z "$seleccion" ] && return

        local opcion_num
        opcion_num=$(echo "$seleccion" | grep -oE '^[0-9]+')

        case "$opcion_num" in
            1) menu_categoria "scan4me" "Scan4Me" ;;
            2) menu_categoria "admin4me" "Admin4Me" ;;
            3) menu_categoria "stop4me" "Stop4Me" ;;
            4) menu_categoria "note4me" "Note4Me" ;;
            5) menu_categoria "docker4me" "Docker4Me" ;;
            6) menu_categoria "move4me" "Move4Me" ;;
            0) return ;;
            *) echo "Opción no válida"; sleep 1 ;;
        esac
    done
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
6. 🚀  ALL4ME          - Paquetes necesarios incluidos en cada programa personal
7. 🍱  GESTORES PKG    - Instalar Flatpak, Snap, AppImage o AUR (yay)
0. ❌  SALIR           - Salir del script"

        local seleccion
        seleccion=$(echo -e "$opciones" | fzf --ansi --height=18 --reverse --border=rounded --prompt=" Seleccione Opción ❯ ")

        [ -z "$seleccion" ] && salir

        local opcion_num
        opcion_num=$(echo "$seleccion" | grep -oE '^[0-9]+')

        case "$opcion_num" in
            1) menu_categoria "escritorio" "Escritorio" ;;
            2) menu_categoria "desarrollo" "Desarrollo" ;;
            3) menu_categoria "sistemas" "Sistemas" ;;
            4) menu_categoria "seguridad" "Seguridad" ;;
            5) menu_categoria "utilidades" "Utilidades" ;;
            6) menu_all4me ;;
            7) menu_gestores_paquetes ;;
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