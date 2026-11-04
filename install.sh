#!/bin/bash
# Link this checkout in as an Omarchy shell plugin, add it to the bar, and enable
# the service that reapplies saved settings. Safe to run again.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
plugin_id=kk.kraken
plugin_link=$HOME/.config/omarchy/plugins/$plugin_id
unit_dir=$HOME/.config/systemd/user
unit=omarchy-kraken.service

for tool in liquidctl gdbus omarchy omarchy-shell; do
  command -v "$tool" >/dev/null || { echo "Missing required command: $tool" >&2; exit 1; }
done
/usr/bin/python3 -c 'import PIL' || { echo "Missing python-pillow" >&2; exit 1; }

mkdir -p "$(dirname "$plugin_link")" "$unit_dir"
ln -sfn "$root" "$plugin_link"
omarchy plugin validate "$root"

sed "s|@ROOT@|$root|g" "$root/systemd/$unit" > "$unit_dir/$unit"
systemctl --user daemon-reload
systemctl --user enable "$unit"
systemctl --user restart "$unit"

omarchy-shell shell rescanPlugins >/dev/null
# The rescan is asynchronous, so wait for the shell to see the plugin.
for _ in {1..20}; do
  list=$(omarchy plugin list --json)
  if grep -q "\"id\":\"$plugin_id\"" <<<"$list"; then break; fi
  sleep 0.25
done
if ! /usr/bin/python3 -c '
import json, sys
sys.exit(not any(p["id"] == sys.argv[1] and p["enabled"] for p in json.load(sys.stdin)))
' "$plugin_id" <<<"$list"; then
  omarchy plugin enable "$plugin_id" --after omarchy.tray
fi

echo "Installed. Look for the fan icon in the bar, next to the tray."
