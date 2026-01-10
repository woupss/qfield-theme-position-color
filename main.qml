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

    // --- TRADUCTIONS ---
    property string currentLang: Qt.locale().name.substring(0, 2)
    function tr(key) {
        var translations = {
            // 1. & 2. Remplissage
            "pos_label":       { "en": "Fill",               "fr": "Remplissage" },
            "pos_desc":        { "en": "Arrow & Dot",        "fr": "Flèche & Point" },
            
            // 3. & 4. Bordures
            "stroke_label":    { "en": "Borders",            "fr": "Bordures" },
            "stroke_desc":     { "en": "Arrow & Dot",        "fr": "Flèche & Point" },
            
            // 5. Couleur Bordure
            "acc_border_c":    { "en": "Border Color",       "fr": "Couleur bordure" },
            "acc_border_d":    { "en": "Accuracy circle",    "fr": "Cercle de précision" }, // inchangé

            "pos_tint":        { "en": "Position Settings",  "fr": "Réglages Position" },
            "reset":           { "en": "Reset",              "fr": "Réinitialiser" },
            "apply":           { "en": "Apply",              "fr": "Appliquer" },

            // 6. Taille flèche (plus de description)
            "arrow_size":      { "en": "Arrow Size",         "fr": "Taille flèche" },
            "arrow_s_desc":    { "en": "",                   "fr": "" },
            
            // 7. Épaisseur bordure de la Flèche
            "arrow_w":         { "en": "Arrow Border Width", "fr": "Épaisseur bordure de la Flèche" },
            "arrow_w_desc":    { "en": "",                   "fr": "" },
            
            // 8. Épaisseur bordure du Point
            "dot_w":           { "en": "Dot Border Width",   "fr": "Épaisseur bordure du Point" },
            "dot_w_desc":      { "en": "",                   "fr": "" },
            
            // 9. Épaisseur bordure du cercle de précision
            "acc_w":           { "en": "Acc. Border Width",  "fr": "Épaisseur bordure du cercle de précision" },
            "acc_w_desc":      { "en": "",                   "fr": "" },

            // Ceux-ci n'ont pas été demandés à être modifiés, je les laisse
            "dot_size":        { "en": "Dot Size",           "fr": "Taille Point" },
            "dot_s_desc":      { "en": "Diameter",           "fr": "Diamètre" },
            
            // Anciennes clés gardées pour compatibilité ou reset
            "acc_high":        { "en": "Acc. (High)",        "fr": "Préc. (Excellente)" },
            "acc_avg":         { "en": "Acc. (Avg.)",        "fr": "Préc. (Moyenne)" },
            "acc_low":         { "en": "Acc. (Low)",         "fr": "Préc. (Faible)" },
            "green_circ":      { "en": "Green circle",       "fr": "Cercle vert" },
            "orange_circ":     { "en": "Orange circle",      "fr": "Cercle orange" },
            "red_circ":        { "en": "Red circle",         "fr": "Cercle rouge" }
        }
        var t = translations[key];
        if (t) return (currentLang === "fr") ? t.fr : t.en;
        return key;
    }

    // --- CONFIGURATION ---
    property var positionColorConfig: ({
        // --- COULEURS ---
        "positionColor":           { "name": tr("pos_label"),    "desc": tr("pos_desc"),     "type": "color" },
        "positionStrokeColor":     { "name": tr("stroke_label"), "desc": tr("stroke_desc"),  "type": "color" },
        "accuracyBorderColor":     { "name": tr("acc_border_c"), "desc": tr("acc_border_d"), "type": "color" },
        
        // --- SLIDERS ---
        "movementSize":            { "name": tr("arrow_size"),   "desc": tr("arrow_s_desc"), "type": "number", "min": 10, "max": 60, "step": 2 },
        "movementStrokeWidth":     { "name": tr("arrow_w"),      "desc": tr("arrow_w_desc"), "type": "number", "min": 0, "max": 10, "step": 0.5 },
        "positionMarkerSize":      { "name": tr("dot_size"),     "desc": tr("dot_s_desc"),   "type": "number", "min": 5, "max": 40, "step": 1 },
        "positionBorderWidth":     { "name": tr("dot_w"),        "desc": tr("dot_w_desc"),   "type": "number", "min": 0, "max": 5, "step": 0.1 },
        "accuracyBorderWidth":     { "name": tr("acc_w"),        "desc": tr("acc_w_desc"),   "type": "number", "min": 0, "max": 5, "step": 0.1 }
    })

    property var allKeys: Object.keys(positionColorConfig)
    property var colorKeys: allKeys.filter(function(k){ return positionColorConfig[k].type === 'color' })
    property var sliderKeys: allKeys.filter(function(k){ return positionColorConfig[k].type === 'number' })
    
    property var defaultColors: ({
        "positionColor": "#3388FF",           
        "positionStrokeColor": "#FFFFFF",
        "accuracyExcellent": "#4CAF50",       
        "accuracyTolerated": "#FF9800",       
        "accuracyBad": "#F44336",
        "accuracyBorderColor": "#3388FF",
        
        "movementSize": 26.0,
        "movementStrokeWidth": 3.0,
        "positionMarkerSize": 14.0,
        "positionBorderWidth": 2.0,
        "accuracyBorderWidth": 0.7
    })

    Settings {
        id: themeSettings
        property string jsonColors: "{}" 
    }

    // --- LOGIQUE ---
    function findLocationMarker(parent) {
        if (!parent || !parent.children) return null;
        for (var i = 0; i < parent.children.length; i++) {
            var child = parent.children[i];
            if (child.toString().indexOf("LocationMarker") !== -1) return child;
            var res = findLocationMarker(child);
            if (res) return res;
        }
        return null;
    }

    function updateLiveMarker(key, value) {
        var mapCanvas = iface.findItemByObjectName('mapCanvasContainer');
        if (!mapCanvas) return;
        var marker = findLocationMarker(mapCanvas);
        if (!marker) return;

        // Racines
        if (key === "positionColor") marker.color = value;
        if (key === "positionStrokeColor") marker.strokeColor = value;

        for (var i = 0; i < marker.children.length; i++) {
            var child = marker.children[i];
            try {
                var childStr = child.toString();
                var isRectangle = (childStr.indexOf("Rectangle") !== -1);
                var isShape = (childStr.indexOf("Shape") !== -1);

                var isPosMarker = (isRectangle && child.layer && child.layer.enabled);
                var isAccMarker = (isRectangle && (!child.layer || !child.layer.enabled));
                var isMovementMarker = isShape; 

                // 1. Point de Position
                if (isPosMarker) {
                    if (key === "positionMarkerSize") {
                        child.width = Number(value); child.height = Number(value); child.radius = Number(value) / 2;
                    }
                    if (key === "positionBorderWidth") child.border.width = Number(value);
                    if (key === "positionStrokeColor") child.border.color = value;
                }

                // 2. Cercle de Précision
                if (isAccMarker) {
                    if (key === "accuracyBorderWidth") {
                        if (child.border) child.border.width = Number(value);
                    }
                    if (key === "accuracyBorderColor") {
                        if (child.border) child.border.color = value;
                    }
                }

                // 3. Flèche
                if (isMovementMarker) {
                    if (key === "movementSize") child.scale = Number(value) / 26.0;
                    if (key === "movementStrokeWidth") {
                        if (child.data) {
                            for (var j = 0; j < child.data.length; j++) {
                                if (child.data[j].strokeWidth !== undefined) child.data[j].strokeWidth = Number(value);
                            }
                        }
                    }
                    if (key === "positionStrokeColor") {
                         if (child.data) {
                            for (var k = 0; k < child.data.length; k++) {
                                if (child.data[k].strokeColor !== undefined) child.data[k].strokeColor = value;
                            }
                        }
                    }
                }
            } catch(e) {}
        }
    }

    function applyChange(key, value) {
        try {
            if (key === undefined || key === "") return;
            var currentJson = themeSettings.jsonColors || "{}";
            var colorsObj = JSON.parse(currentJson);
            colorsObj[key] = value;
            
            if (plugin.positionColorConfig[key].type === "color") Theme.applyColors(colorsObj); 
            
            updateLiveMarker(key, value);
            themeSettings.jsonColors = JSON.stringify(colorsObj);
        } catch (e) { console.log("Erreur application: " + e); }
    }

    function getCurrentValue(key) {
        var saved = JSON.parse(themeSettings.jsonColors || "{}")[key];
        if (saved !== undefined) return saved;
        var conf = plugin.positionColorConfig[key];
        if (conf.type === "color") {
            if (Theme[key]) return Theme[key].toString();
        }
        return plugin.defaultColors[key];
    }

    // --- UI ---
    QfToolButton {
        id: openColorsBtn
        iconSource: 'icon.svg'
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true
        onClicked: positionColorDialog.open()
    }

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
            spacing: 0
            
            // TITRE
            Label {
                text: plugin.tr("pos_tint")
                font.bold: true; font.pixelSize: 18
                color: Theme.mainTextColor 
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                Layout.bottomMargin: 10
            }

            // CONTENU SCROLLABLE
            ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(innerColumn.implicitHeight, plugin.mainWindow.height * 0.75)
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    id: innerColumn
                    width: scrollView.availableWidth
                    spacing: 15 

                    // --- SECTION COULEURS ---
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: plugin.colorKeys
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                color: "#259E9E9E" 
                                border.color: Theme.controlBorderColor; border.width: 1; radius: 6

                                property string key: modelData
                                property var conf: plugin.positionColorConfig[key]
                                property var val: plugin.getCurrentValue(key)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2 

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        color: val
                                        border.color: Theme.controlBorderColor; border.width: 1
                                        Layout.rightMargin: 4
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label { 
                                            text: conf.name
                                            font.bold: true; color: Theme.mainTextColor; font.pixelSize: 12
                                            elide: Text.ElideRight; Layout.fillWidth: true
                                        }
                                        Label { 
                                            text: conf.desc
                                            color: Theme.secondaryTextColor; font.pixelSize: 10
                                            elide: Text.ElideRight; Layout.fillWidth: true
                                        }
                                    }

                                    Button {
                                        display: AbstractButton.IconOnly
                                        icon.source: "palette_icon.svg"
                                        icon.color: Theme.mainTextColor
                                        icon.width: 34; icon.height: 34 
                                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                        background: Rectangle {
                                            color: parent.down ? Theme.controlBackgroundColor : "transparent"
                                            radius: 4
                                        }
                                        onClicked: colorPicker.open()
                                    }
                                }
                                ColorDialog {
                                    id: colorPicker
                                    title: conf.name
                                    selectedColor: val
                                    options: ColorDialog.ShowAlphaChannel
                                    onAccepted: plugin.applyChange(key, "" + selectedColor)
                                }
                            }
                        }
                    }
                    
                    // --- SECTION SLIDERS ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8 

                        Repeater {
                            model: plugin.sliderKeys
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70 
                                color: "#259E9E9E"
                                border.color: Theme.controlBorderColor; border.width: 1; radius: 6

                                property string key: modelData
                                property var conf: plugin.positionColorConfig[key]
                                property var val: Number(plugin.getCurrentValue(key))

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8 
                                    spacing: 2
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { 
                                            // Affiche le nom, et la description seulement si elle n'est pas vide
                                            text: conf.desc !== "" ? conf.name + " (" + conf.desc + ")" : conf.name
                                            font.bold: true; color: Theme.mainTextColor; font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: val.toLocaleString(Qt.locale(), 'f', 1)
                                            font.bold: true; color: Theme.mainTextColor
                                        }
                                    }

                                    Slider {
                                        id: sControl
                                        Layout.fillWidth: true
                                        from: conf.min; to: conf.max 
                                        stepSize: conf.step
                                        value: val

                                        background: Rectangle {
                                            x: sControl.leftPadding
                                            y: sControl.topPadding + sControl.availableHeight / 2 - height / 2
                                            width: sControl.availableWidth
                                            height: 4
                                            radius: 2
                                            color: "#bdbebf"
                                            Rectangle {
                                                width: sControl.visualPosition * parent.width
                                                height: parent.height; color: Theme.mainColor; radius: 2
                                            }
                                        }
                                        handle: Rectangle {
                                            x: sControl.leftPadding + sControl.visualPosition * (sControl.availableWidth - width)
                                            y: sControl.topPadding + sControl.availableHeight / 2 - height / 2
                                            width: 16; height: 16
                                            radius: 8
                                            color: sControl.pressed ? Qt.darker(Theme.mainColor, 1.1) : Theme.mainColor
                                            border.color: "white"; border.width: 2
                                        }
                                        onMoved: plugin.applyChange(key, value)
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 5 }
                }
            }

            // BOUTONS BAS
            RowLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 0    
                Layout.bottomMargin: 2 
                spacing: 20
                Button {
                    text: plugin.tr("reset")
                    onClicked: {
                        themeSettings.jsonColors = "{}";
                        Theme.applyColors(plugin.defaultColors);
                        var keys = Object.keys(plugin.defaultColors);
                        for(var i=0; i<keys.length; i++) plugin.updateLiveMarker(keys[i], plugin.defaultColors[keys[i]]);
                    }
                }
                Button {
                    text: plugin.tr("apply")
                    highlighted: true
                    onClicked: positionColorDialog.close()
                }
            }
        }
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(openColorsBtn);
        loadTimer.start();
    }
    
    Timer {
        id: loadTimer
        interval: 1000
        onTriggered: {
            try {
                var c = JSON.parse(themeSettings.jsonColors || "{}");
                var keys = Object.keys(c);
                if(keys.length > 0) {
                    Theme.applyColors(c);
                    for (var i = 0; i < keys.length; i++) plugin.updateLiveMarker(keys[i], c[keys[i]]);
                }
            } catch(e) {}
        }
    }
}
