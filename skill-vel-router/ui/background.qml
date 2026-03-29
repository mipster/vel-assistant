import QtQuick 2.12
import Mycroft 1.0 as Mycroft

Mycroft.Delegate {
    id: root
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    skillBackgroundSource: sessionData.image_url || ""
    skillBackgroundColorOverlay: "transparent"
}
