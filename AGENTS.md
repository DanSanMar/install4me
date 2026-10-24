# AGENTS.md

## What this is

Single-file interactive Bash TUI that installs software on Linux by category. Everything lives in `install4me.sh`; there is no build system, test suite, CI, or dependency manifest. Runtime requirements are root, a supported package manager, and `fzf` (auto-installed at startup).

## Verification

- Only static check available: `bash -n install4me.sh`. No shellcheck config, linter, or tests exist.
- Do **not** run the script to "test" changes. It requires root, installs real system packages (`apt`/`dnf`/`pacman`/`zypper`), writes `/var/log/install4me.log`, and needs an interactive TTY (`clear`, `fzf`). Exercise behavior in a disposable VM/container if unavoidable.
- Entrypoint is the bottom of the file: `menu_principal "$@"`.

## Layout of install4me.sh

- `V` (line 4) is the version rendered in the logo; bump it for releases.
- `CATEGORIAS` associative array holds all installable software as `tool|description` lines. The part before `|` is a distro-neutral tool name; the description is rendered by the `fzf` preview. Section keys (`escritorio_navegadores`, `desarrollo_editores`, `sistemas_discos`, etc.) are dispatched by `menu_escritorio`, `menu_desarrollo`, `menu_sistemas`, and `menu_all4me`; `menu_principal` only routes to those section menus. Add a new submenu entry in the matching section function when adding a category key.
- `get_package_name` translates those neutral names to per-manager package names. Add a branch whenever distro names differ (e.g. `code` → `visual-studio-code-bin`, `host` → `bind9-dnsutils`).
- `instalar_paquetes` installs native packages by default. Non-native tools need **two** entries: the `case "$nombre_paquete"` whitelist at the top of the function **and** a matching arm in the `for tool in "${paquetes_especiales[@]}"` case. Missing the whitelist silently routes the tool to the native package manager.
- External installers: `instalar_github_release` resolves the latest GitHub release and hardcodes `x86_64`/`linux_amd64` assets. These paths are not ARM-safe.
- Menu selections are parsed with `grep -oE '^[0-9]+'`, so every menu line must start with `N.`; `0` means back/exit.
- Package-manager detection from `/etc/os-release` sets `Package` to `apt`, `dnf`, `pacman`, `zypper`, or `unknown`. Use it for every new install path.

## Conventions

- Comments, log messages, and all user-facing UI text are Spanish; keep new text Spanish and match the existing icons/emoji style.
- Use the existing ANSI variables plus `pintar` / `imprimir_centrado` / `mostrar_logo` instead of raw escape sequences — `medir_texto` strips ANSI codes so centering stays correct.
- Record installation outcomes with `registrar_log "$LOG_INFO"|"$LOG_ERR" ...`; the log path is hardcoded to `/var/log/install4me.log`.
- Default branch is `Security-Scripts-Bash` (not `main`); origin is `https://github.com/DanSanMar/install4me.git`. Commit messages are Spanish and descriptive.
