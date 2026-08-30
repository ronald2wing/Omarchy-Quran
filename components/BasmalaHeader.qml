import QtQuick
import qs.Commons

Item {
  id: root

  required property color accentColor
  required property color contentForeground
  required property color panelBackground
  required property string fontFamily
  required property string arabicFontFamily
  required property string language

  signal languageSelected(string lang)

  implicitHeight: basmalaText.implicitHeight + Style.spacing.xs + ruleRect.height

  // Gold basmala centered
  Text {
    id: basmalaText
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    text: "\u0628\u0650\u0633\u0652\u0645\u0650 \u0627\u0644\u0644\u0651\u064e\u0647\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0670\u0646\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650"
    textFormat: Text.PlainText
    color: root.accentColor
    font.family: root.arabicFontFamily
    font.pixelSize: Style.font.displayLarge  // AmiriQuran strokes are thin; large size for spiritual presence
  }

  // Decorative geometric rule below basmala — gold line with center diamond
  Rectangle {
    id: ruleRect
    anchors.top: basmalaText.bottom
    anchors.topMargin: Style.spacing.xs
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width * 0.6
    height: Style.space(1)
    color: root.accentColor
    opacity: 0.4
  }

  // Language toggle — three discrete pill buttons in top-right corner.
  Row {
    anchors.right: parent.right
    anchors.rightMargin: Style.spacing.md
    anchors.verticalCenter: basmalaText.verticalCenter
    spacing: Style.spacing.sm

    Repeater {
      model: [
        { lang: "both",    label: "EN+\u0639" },
        { lang: "english", label: "EN" },
        { lang: "arabic",  label: "\u0639" }
      ]
      delegate: Rectangle {
        width: labelText.implicitWidth + Style.spacing.sm * 2
        height: labelText.implicitHeight + Style.spacing.xs * 2
        radius: Style.cornerRadius / 2
        color: root.language === modelData.lang ? root.accentColor : "transparent"
        border.width: Style.space(1)
        border.color: root.language === modelData.lang ? root.accentColor : "transparent"

        Text {
          id: labelText
          anchors.centerIn: parent
          text: modelData.label
          color: root.language === modelData.lang
            ? root.panelBackground : root.contentForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: root.language === modelData.lang
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.languageSelected(modelData.lang)
        }
      }
    }
  }
}
