import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "siygle.rss"
  ipcTarget: "siygle.rss"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property int unread: 0
  property int feedCount: 0
  property var articles: []
  property var feeds: []
  property string view: "articles"
  property int feedPage: 0
  property string statusText: ""
  property string addUrl: ""
  property string opmlPath: (Quickshell.env("HOME") || "") + "/Downloads/omarchy-rss-feeds.opml"

  readonly property int articleLimit: Math.max(1, parseInt(setting("articleLimit", 20), 10) || 20)
  readonly property int feedPageSize: Math.max(1, parseInt(setting("feedPageSize", 6), 10) || 6)
  readonly property int refreshSeconds: Math.max(10, parseInt(setting("refreshSeconds", 60), 10) || 60)
  readonly property int totalFeedPages: Math.max(1, Math.ceil(feeds.length / feedPageSize))
  readonly property string barLabel: unread > 0 ? "󰓰 " + unread : "󰓰"
  readonly property string tooltipText: unread + " unread RSS articles"

  readonly property string apiBase: "http://127.0.0.1:8765"

  function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
  function jsonArg(obj) { return shellQuote(JSON.stringify(obj)) }
  function runJson(cmd, cb) { jsonProc.callback = cb; jsonProc.command = ["bash", "-lc", cmd]; jsonProc.running = true }
  function runAction(cmd, after) { actionProc.after = after || null; actionProc.command = ["bash", "-lc", cmd]; actionProc.running = true }
  function apiGet(path, cb) { runJson("curl -fsS --max-time 8 " + shellQuote(apiBase + path), cb) }
  function apiPost(path, body, after) { runAction("curl -fsS --max-time 30 -H 'Content-Type: application/json' -X POST --data " + jsonArg(body || {}) + " " + shellQuote(apiBase + path), after) }
  function apiDelete(path, after) { runAction("curl -fsS --max-time 15 -X DELETE " + shellQuote(apiBase + path), after) }

  function refresh() {
    apiGet("/dump?limit=" + articleLimit, function(obj) {
      var s = obj.status || {}
      unread = s.unread || 0
      feedCount = s.feeds || 0
      articles = obj.articles || []
      feeds = obj.feeds || []
      if (feedPage >= totalFeedPages) feedPage = Math.max(0, totalFeedPages - 1)
    })
  }

  function openArticle(articleId, url) {
    runAction("xdg-open " + shellQuote(url) + " >/dev/null 2>&1; curl -fsS --max-time 15 -X POST " + shellQuote(apiBase + "/articles/" + articleId + "/read"), refresh)
  }

  function addFeed() {
    if (addUrl.trim() === "") return
    statusText = "Adding feed..."
    apiPost("/feeds", { url: addUrl }, function() { addUrl = ""; statusText = "Feed added"; view = "feeds"; apiPost("/refresh", {}, refresh) })
  }

  function deleteFeed(id) {
    statusText = "Deleting feed..."
    apiDelete("/feeds/" + id, function() { statusText = "Feed deleted"; refresh() })
  }

  function refreshFeed(id) { statusText = "Refreshing..."; apiPost("/feeds/" + id + "/refresh", {}, function() { statusText = "Refreshed"; refresh() }) }
  function refreshAll() { statusText = "Refreshing..."; apiPost("/refresh", {}, function() { statusText = "Refreshed"; refresh() }) }
  function readAll() { apiPost("/articles/read-all", {}, refresh) }
  function importOpml() { statusText = "Importing OPML..."; apiPost("/opml/import", { path: opmlPath }, function() { statusText = "OPML imported"; refresh() }) }
  function exportOpml() { statusText = "Exporting OPML..."; apiPost("/opml/export", { path: opmlPath }, function() { statusText = "Exported: " + opmlPath; refresh() }) }

  function open() { root.controller.show(); refresh() }
  function openFromHotkey() { root.controller.show(); refresh(); setCenterHoverRevealSuppressed(true) }
  function close() { setCenterHoverRevealSuppressed(false); root.controller.hide() }
  function toggle() { if (root.opened) close(); else openFromHotkey() }
  function closeForPopoutSwitch() { close() }
  function switchPanel(direction) { if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root.barIdentity, direction); return false }
  function setCenterHoverRevealSuppressed(value) { if (root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = value }

  Component.onCompleted: refresh()

  Timer { interval: root.refreshSeconds * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  Process {
    id: jsonProc
    property var callback: null
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { if (jsonProc.callback) jsonProc.callback(JSON.parse(String(text || "[]"))) } catch(e) { root.statusText = "RSS command failed" } } }
  }

  Process {
    id: actionProc
    property var after: null
    onExited: function(exitCode) {
      if (exitCode === 0) {
        if (actionProc.after) actionProc.after()
      } else {
        root.statusText = "Command failed"
        root.refresh()
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refreshAll() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: addField.activeFocus || opmlField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true

        Column {
          id: content
          x: Style.space(16)
          width: parent.width - Style.space(32)
          spacing: Style.space(10)

          Text { text: "RSS  ·  " + root.unread + " unread"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }

          Row { spacing: Style.space(8)
            Button { text: "Articles"; onClicked: root.view = "articles" }
            Button { text: "Feeds"; onClicked: root.view = "feeds" }
            Button { text: "Add"; onClicked: root.view = "add" }
            Button { text: "OPML"; onClicked: root.view = "opml" }
          }

          Text { visible: root.statusText !== ""; text: root.statusText; color: Qt.darker(root.bar.foreground, 1.3); font.family: root.bar.fontFamily }

          Column {
            visible: root.view === "articles"
            width: parent.width
            spacing: Style.space(8)
            Row {
              spacing: Style.space(8)
              Button { text: "Refresh"; onClicked: root.refreshAll() }
              Button { text: "Mark all read"; onClicked: root.readAll() }
            }
            Repeater { model: root.articles
              delegate: Rectangle {
                width: content.width - Style.space(32)
                height: articleCol.implicitHeight + Style.space(12)
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)
                radius: Style.radius.s
                Column {
                  id: articleCol
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(3)
                  Text { text: "[" + modelData.feed_title + "]"; color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; elide: Text.ElideRight; width: parent.width }
                  Text { text: modelData.title; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width }
                  Text { text: modelData.url; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openArticle(modelData.id, modelData.url) }
              }
            }
          }

          Column {
            visible: root.view === "feeds"
            width: parent.width
            spacing: Style.space(8)
            Text {
              text: "Feeds " + (root.feeds.length ? (root.feedPage + 1) + " / " + root.totalFeedPages : "0")
              color: root.bar.foreground
              font.family: root.bar.fontFamily
            }
            Repeater { model: root.feeds.slice(root.feedPage * root.feedPageSize, (root.feedPage + 1) * root.feedPageSize)
              delegate: Rectangle {
                width: content.width - Style.space(32)
                height: feedCol.implicitHeight + Style.space(12)
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)
                radius: Style.radius.s
                Column {
                  id: feedCol
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(4)
                  Text { text: modelData.title + "  ·  " + modelData.unread + " unread"; color: root.bar.foreground; font.family: root.bar.fontFamily; elide: Text.ElideRight; width: parent.width }
                  Text { text: modelData.url; color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                  Text { visible: modelData.last_error; text: "Error: " + modelData.last_error; color: Color.urgent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                  Row {
                    spacing: Style.space(8)
                    Button { text: "Refresh"; onClicked: root.refreshFeed(modelData.id) }
                    Button { text: "Delete"; onClicked: root.deleteFeed(modelData.id) }
                  }
                }
              }
            }
            Row {
              spacing: Style.space(8)
              Button { text: "Prev"; enabled: root.feedPage > 0; onClicked: root.feedPage-- }
              Button { text: "Next"; enabled: root.feedPage < root.totalFeedPages - 1; onClicked: root.feedPage++ }
            }
          }

          Column {
            visible: root.view === "add"
            width: parent.width
            spacing: Style.space(8)
            Text { text: "Add RSS / Atom feed"; color: root.bar.foreground; font.family: root.bar.fontFamily }
            TextField {
              id: addField
              width: parent.width - Style.space(32)
              placeholderText: "https://example.com/feed.xml"
              text: root.addUrl
              onTextChanged: root.addUrl = text
              onAccepted: root.addFeed()
            }
            Button { text: "Add feed"; onClicked: root.addFeed() }
          }

          Column {
            visible: root.view === "opml"
            width: parent.width
            spacing: Style.space(8)
            Text { text: "OPML import / export"; color: root.bar.foreground; font.family: root.bar.fontFamily }
            TextField {
              id: opmlField
              width: parent.width - Style.space(32)
              text: root.opmlPath
              onTextChanged: root.opmlPath = text
            }
            Row {
              spacing: Style.space(8)
              Button { text: "Import"; onClicked: root.importOpml() }
              Button { text: "Export"; onClicked: root.exportOpml() }
            }
          }
        }
      }
    }
  }
}
