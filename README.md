# install4me

Instalador interactivo por categorías para Linux, escrito en Bash. Muestra menús de terminal con `fzf`, detecta el gestor de paquetes de la distribución e instala software nativo y herramientas externas desde un único script.

Versión actual: **2.2.2**

## Características

- Menús TUI con `fzf`, selección múltiple y vista previa de cada programa.
- Detección automática de `apt`, `dnf`, `pacman` o `zypper` desde `/etc/os-release`.
- Categorías generales: escritorio, desarrollo, sistemas, seguridad y utilidades.
- Submenús **ALL4ME**: `scan4me`, `admin4me`, `stop4me`, `note4me`, `docker4me` y `move4me`.
- Instalación de gestores adicionales: Flatpak + Flathub, Snap, soporte FUSE para AppImage y `yay` (Arch).
- Herramientas que no están en los repositorios se instalan desde GitHub Releases, RubyGems, `pip` o clonando repositorios en `/opt`.
- Registro de instalaciones en `/var/log/install4me.log`.
- Interfaz y mensajes en español.

## Distribuciones compatibles

- Debian, Ubuntu, Linux Mint, Pop!_OS, Kali y Raspbian (`apt`).
- Fedora, RHEL, CentOS, Rocky Linux y AlmaLinux (`dnf`).
- Arch Linux, Manjaro, EndeavourOS y Garuda (`pacman`).
- openSUSE y derivados (`zypper`).

En el resto de distribuciones se intenta detectar el gestor disponible; si no se encuentra ninguno, el script no puede instalar paquetes.

## Requisitos

- Linux con uno de los gestores de paquetes anteriores.
- Privilegios de root (`sudo`).
- `bash`, terminal interactiva y conexión a Internet.
- `fzf` (se instala automáticamente al arrancar si falta).
- Según la categoría: `curl`, `wget`, `git`, `tar`, `unzip`, `pip` y `gem`.

> Las instalaciones desde GitHub Releases usan binarios `x86_64`/`amd64`; no están preparadas para ARM.

## Uso

```bash
git clone https://github.com/DanSanMar/install4me.git
cd install4me
chmod +x install4me.sh
sudo ./install4me.sh
```

También puedes ejecutarlo con `sudo bash install4me.sh`.

Dentro de los menús: `TAB` marca, `Shift+TAB` desmarca, `Enter` confirma y `Esc` vuelve al menú anterior.

## Menú principal

| Opción | Sección |
| --- | --- |
| 1 | Escritorio |
| 2 | Desarrollo |
| 3 | Sistemas |
| 4 | Seguridad |
| 5 | Utilidades |
| 6 | ALL4ME (submenús por perfil) |
| 7 | Gestores de paquetes |
| 0 | Salir |

## Estructura

```text
install4me.sh   # script único: menús, catálogo y lógica de instalación
AGENTS.md       # contexto para agentes y colaboradores
README.md
LICENSE
```

## Añadir programas

1. Añade una línea `herramienta|Descripción` a la categoría correspondiente del array `CATEGORIAS`.
2. Si el nombre del paquete cambia según el gestor, añade la traducción en `get_package_name`.
3. Si la herramienta no está en los repositorios, añádela tanto a la lista de `paquetes_especiales` como a su `case` de instalación en `instalar_paquetes`.

## Registro

Las instalaciones se anotan en `/var/log/install4me.log` con el formato:

```text
[fecha] [NIVEL] [usuario] - mensaje
```

El archivo se crea con permisos `640`.

## Aviso

Este script instala paquetes reales y modifica el sistema. Revísalo antes de ejecutarlo y pruébalo en una máquina virtual o contenedor si solo quieres evaluarlo.

## Licencia

Copyright (C) 2026 DanSanMar.

Distribuido bajo la licencia **GNU General Public License v3.0**. Consulta [LICENSE](LICENSE).
