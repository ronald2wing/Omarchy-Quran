import QtQuick
import qs.Commons
import "../i18n.js" as I18n

Item {
  id: root

  required property string currentPage
  required property string language
  required property color accentColor
  required property color mutedForeground
  required property color contentForeground
  required property string fontFamily

  signal pageSelected(string page)

  implicitHeight: Style.spacing.controlHeight

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.spacing.lg

    Repeater {
      model: [
        { page: "home",    iconGold: "../assets/icons/home-gold.svg",        iconDark: "../assets/icons/home-dark.svg",        key: "tab.ayat" },
        { page: "quran",   iconGold: "../assets/icons/book-open-gold.svg",   iconDark: "../assets/icons/book-open-dark.svg",   key: "tab.quran" },
        { page: "hadith",  iconGold: "../assets/icons/scroll-text-gold.svg", iconDark: "../assets/icons/scroll-text-dark.svg", key: "tab.hadith" }
      ]
      delegate: Item {
        required property var modelData
        readonly property bool active: root.currentPage === modelData.page

        width: medallionColumn.implicitWidth + Style.spacing.sm * 2
        height: root.implicitHeight

        Column {
          id: medallionColumn
          anchors.centerIn: parent
          spacing: Style.spacing.xxs

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: (active ? Style.font.bodySmall + Style.spacing.md : Style.font.bodySmall + Style.spacing.sm)
            height: width
            radius: width / 2
            color: active ? root.accentColor : "transparent"
            border.width: Style.space(1)
            border.color: active ? root.accentColor : root.mutedForeground
            opacity: active ? 1.0 : 0.65

            Image {
              anchors.centerIn: parent
              source: active ? modelData.iconDark : modelData.iconGold
              // gold icon on active circle, dark icon on inactive
              width: active ? Style.font.bodySmall : Style.font.body
              height: active ? Style.font.bodySmall : Style.font.body
              fillMode: Image.PreserveAspectFit
              opacity: active ? 1.0 : 0.65
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.get(modelData.key, root.language)
            color: active ? root.contentForeground : root.mutedForeground
            opacity: active ? 1.0 : 0.65
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: active
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.pageSelected(modelData.page)
        }
      }
    }
  }
}
