import QtQuick 2.12

Image {
    anchors.fill: parent
    source: sessionData.image_url || ""
    fillMode: Image.PreserveAspectCrop
}
