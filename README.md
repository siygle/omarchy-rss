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
- OPML import/export from the plugin UI

## Install

```bash
./install.sh
systemctl --user enable --now omarchy-rss.service
omarchy bar put siygle.rss --after omarchy.clock
```

Make sure `~/.local/bin` is in your PATH.

## Usage

Everything is handled from the Omarchy widget UI:

- Left click the RSS widget to open the panel
- Articles: open links, refresh, mark all read
- Feeds: paginated subscriptions, refresh one feed, delete feed
- Add: add an RSS/Atom URL
- OPML: import/export an OPML file path

## Data

- Database: `~/.local/share/omarchy-rss/rss.db`
- Default OPML export: `~/Downloads/omarchy-rss-feeds.opml`

## Architecture

The QML plugin renders the UI and talks to a local HTTP daemon at `127.0.0.1:8765`. The daemon owns parsing, persistence, scheduled refresh, and OPML import/export.
