#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="siygle.rss"

mkdir -p "$HOME/.local/bin" "$HOME/.config/omarchy/plugins/$plugin_id" "$HOME/.config/systemd/user"
install -m 0755 "$root/bin/omarchy-rss" "$HOME/.local/bin/omarchy-rss"
cp -r "$root/plugin/." "$HOME/.config/omarchy/plugins/$plugin_id/"
cp "$root/systemd/omarchy-rss.service" "$HOME/.config/systemd/user/omarchy-rss.service"
systemctl --user daemon-reload || true

echo "Installed Omarchy RSS."
echo "Next: systemctl --user enable --now omarchy-rss.service"
echo "Then: omarchy bar put siygle.rss --after omarchy.clock"
