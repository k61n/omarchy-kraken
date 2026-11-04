#!/bin/bash
# Remove the bar widget, service and plugin link. Saved settings stay in
# ~/.local/state/omarchy-kraken; the cooler keeps its current curve until power-off.
set -uo pipefail

plugin_id=kk.kraken
unit=omarchy-kraken.service

systemctl --user disable --now "$unit" 2>/dev/null
rm -f "$HOME/.config/systemd/user/$unit"
systemctl --user daemon-reload
omarchy plugin disable "$plugin_id"
rm -f "$HOME/.config/omarchy/plugins/$plugin_id"
omarchy-shell shell rescanPlugins >/dev/null
