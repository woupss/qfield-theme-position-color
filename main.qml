import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import org.qfield
import org.qgis
import Theme

import "."

Item {
    id: plugin
    property var mainWindow: iface.mainWindow()

    // --- 0. SYSTÈME DE TRADUCTION SANS FICHIER .TS ---
    
    // Détection de la langue (ex: "fr_FR" devient "fr", "en_US" devient "en")
    property string currentLang: Qt.locale().name.substring(0, 2)

    // Dictionnaire des textes
    property var translations: {
        "pos_point":   { "en": "Pos. (Point)",   "fr": "Pos. (Point)" },
        "center_pt":   { "en": "Center point",   "fr": "Point central" },
        "pos_bg":      { "en": "Pos. (Backgr.)", "fr": "Pos. (Fond)" },
        "white_halo":  { "en": "White halo",     "fr": "Halo blanc" },
        "acc_high":    { "en": "Acc. (High)",    "fr": "Préc. (Top)" },
        "green_circ":  { "en": "Green circle",   "fr": "Cercle vert" },
        "acc_avg":     { "en": "Acc. (Avg.)",    "fr": "Préc. (Moy.)" },
        "orange_circ": { "en": "Orange circle",  "fr": "Cercle orange" },
        "acc_low":     { "en": "Acc. (Low)",     "fr": "Préc. (Mauv.)" },
        "red_circ":    { "en": "Red circle",     "fr": "Cercle rouge" },
        "gps_colors":  { "en": "GPS Colors",     "fr": "Couleurs GPS" },
        "pos_tint":    { "en": "Position Tint",  "fr": "Teinte Position" },
        "reset":       { "en": "Reset",          "fr": "Réinitialiser" },
        "apply":       { "en": "Apply",          "fr": "Appliquer" }
    }

    // Fonction helper pour récupérer le texte
    function tr(key) {
        var t = translations[key];
        if (t) {
            // Si c'est "fr", on renvoie le français, sinon l'anglais par défaut
            return (currentLang === "fr") ? t.fr : t.en;
        }
        return key; // Retourne la clé si traduction manquante
    }

    // --- 1. CONFIGURATION ---
    // On utilise tr() ici. Note: comme c'est une propriété var, 
    // elle est évaluée à la création. Si on change de langue à chaud, il faut recharger.
    property var positionColorConfig: ({
        "positionColor": { "name": tr("pos_point"), "desc": tr("center_pt") },
        "positionBackgroundColor": { "name": tr("pos_bg"), "desc": tr("white_halo") },
        "accuracyExcellent": { "name": tr("acc_high"), "desc": tr("green_circ") },
        "accuracyTolerated": { "name": tr("acc_avg"), "desc": tr("orange_circ") },
        "accuracyBad": { "name": tr("acc_low"), "desc": tr("red_circ") }
    })
    
    // --- VALEURS PAR DÉFAUT (Bleu standard) ---
    property var defaultColors: ({
        "positionColor": "#3388FF",           
        "positionBackgroundColor": "#FFFFFF", 
        "accuracyExcellent": "#4CAF50",       
        "accuracyTolerated": "#FF9800",       
        "accuracyBad": "#F44336"              
    })

    property var colorKeys: Object.keys(positionColorConfig)

    // --- 2. SAUVEGARDE ---
    Settings {
        id: themeSettings
        property string jsonColors: "{}" 
    }

    // --- 3. FONCTION D'APPLICATION ---
    function applyColorChange(key, hexValue) {
        try {
            if (key === undefined || key === "") return;
            var currentJson = themeSettings.jsonColors || "{}";
            var colorsObj = JSON.parse(currentJson);
            
            colorsObj[key] = hexValue;
            Theme.applyColors(colorsObj);
            themeSettings.jsonColors = JSON.stringify(colorsObj);
        } catch (e) {
            console.log("Erreur application couleur: " + e);
        }
    }

    // --- 4. BOUTON TOOLBAR ---
    QfToolButton {
        id: openColorsBtn
        iconSource: 'icon.svg'
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true
        ToolTip.visible: pressed
        ToolTip.text: plugin.tr("gps_colors") // Utilisation de tr()
        onClicked: positionColorDialog.open()
    }

    // --- 5. DIALOGUE ---
    Dialog {
        id: positionColorDialog
        modal: true
        visible: false
        
        parent: plugin.mainWindow.contentItem
        anchors.centerIn: parent 
        width: Math.min(500, parent.width * 0.95)

        background: Rectangle {
            color: Theme.mainBackgroundColor 
            radius: 8
            border.color: Theme.mainColor
            border.width: 2
        }

        contentItem: ColumnLayout {
            id: mainLayout
            spacing: 10
            
            // TITRE
            Label {
                text: plugin.tr("pos_tint") // Utilisation de tr()
                font.bold: true
                font.pixelSize: 18
                color: Theme.mainTextColor 
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                Layout.bottomMargin: 5
            }

            ScrollView {
                id: listScrollView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(listContent.implicitHeight, plugin.mainWindow.height * 0.6)
                clip: true

                GridLayout {
                    id: listContent
                    width: listScrollView.availableWidth
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: plugin.colorKeys
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            
                            color: "transparent"
                            border.color: Theme.controlBorderColor
                            border.width: 1
                            radius: 6

                            property string currentKey: modelData
                            property var itemConfig: plugin.positionColorConfig[modelData]
                            
                            property string displayColor: {
                                var c = Theme[modelData];
                                return c ? c.toString() : "#000000";
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: colorPicker.open()
                                z: 0 
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                // 1. Cercle couleur
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: displayColor
                                    border.color: Theme.controlBorderColor
                                    border.width: 1
                                    MouseArea { anchors.fill: parent; onClicked: colorPicker.open() }
                                }

                                // 2. Textes
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { 
                                        text: itemConfig.name // Déjà traduit via positionColorConfig
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: Theme.mainTextColor 
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Label { 
                                        text: itemConfig.desc // Déjà traduit via positionColorConfig
                                        font.pixelSize: 10
                                        color: Theme.secondaryTextColor 
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                
                                // 3. Bouton Palette
                                Button {
                                    display: AbstractButton.IconOnly
                                    icon.source: "palette_icon.svg"
                                    icon.color: Theme.mainTextColor 
                                    
                                    icon.width: 30
                                    icon.height: 30
                                    
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    
                                    background: Rectangle {
                                        color: parent.down ? Theme.controlBackgroundColor : "transparent"
                                        radius: 4
                                    }
                                    onClicked: colorPicker.open()
                                }
                            }

                            ColorDialog {
                                id: colorPicker
                                title: itemConfig.name
                                selectedColor: displayColor
                                options: ColorDialog.ShowAlphaChannel
                                onAccepted: {
                                    var colorString = "" + selectedColor;
                                    plugin.applyColorChange(currentKey, colorString);
                                }
                            }
                        }
                    }
                }
            }
            
            // BOUTONS
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 5
                Layout.bottomMargin: 10
                spacing: 20

                Button {
                    text: plugin.tr("reset") // Utilisation de tr()
                    onClicked: {
                        themeSettings.jsonColors = "{}";
                        Theme.applyColors(plugin.defaultColors);
                    }
                }
                Button {
                    text: plugin.tr("apply") // Utilisation de tr()
                    highlighted: true
                    onClicked: positionColorDialog.close()
                }
            }
        }
    }

    // --- INITIALISATION ---
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(openColorsBtn);
        loadTimer.start();
    }
    
    Timer {
        id: loadTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            try {
                var c = JSON.parse(themeSettings.jsonColors || "{}");
                if(Object.keys(c).length > 0) Theme.applyColors(c);
            } catch(e) {}
        }
    }
}