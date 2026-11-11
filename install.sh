#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID == 0 )); then
  echo '[ERROR] Ejecuta como usuario normal; NO uses sudo.' >&2
  exit 1
fi
if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* && "${XDG_CURRENT_DESKTOP:-}" != *Plasma* ]]; then
  echo '[AVISO] Este paquete fue creado para KDE Plasma 6.'
fi
for cmd in qdbus6 kpackagetool6 python3 plasmashell; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] Falta $cmd"; exit 1; }
done
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP='org.ripper.desktop.v3'
BASE="$HOME/.local/share/ripper-desktop-v3"
PLASMAFILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
PKG="$HOME/.local/share/plasma/wallpapers/$APP"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BASE/backups/$STAMP"
mkdir -p "$BACKUP" "$BASE" "$HOME/.local/bin"
if [[ -f "$PLASMAFILE" ]]; then
  cp -a "$PLASMAFILE" "$BACKUP/plasma-org.kde.plasma.desktop-appletsrc"
fi

# Save original wallpaper plugin per containment once so restoring is possible.
if [[ ! -s "$BASE/wallpapers-original.jsonl" ]]; then
  query='var ds=desktops();for(var i=0;i<ds.length;i++){var d=ds[i];print("RIPPER_ORIGINAL:"+JSON.stringify({id:d.id,plugin:d.wallpaperPlugin}));}'
  if output="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$query" 2>&1)"; then
    printf '%s\n' "$output" | python3 -c 'import sys,json
for line in sys.stdin:
    if "RIPPER_ORIGINAL:" not in line: continue
    candidate=line.split("RIPPER_ORIGINAL:",1)[1].strip()
    try:
        value=json.loads(candidate)
        if isinstance(value.get("id"),int) and value.get("plugin"):
            print(json.dumps(value,separators=(",",":")))
    except (ValueError,AttributeError): pass' > "$BASE/wallpapers-original.jsonl"
  fi
fi
if [[ ! -s "$BASE/wallpapers-original.jsonl" ]]; then
  echo '[ERROR] No se pudo guardar la configuración original de fondos. No se aplican cambios.' >&2
  exit 1
fi

# Find only the widgets created by V2 (IDs not present in the pre-V2 backup).
# Never delete a preexisting widget with the same type.
mapfile -t old_backups < <(find "$HOME/.local/share/ripper-desktop" -type f \
 -path '*/multimonitor-backup-*/plasma-org.kde.plasma.desktop-appletsrc' 2>/dev/null | sort)
if [[ ${#old_backups[@]} -gt 0 && -f "$PLASMAFILE" ]]; then
  prev="${old_backups[${#old_backups[@]}-1]}"
  python3 - "$prev" "$PLASMAFILE" "$BACKUP/clean-v2.js" <<'PY'
import pathlib, re, json, sys
section = re.compile(r'^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]$')
allowed = {'org.kde.plasma.digitalclock', 'org.kde.plasma.systemmonitor',
           'org.kde.plasma.mediacontroller'}
def widgets(path):
    current = None
    result = {}
    for line in pathlib.Path(path).read_text(errors='replace').splitlines():
        if line.startswith('['):
            m = section.match(line.strip())
            current = int(m.group(2)) if m else None
        elif current is not None and line.startswith('plugin='):
            result[current] = line.partition('=')[2].strip()
    return result
before, after = widgets(sys.argv[1]), widgets(sys.argv[2])
new_ids = [k for k,v in after.items() if k not in before and v in allowed]
js = 'var ids='+json.dumps(new_ids)+';var ds=desktops();for(var i=0;i<ds.length;i++){var ws=ds[i].widgets();for(var j=0;j<ws.length;j++){var w=ws[j];if(ids.indexOf(w.id)>=0 && '+json.dumps(sorted(allowed))+'.indexOf(w.type)>=0){print("RIPPER: Removing V2 applet "+w.id);w.remove();}}}'
pathlib.Path(sys.argv[3]).write_text(js)
print('Widgets V2 identificados:', new_ids)
PY
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$BACKUP/clean-v2.js")" || true
fi

install -m 755 "$SRC/ripper-v3-stats" "$HOME/.local/bin/ripper-v3-stats"
# Install a package from a staged copy, keeping the shipped source pristine.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$APP/contents"
cp "$SRC/metadata.json" "$STAGE/$APP/metadata.json"
cp -a "$SRC/contents/"* "$STAGE/$APP/contents/"
python3 - "$STAGE/$APP/contents/ui/main.qml" "$HOME/.local/bin/ripper-v3-stats" <<'PY'
from pathlib import Path
import sys
qml = Path(sys.argv[1])
path = str(Path(sys.argv[2]).resolve()).replace('\\', '\\\\').replace('"', '\\"')
text = qml.read_text()
assert '__STATS_COMMAND__' in text
qml.write_text(text.replace('__STATS_COMMAND__', path))
PY

if [[ -f "$PKG/metadata.json" ]]; then
  echo '[INFO] Actualizando fondo RIPPER V3.'
  if ! kpackagetool6 --type Plasma/Wallpaper --upgrade "$STAGE/$APP"; then
    echo '[ERROR] No se pudo actualizar el fondo. Sin cambiar Plasma.' >&2
    exit 1
  fi
else
  if ! kpackagetool6 --type Plasma/Wallpaper --install "$STAGE/$APP"; then
    echo '[ERROR] No se pudo instalar el fondo. Sin cambiar Plasma.' >&2
    exit 1
  fi
fi
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
if ! kpackagetool6 --type Plasma/Wallpaper --list 2>&1 | grep -Fq "$APP"; then
  echo '[ERROR] Plasma no reconoce el paquete nuevo. Se conserva el fondo actual.' >&2
  exit 1
fi

# Switch wallpaper on every Plasma desktop containment, preserving current panels.
JS='var ds=desktops();for(var i=0;i<ds.length;i++){var d=ds[i];d.wallpaperPlugin="org.ripper.desktop.v3";print("RIPPER: pantalla="+d.screen+" escritorio="+d.id);}'
if ! qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS"; then
  echo '[ERROR] No se pudo aplicar mediante Plasma D-Bus.' >&2
  exit 1
fi

cat > "$HOME/.local/bin/ripper-v3-restore" <<'RESTORE'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$HOME/.local/share/ripper-desktop-v3"
FILE="$BASE/wallpapers-original.jsonl"
if [[ ! -s "$FILE" ]]; then
    echo 'No hay una copia de la selección anterior; no se modifica Plasma.'
    exit 1
fi
JS="$(python3 - "$FILE" <<'PY'
import json, pathlib, sys
items=[]
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    try:
        item=json.loads(line)
        if item.get('plugin') and item['plugin'] != 'org.ripper.desktop.v3':
            items.append({'id':int(item['id']), 'plugin':item['plugin']})
    except (ValueError, KeyError, TypeError): pass
print('var settings='+json.dumps(items)+';for(var i=0;i<settings.length;i++){var d=desktopById(settings[i].id);if(d && d.wallpaperPlugin==="org.ripper.desktop.v3"){d.wallpaperPlugin=settings[i].plugin;print("Restaurado escritorio "+d.id);}}')
PY
)"
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS"
echo 'Fondos anteriores restaurados. Se conservaron paneles, terminal y monitores.'
RESTORE
chmod +x "$HOME/.local/bin/ripper-v3-restore"

echo
echo '=========================================='
echo ' RIPPER DESKTOP V3 / INSTALACIÓN FINALIZADA'
echo '=========================================='
echo "Copia de seguridad: $BACKUP"
echo 'Restaurar fondos: ~/.local/bin/ripper-v3-restore'
echo 'No se han modificado paneles ni resoluciones.'
echo 'Si no aparece el fondo, cierra sesión y vuelve a entrar.'
