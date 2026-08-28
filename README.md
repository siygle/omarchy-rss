# Omarchy RSS

Lightweight RSS/Atom notifier plugin for Omarchy.

First version scope:

- Bar widget with unread count
- Popup list of new articles
- Open original article in the browser
- Mark article read / mark all read
- Add and delete feeds from the plugin UI
- Paginated feed listing
- Scheduled refresh in a local daemon
- OPML import/export

## Install

```bash
./install.sh
systemctl --user enable --now omarchy-rss.service
omarchy bar put siygle.rss --after omarchy.clock
```

Make sure `~/.local/bin` is in your PATH.

## CLI

```bash
omarchy-rss daemon
omarchy-rss refresh
omarchy-rss status --json
omarchy-rss feeds --json
omarchy-rss add https://example.com/feed.xml
omarchy-rss delete 1
omarchy-rss articles --json --limit 20
omarchy-rss read 123
omarchy-rss read-all
omarchy-rss import-opml ~/feeds.opml
omarchy-rss export-opml ~/Downloads/omarchy-rss-feeds.opml
```

## Data

- Database: `~/.local/share/omarchy-rss/rss.db`
- Default OPML export: `~/Downloads/omarchy-rss-feeds.opml`

## Notes

The plugin delegates parsing, persistence, scheduling, and OPML handling to the local `omarchy-rss` daemon/CLI. The QML side stays small and only renders state plus invokes commands.
