import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    // Plasma Wallpaper settings host uses cfg_ properties to persist values.
    property var configDialog
    property var wallpaperConfiguration: wallpaper.configuration
    property var parentLayout

    property string cfg_VideoPath: ""
    property bool cfg_VideoEnabled: false
    property int cfg_CenterWidth: 38
    property int cfg_PanelOpacity: 70
    property bool cfg_ShowMusic: true
    property bool cfg_ShowCalendar: true
    property bool cfg_ShowNetwork: true
    property bool cfg_ShowPerformance: true

    spacing: 12

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Controls.Label {
            Kirigami.FormData.label: "RIPPER NOVA"
            text: "Calavera a pantalla completa. Activa el video para mostrarlo en el centro."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Controls.TextField {
            id: videoInput
            Kirigami.FormData.label: "Video:"
            Layout.fillWidth: true
            placeholderText: "file:///home/usuario/Vídeos/mi-video.mp4"
            text: page.cfg_VideoPath
            onEditingFinished: page.cfg_VideoPath = text.trim()
        }
        Controls.Button {
            text: "Elegir video…"
            icon.name: "folder-videos"
            onClicked: videoPicker.open()
        }
        Controls.CheckBox {
            text: "Mostrar video central (sin sonido)"
            checked: page.cfg_VideoEnabled
            onToggled: page.cfg_VideoEnabled = checked
        }
        Controls.Label {
            text: "Sin video: Calavera Crimson Ghost ocupa todo el escritorio."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Controls.SpinBox {
            Kirigami.FormData.label: "Ancho central (%):"
            from: 30; to: 48; stepSize: 1
            value: page.cfg_CenterWidth
            onValueModified: page.cfg_CenterWidth = value
        }
        Controls.SpinBox {
            Kirigami.FormData.label: "Opacidad paneles (%):"
            from: 35; to: 95; stepSize: 5
            value: page.cfg_PanelOpacity
            onValueModified: page.cfg_PanelOpacity = value
        }
        Controls.CheckBox {
            text: "Monitor de rendimiento"
            checked: page.cfg_ShowPerformance
            onToggled: page.cfg_ShowPerformance = checked
        }
        Controls.CheckBox {
            text: "Reproductor musical"
            checked: page.cfg_ShowMusic
            onToggled: page.cfg_ShowMusic = checked
        }
        Controls.CheckBox {
            text: "Calendario"
            checked: page.cfg_ShowCalendar
            onToggled: page.cfg_ShowCalendar = checked
        }
        Controls.CheckBox {
            text: "Datos de red"
            checked: page.cfg_ShowNetwork
            onToggled: page.cfg_ShowNetwork = checked
        }
    }

    Item { Layout.fillHeight: true }

    FileDialog {
        id: videoPicker
        title: "Selecciona un video para RIPPER NOVA"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Videos (*.mp4 *.webm *.mkv *.mov *.m4v *.avi)", "Todos los archivos (*)"]
        onAccepted: {
            page.cfg_VideoPath = selectedFile.toString()
            videoInput.text = page.cfg_VideoPath
        }
    }
}
