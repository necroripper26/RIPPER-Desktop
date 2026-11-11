#!/usr/bin/env bash
# RIPPER CRIMSON -- independent wallpaper for Plasma 6; safe for existing configurations.
set -Eeuo pipefail

APP='org.ripper.crimson.mono'
SOURCE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKG_DEST="$HOME/.local/share/plasma/wallpapers/$APP"
BASE="$HOME/.local/share/ripper-crimson-mono"
ORIGINAL="$BASE/original-desktops.json"
APPLY=1
VIDEO=''
for arg in "$@"; do
    case "$arg" in
      --no-apply) APPLY=0 ;;
      -h|--help) echo 'Uso: bash install.sh [ruta_video.mp4] [--no-apply]'; exit 0 ;;
      *) if [[ -z "$VIDEO" ]]; then VIDEO="$arg"; else echo "Argumento desconocido: $arg" >&2; exit 1; fi ;;
    esac
done

if (( EUID == 0 )); then echo '[ERROR] Ejecuta como usuario normal, sin sudo.' >&2; exit 1; fi
for command in python3 qdbus6 kpackagetool6 plasmashell; do
    if ! command -v "$command" >/dev/null; then echo "[ERROR] Falta $command" >&2; exit 1; fi
done
[[ -f "$SOURCE/metadata.json" && -f "$SOURCE/contents/ui/main.qml" ]] || {
    echo '[ERROR] Faltan archivos del complemento.' >&2; exit 1;
}
[[ -z "$VIDEO" || -s "$VIDEO" ]] || { echo "[ERROR] No existe el video: $VIDEO" >&2; exit 1; }

mkdir -p "$BASE/backups" "$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BASE/backups/$STAMP"
mkdir -p "$BACKUP"
CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
[[ ! -f "$CONFIG" ]] || cp -a "$CONFIG" "$BACKUP/desktop-appletsrc.bak"

# Save ORIGINAL plugin choices in one JSON output; don't parse concatenated print() calls.
if [[ ! -s "$ORIGINAL" ]]; then
    PRINT_JS='var ds=desktops();var list=[];for(var i=0;i<ds.length;i++){list.push({id:ds[i].id,plugin:ds[i].wallpaperPlugin});}print("RIPPER_CRIMSON_ORIGINAL:"+JSON.stringify(list));'
    RES="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$PRINT_JS")" || {
        echo '[ERROR] Plasma D-Bus no respondió. Ningún fondo modificado.' >&2; exit 1;
    }
    printf '%s' "$RES" | python3 -c '
import sys,json,pathlib
s=sys.stdin.read(); mark="RIPPER_CRIMSON_ORIGINAL:"
if mark not in s: raise SystemExit("ERROR: No se pudo leer el fondo original")
value=json.loads(s.split(mark,1)[1])
if not isinstance(value,list) or not value or not all(isinstance(x,dict) and isinstance(x.get("id"),int) and x.get("plugin") for x in value):
    raise SystemExit("ERROR: Respuesta de Plasma inválida")
out=pathlib.Path(sys.argv[1]);out.write_text(json.dumps(value,ensure_ascii=False))
' "$ORIGINAL" || exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
STAGE="$TMP/$APP"
mkdir -p "$STAGE"
cp "$SOURCE/metadata.json" "$STAGE/metadata.json"
cp -a "$SOURCE/contents" "$STAGE/"
install -m 755 "$SOURCE/ripper-crimson-stats.py" "$HOME/.local/bin/ripper-crimson-stats"
python3 - "$STAGE/contents/ui/main.qml" "$HOME/.local/bin/ripper-crimson-stats" <<'PY'
import sys,json,pathlib
p=pathlib.Path(sys.argv[1]);s=p.read_text();tag='"__STATS_COMMAND__"'
assert s.count(tag)==1, 'No se encontró el comando de estadísticas'
p.write_text(s.replace(tag,json.dumps(str(pathlib.Path(sys.argv[2]).resolve()))))
PY

# Validate before activating. qmllint is included in KDE/Qt packages on Arch.
if command -v qmllint >/dev/null 2>&1; then
    echo '[1/4] Validando QML...'
    if ! qmllint "$STAGE/contents/ui/main.qml" "$STAGE/contents/ui/config.qml" "$STAGE/contents/ui/GlassCard.qml" "$STAGE/contents/ui/MeasureBar.qml"; then
        echo '[ERROR] El validador QML rechazó el complemento. Fondo actual conservado.' >&2
        exit 1
    fi
fi

echo '[2/4] Registrando RIPPER CRIMSON...'
if [[ -f "$PKG_DEST/metadata.json" ]]; then
    cp -a "$PKG_DEST" "$BACKUP/previous-nova-plugin"
    kpackagetool6 --type Plasma/Wallpaper --upgrade "$STAGE"
else
    kpackagetool6 --type Plasma/Wallpaper --install "$STAGE"
fi

install -m 755 "$SOURCE/ripper-crimson-video.sh" "$HOME/.local/bin/ripper-crimson-video"
install -m 755 "$SOURCE/ripper-crimson-restore.sh" "$HOME/.local/bin/ripper-crimson-restore"

if [[ -n "$VIDEO" ]]; then
    echo '[3/4] Seleccionando video del usuario...'
    "$HOME/.local/bin/ripper-crimson-video" "$VIDEO" --only-config
fi

if (( APPLY )); then
    echo '[4/4] Activando en los escritorios detectados...'
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
      'var ds=desktops();for(var i=0;i<ds.length;i++){ds[i].wallpaperPlugin="org.ripper.crimson.mono";}'
else
    echo '[4/4] Instalado, sin cambiar el fondo actual.'
fi

echo
printf 'RIPPER CRIMSON listo. Respaldo: %s\n' "$BACKUP"
echo 'Configurar: clic derecho escritorio > Configurar escritorio y fondo > RIPPER CRIMSON > Elegir video'
echo 'Cambiar video por terminal: ~/.local/bin/ripper-crimson-video /ruta/mi-video.mp4'
echo 'Restaurar fondos anteriores: ~/.local/bin/ripper-crimson-restore'
