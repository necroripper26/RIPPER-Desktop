#!/usr/bin/env bash
set -Eeuo pipefail
ORIGINAL="$HOME/.local/share/ripper-crimson-mono/original-desktops.json"
[[ -s "$ORIGINAL" ]] || { echo 'No hay respaldo de selección de fondos.' >&2; exit 1; }
JS="$(python3 - "$ORIGINAL" <<'PY'
import sys,json,pathlib
items=json.loads(pathlib.Path(sys.argv[1]).read_text())
print('var orig='+json.dumps(items)+';for(var i=0;i<orig.length;i++){'
      'var d=desktopById(orig[i].id);'
      'if(d && d.wallpaperPlugin==="org.ripper.crimson.mono")d.wallpaperPlugin=orig[i].plugin;}')
PY
)"
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS"
echo 'Fondos anteriores solicitados. Paneles, monitores y Dolphin intactos.'
