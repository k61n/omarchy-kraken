import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "kk.kraken"
  ipcTarget: "kk.kraken"

  readonly property string ctl: decodeURIComponent(Qt.resolvedUrl("bin/krakenctl").toString().replace("file://", ""))

  readonly property string fanIcon: String.fromCodePoint(0xF0210)         // md-fan
  readonly property string imageIcon: String.fromCodePoint(0xF02E9)       // md-image
  readonly property string thermometerIcon: String.fromCodePoint(0xF050F) // md-thermometer
  readonly property var profileIcons: ({
    silent: String.fromCodePoint(0xF04B2),     // md-sleep
    auto: String.fromCodePoint(0xF006A),       // md-autorenew
    performance: String.fromCodePoint(0xF04C5) // md-speedometer
  })

  property var status: null
  property string pendingProfile: ""
  property string error: ""
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var sensors: status ? status.sensors : null
  readonly property var profiles: status ? status.profiles : []
  readonly property string activeProfile: pendingProfile !== "" ? pendingProfile : (status ? status.profile : "")
  readonly property var screen: status ? status.screen : ({ mode: "liquid" })
  readonly property bool busy: actionProc.running
  readonly property int changeImageIndex: profiles.length
  readonly property int liquidIndex: profiles.length + 1

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function profileLabel() {
    for (var i = 0; i < profiles.length; i++) {
      if (profiles[i].id === activeProfile) return profiles[i].label
    }
    return ""
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args) {
    if (busy) return
    error = ""
    actionProc.command = [ctl].concat(args)
    actionProc.running = true
  }

  function setProfile(id) {
    if (busy || id === activeProfile) return
    pendingProfile = id
    run(["profile", id])
  }

  // The file chooser takes over from here, so get the panel out of the way.
  function pickImage() {
    close()
    run(["screen", "pick"])
  }

  function showLiquid() {
    run(["screen", "liquid"])
  }

  function activateCursor() {
    if (cursorIndex < profiles.length) setProfile(profiles[cursorIndex].id)
    else if (cursorIndex === changeImageIndex) pickImage()
    else if (cursorIndex === liquidIndex) showLiquid()
  }

  function moveCursor(dx, dy) {
    if (!cursorActive) {
      cursorActive = true
      return
    }
    var inProfiles = cursorIndex < profiles.length
    if (dy > 0 && inProfiles) cursorIndex = changeImageIndex
    else if (dy < 0 && !inProfiles) cursorIndex = 0
    else if (dx !== 0) {
      var first = inProfiles ? 0 : changeImageIndex
      var last = inProfiles ? profiles.length - 1 : liquidIndex
      cursorIndex = Math.max(first, Math.min(last, cursorIndex + dx))
    }
  }

  function hover(index, isHovered) {
    if (!isHovered) return
    cursorActive = true
    cursorIndex = index
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Timer {
    interval: root.opened ? 2000 : 10000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.ctl, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.status = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    // krakenctl only writes to stderr when something failed.
    stderr: StdioCollector {
      onStreamFinished: root.error = text.trim().replace(/^krakenctl: /, "")
    }
    onExited: {
      root.pendingProfile = ""
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.fanIcon
    active: root.status !== null && root.sensors === null
    tooltipText: root.sensors
      ? root.sensors.liquid.toFixed(1) + "°C · " + root.profileLabel()
      : "Kraken not detected"
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "NZXT Kraken"
          meta: root.sensors ? "Liquid " + root.sensors.liquid.toFixed(1) + "°C" : "Cooler not detected"
          detail: root.sensors
            ? "Pump " + root.sensors.pumpRpm + " rpm · Fan " + root.sensors.fanRpm + " rpm"
            : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: root.fanIcon
              color: root.sensors ? root.foreground : root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          visible: root.error !== ""
          width: parent.width
          text: root.error
          textFormat: Text.PlainText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "COOLING PROFILE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          id: profileRow
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: root.profiles.length > 0
            ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length
            : 0

          Repeater {
            model: root.profiles
            Button {
              required property var modelData
              required property int index
              width: profileRow.cellWidth
              iconText: root.profileIcons[modelData.id] || root.fanIcon
              iconSize: Style.font.title
              text: modelData.label
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              active: root.activeProfile === modelData.id
              hasCursor: root.cursorActive && root.cursorIndex === index
              onClicked: root.setProfile(modelData.id)
              onHovered: function(h) { root.hover(index, h) }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "DISPLAY"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          width: parent.width
          spacing: Style.space(12)

          ClippingRectangle {
            id: preview
            width: Style.space(96)
            height: width
            radius: width / 2
            color: "black"

            Text {
              anchors.centerIn: parent
              visible: root.screen.mode === "liquid"
              text: root.sensors ? root.sensors.liquid.toFixed(0) + "°" : root.thermometerIcon
              color: "white"
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Image {
              anchors.fill: parent
              visible: root.screen.mode === "static"
              source: visible ? "file://" + root.screen.path : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: false
            }

            AnimatedImage {
              anchors.fill: parent
              visible: root.screen.mode === "gif"
              source: visible ? "file://" + root.screen.path : ""
              fillMode: Image.PreserveAspectCrop
              playing: visible && root.opened
              cache: false
            }
          }

          Column {
            width: parent.width - preview.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: root.busy ? "Working…"
                : root.screen.mode === "liquid" ? "Liquid temperature"
                : String(root.screen.source || "").split("/").pop()
              textFormat: Text.PlainText
              elide: Text.ElideMiddle
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Button {
              width: parent.width
              iconText: root.imageIcon
              text: "Change image"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === root.changeImageIndex
              onClicked: root.pickImage()
              onHovered: function(h) { root.hover(root.changeImageIndex, h) }
            }

            Button {
              width: parent.width
              iconText: root.thermometerIcon
              text: "Show temperature"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.screen.mode === "liquid"
              hasCursor: root.cursorActive && root.cursorIndex === root.liquidIndex
              onClicked: root.showLiquid()
              onHovered: function(h) { root.hover(root.liquidIndex, h) }
            }
          }
        }
      }
    }
  }
}
