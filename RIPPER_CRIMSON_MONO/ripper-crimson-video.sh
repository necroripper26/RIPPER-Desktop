#!/usr/bin/env bash
set -Eeuo pipefail
APP='org.ripper.crimson.mono'
if [[ $# -lt 1 || ! -f "$1" ]]; then
  echo 'Uso: ripper-crimson-video /ruta/mi-video.mp4 [--only-config]' >&2
  exit 1
fi
if command -v ffprobe >/dev/null 2>&1; then
  if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_type \
        -of default=noprint_wrappers=1:nokey=1 "$1" | grep -qx 'video'; then
    echo 'ERROR: El archivo no contiene una pista de video reconocible.' >&2
    exit 1
  fi
fi
URL="$(python3 - "$1" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[1]).expanduser().resolve(strict=True).as_uri())
PY
)"
# Produce JavaScript as json-escaped data to prevent injection by unusual filenames.
JS="$(python3 - "$URL" "$APP" <<'PY'
import json,sys
url=json.dumps(sys.argv[1]);app=json.dumps(sys.argv[2])
print('var ds=desktops();for(var i=0;i<ds.length;i++){var d=ds[i];'
      'd.currentConfigGroup=["Wallpaper",'+app+',"General"];'
      'd.writeConfig("VideoPath",'+url+');d.writeConfig("VideoEnabled",true);'
      'd.reloadConfig();}')
PY
)"
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS"
if [[ "${2:-}" != '--only-config' ]]; then
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'var ds=desktops();for(var i=0;i<ds.length;i++){ds[i].wallpaperPlugin="org.ripper.crimson.mono";}'
fi
printf 'Video seleccionado para RIPPER CRIMSON: %s\n' "$1"
