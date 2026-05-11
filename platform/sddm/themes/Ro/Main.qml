// Ro SDDM giriş teması
// Bu dosya saf QtQuick ile yazılır. ek efekt modülleri ve Controls kullanılmaz;
// amaç Fedora/SDDM ortamlarında modül eksikliği yüzünden giriş ekranının patlamamasıdır.

import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#352F44"

    property bool lockMode: true
    property bool userListOpen: false
    property bool sessionListOpen: false
    property bool keyboardListOpen: false
    property bool passwordVisible: false
    property string selectedUser: ""
    property string selectedUserAvatar: ""
    property int selectedSession: 0
    property string selectedSessionName: ""
    property int selectedKeyboard: -1
    property string selectedKeyboardName: ""

    property color roBg: "#352F44"
    property color roSurface: "#5C5470"
    property color roSurfaceSoft: "#655B78"
    property color roField: "#443B58"
    property color roFieldHover: "#504762"
    property color roAccent: "#B9B4C7"
    property color roSoftAccent: "#AAD7D9"
    property color roAction: "#92C7CF"
    property color roActionHover: "#AAD7D9"
    property color roText: "#FAF0E6"
    property color roMuted: "#D8CFE0"

    function userCount() {
        try { if (typeof userModel !== "undefined" && userModel.count >= 0) return userModel.count; } catch (e) {}
        return 0;
    }

    function userNameAt(index) {
        try {
            if (typeof userModel !== "undefined" && userModel.get) {
                var item = userModel.get(index);
                if (item) {
                    if (item.name && item.name.length > 0) return item.name;
                    if (item.userName && item.userName.length > 0) return item.userName;
                    if (item.loginName && item.loginName.length > 0) return item.loginName;
                    if (item.realName && item.realName.length > 0) return item.realName;
                }
            }
        } catch (e) {}

        try {
            if (typeof userModel !== "undefined" && userModel.index && userModel.data) {
                var idx = userModel.index(index, 0);
                var roles = [257, 256, 0];
                for (var r = 0; r < roles.length; r++) {
                    var value = userModel.data(idx, roles[r]);
                    if (value && value.length > 0) return value;
                }
            }
        } catch (e) {}
        return "";
    }

    function userAvatarAt(index) {
        try {
            if (typeof userModel !== "undefined" && userModel.get) {
                var item = userModel.get(index);
                if (item) {
                    if (item.icon && item.icon.length > 0) return item.icon;
                    if (item.avatarPath && item.avatarPath.length > 0) return item.avatarPath;
                }
            }
        } catch (e) {}

        try {
            if (typeof userModel !== "undefined" && userModel.index && userModel.data) {
                var idx = userModel.index(index, 0);
                var roles = [259, 258];
                for (var r = 0; r < roles.length; r++) {
                    var value = userModel.data(idx, roles[r]);
                    if (value && value.length > 0) return value;
                }
            }
        } catch (e) {}
        return "";
    }

    function userAvatarForName(name) {
        for (var i = 0; i < users.count; i++) {
            var item = users.get(i);
            if (item.name === name) return item.icon;
        }
        return "";
    }

    function setSelectedUser(name, avatar) {
        selectedUser = name;
        selectedUserAvatar = avatar && avatar.length > 0 ? avatar : userAvatarForName(name);
    }

    function detectUserName() {
        try {
            if (typeof userModel !== "undefined" && userModel.lastUser && userModel.lastUser.length > 0) return userModel.lastUser;
        } catch (e) {}
        try {
            if (typeof userModel !== "undefined" && userModel.lastIndex >= 0) {
                var last = userNameAt(userModel.lastIndex);
                if (last.length > 0) return last;
            }
        } catch (e) {}
        if (userCount() > 0) return userNameAt(0);
        return "";
    }

    function defaultSessionIndex() {
        try { if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) return sessionModel.lastIndex; } catch (e) {}
        return 0;
    }

    function sessionIndex() {
        if (selectedSession >= 0) return selectedSession;
        return defaultSessionIndex();
    }

    function sessionNameForIndex(index) {
        for (var i = 0; i < sessions.count; i++) {
            var item = sessions.get(i);
            if (item.sessionIndexValue === index) return item.name;
        }
        return "";
    }

    function sessionDelegateName(object, index) {
        if (object && object.sessionName && object.sessionName.length > 0) return object.sessionName;
        return qsTr("Session") + " " + (index + 1);
    }

    function refreshUsers() {
        users.clear();
        for (var i = 0; i < userCount(); i++) {
            var name = userNameAt(i);
            if (name.length > 0) users.append({ "name": name, "icon": userAvatarAt(i) });
        }
    }

    function refreshSessions() {
        sessions.clear();
        for (var i = 0; i < sessionInstantiator.count; i++) {
            var object = sessionInstantiator.objectAt(i);
            if (object) {
                sessions.append({
                    "name": sessionDelegateName(object, i),
                    "sessionIndexValue": object.sessionIndexValue >= 0 ? object.sessionIndexValue : i
                });
            }
        }

        // SDDM sessionModel geç yüklenirse login butonu yine güvenli bir varsayılanla çalışır.
        if (sessions.count === 0) sessions.append({ "name": qsTr("Default session"), "sessionIndexValue": defaultSessionIndex() });

        selectedSession = defaultSessionIndex();
        selectedSessionName = sessionNameForIndex(selectedSession);
        if (selectedSessionName.length === 0 && sessions.count > 0) {
            selectedSession = sessions.get(0).sessionIndexValue;
            selectedSessionName = sessions.get(0).name;
        }
    }

    function keyboardCount() {
        try { if (typeof keyboard !== "undefined" && keyboard.layouts) return keyboard.layouts.length; } catch (e) {}
        return 0;
    }

    function keyboardNameAt(index) {
        try {
            var layout = keyboard.layouts[index];
            if (layout.longName && layout.longName.length > 0) return layout.longName;
            if (layout.shortName && layout.shortName.length > 0) return layout.shortName;
            if (layout.name && layout.name.length > 0) return layout.name;
        } catch (e) {}
        return qsTr("Keyboard") + " " + (index + 1);
    }

    function currentKeyboardIndex() {
        try { if (typeof keyboard !== "undefined" && keyboard.currentLayout >= 0) return keyboard.currentLayout; } catch (e) {}
        return 0;
    }

    function refreshKeyboards() {
        keyboards.clear();
        for (var i = 0; i < keyboardCount(); i++) {
            keyboards.append({ "name": keyboardNameAt(i), "keyboardIndexValue": i });
        }
        selectedKeyboard = currentKeyboardIndex();
        selectedKeyboardName = keyboardNameAt(selectedKeyboard);
    }

    function setKeyboard(index) {
        try { keyboard.currentLayout = index; } catch (e) {}
        selectedKeyboard = index;
        selectedKeyboardName = keyboardNameAt(index);
    }

    function showLogin() {
        lockMode = false;
        userListOpen = false;
        sessionListOpen = false;
        keyboardListOpen = false;
        passwordInput.forceActiveFocus();
    }

    function showLock() {
        userListOpen = false;
        sessionListOpen = false;
        keyboardListOpen = false;
        passwordVisible = false;
        lockMode = true;
    }

    function doLogin() {
        var user = selectedUser.length > 0 ? selectedUser : fallbackUser.text;
        if (user.length > 0) sddm.login(user, passwordInput.text, sessionIndex());
    }

    function power(action) {
        try {
            if (action === "suspend" && sddm.suspend) sddm.suspend();
            if (action === "reboot" && sddm.reboot) sddm.reboot();
            if (action === "powerOff" && sddm.powerOff) sddm.powerOff();
        } catch (e) {}
    }

    Component.onCompleted: {
        refreshUsers();
        sessionSyncTimer.restart();
        refreshKeyboards();
        setSelectedUser(detectUserName(), "");
        clockTimer.triggered();
    }

    ListModel { id: users }
    ListModel { id: sessions }
    ListModel { id: keyboards }

    Timer {
        id: sessionSyncTimer
        interval: 1
        repeat: false
        onTriggered: root.refreshSessions()
    }

    Instantiator {
        id: sessionInstantiator
        model: (typeof sessionModel === "undefined") ? null : sessionModel
        delegate: QtObject {
            property string sessionName: model.name ? model.name : ""
            property int sessionIndexValue: model.index >= 0 ? model.index : index
        }
        onObjectAdded: sessionSyncTimer.restart()
        onObjectRemoved: sessionSyncTimer.restart()
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date();
            timeText.text = Qt.formatTime(now, "hh:mm");
            dateText.text = Qt.formatDate(now, "dddd, MMMM d");
        }
    }

    Image {
        id: bg
        anchors.fill: parent
        source: Qt.resolvedUrl("assets/login.jpg")
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
    }

    // Hafif premium perde. Gerçek blur kullanmıyoruz; modül bağımlılığı giriş ekranını bozmasın.
    Rectangle {
        anchors.fill: parent
        color: root.lockMode ? "#000000" : root.roBg
        opacity: root.lockMode ? 0.18 : 0.42
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.lockMode
        onClicked: root.showLogin()
        Keys.onPressed: root.showLogin()
        focus: root.lockMode
    }

    Column {
        id: lockClock
        visible: root.lockMode
        opacity: root.lockMode ? 1 : 0
        anchors.centerIn: parent
        spacing: 10
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: timeText
            color: root.roText
            font.family: "Inter, Noto Sans, Sans Serif"
            font.pixelSize: Math.max(64, root.height * 0.095)
            font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: dateText
            color: root.roMuted
            opacity: 0.86
            font.family: "Inter, Noto Sans, Sans Serif"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Rectangle {
        id: loginCard
        visible: !root.lockMode
        opacity: root.lockMode ? 0 : 1
        width: Math.min(430, Math.max(340, root.width * 0.86))
        height: Math.min(root.height - 48, 420 + (users.count > 1 ? 42 : 0) + (sessions.count > 0 ? 42 : 0) + (keyboards.count > 1 ? 42 : 0) + (root.userListOpen ? Math.min(124, users.count * 40) : 0) + (root.sessionListOpen ? Math.min(124, sessions.count * 40) : 0) + (root.keyboardListOpen ? Math.min(124, keyboards.count * 40) : 0) + (selectedUser.length === 0 ? 44 : 0))
        radius: 24
        color: root.roSurface
        border.color: root.roSoftAccent
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.min(90, root.height * 0.08)
        Keys.onEscapePressed: root.showLock()
        Behavior on opacity { NumberAnimation { duration: 240 } }

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 12

            Column {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 74
                    height: 74
                    radius: width / 2
                    color: root.roField
                    border.color: root.roSoftAccent
                    border.width: 1
                    clip: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: width / 2
                        color: "#00000000"
                        border.color: root.roAccent
                        border.width: 1
                        opacity: 0.42
                    }

                    Image {
                        id: userAvatarImage
                        anchors.fill: parent
                        anchors.margins: 6
                        source: root.selectedUserAvatar
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 52
                        height: 52
                        source: Qt.resolvedUrl("assets/roasd-logo.png")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: userAvatarImage.status === Image.Error || userAvatarImage.status === Image.Null || root.selectedUserAvatar.length === 0
                    }
                }

                Text {
                    width: parent.width
                    text: selectedUser.length > 0 ? selectedUser : qsTr("User")
                    color: root.roText
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 23
                    font.bold: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.selectedSessionName.length > 0 ? root.selectedSessionName : qsTr("Default session")
                    color: root.roMuted
                    opacity: 0.88
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                width: parent.width
                height: users.count > 1 ? 34 : 0
                visible: users.count > 1
                radius: 13
                color: changeMouse.pressed ? root.roFieldHover : (changeMouse.containsMouse ? root.roSurfaceSoft : root.roField)
                border.color: changeMouse.containsMouse ? root.roAction : root.roAccent
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.userListOpen ? qsTr("Hide users") : qsTr("Change user")
                    color: root.roMuted
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 13
                }
                MouseArea { id: changeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.userListOpen = !root.userListOpen; root.sessionListOpen = false; root.keyboardListOpen = false; } }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.userListOpen
                height: root.userListOpen ? Math.min(124, users.count * 40) : 0
                clip: true

                Repeater {
                    model: users
                    delegate: Rectangle {
                        width: parent.width
                        height: 34
                        radius: 12
                        color: model.name === root.selectedUser ? root.roSurfaceSoft : root.roField
                        border.color: model.name === root.selectedUser ? root.roAction : root.roSurfaceSoft
                        border.width: 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            width: parent.width - 28
                            text: model.name
                            color: root.roText
                            font.family: "Inter, Noto Sans, Sans Serif"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.setSelectedUser(model.name, model.icon); root.userListOpen = false; passwordInput.forceActiveFocus(); } }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: sessions.count > 0 ? 36 : 0
                visible: sessions.count > 0
                radius: 13
                color: sessionMouse.pressed ? root.roFieldHover : (sessionMouse.containsMouse ? root.roSurfaceSoft : root.roField)
                border.color: root.sessionListOpen || sessionMouse.containsMouse ? root.roAction : root.roAccent
                border.width: 1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    text: qsTr("Desktop")
                    color: root.roMuted
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 34
                    width: parent.width - 128
                    text: root.selectedSessionName.length > 0 ? root.selectedSessionName : qsTr("Default")
                    color: root.roText
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 13
                    text: sessions.count > 1 ? (root.sessionListOpen ? "⌃" : "⌄") : "✓"
                    color: root.roText
                    font.pixelSize: 15
                }

                MouseArea { id: sessionMouse; anchors.fill: parent; enabled: sessions.count > 1; hoverEnabled: true; onClicked: { root.sessionListOpen = !root.sessionListOpen; root.userListOpen = false; root.keyboardListOpen = false; } }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.sessionListOpen && sessions.count > 1
                height: visible ? Math.min(124, sessions.count * 40) : 0
                clip: true

                Repeater {
                    model: sessions
                    delegate: Rectangle {
                        width: parent.width
                        height: 34
                        radius: 12
                        color: model.sessionIndexValue === root.selectedSession ? root.roSurfaceSoft : root.roField
                        border.color: model.sessionIndexValue === root.selectedSession ? root.roAction : root.roSurfaceSoft
                        border.width: 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            width: parent.width - 28
                            text: model.name
                            color: root.roText
                            font.family: "Inter, Noto Sans, Sans Serif"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selectedSession = model.sessionIndexValue;
                                root.selectedSessionName = model.name;
                                root.sessionListOpen = false;
                                root.keyboardListOpen = false;
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: keyboards.count > 1 ? 36 : 0
                visible: keyboards.count > 1
                radius: 13
                color: keyboardMouse.pressed ? root.roFieldHover : (keyboardMouse.containsMouse ? root.roSurfaceSoft : root.roField)
                border.color: root.keyboardListOpen || keyboardMouse.containsMouse ? root.roAction : root.roAccent
                border.width: 1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    text: qsTr("Keyboard")
                    color: root.roMuted
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 34
                    width: parent.width - 132
                    text: root.selectedKeyboardName.length > 0 ? root.selectedKeyboardName : qsTr("Default")
                    color: root.roText
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 13
                    text: root.keyboardListOpen ? "⌃" : "⌄"
                    color: root.roText
                    font.pixelSize: 15
                }

                MouseArea { id: keyboardMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.keyboardListOpen = !root.keyboardListOpen; root.userListOpen = false; root.sessionListOpen = false; } }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.keyboardListOpen && keyboards.count > 1
                height: visible ? Math.min(124, keyboards.count * 40) : 0
                clip: true

                Repeater {
                    model: keyboards
                    delegate: Rectangle {
                        width: parent.width
                        height: 34
                        radius: 12
                        color: model.keyboardIndexValue === root.selectedKeyboard ? root.roSurfaceSoft : root.roField
                        border.color: model.keyboardIndexValue === root.selectedKeyboard ? root.roAction : root.roSurfaceSoft
                        border.width: 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            width: parent.width - 28
                            text: model.name
                            color: root.roText
                            font.family: "Inter, Noto Sans, Sans Serif"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.setKeyboard(model.keyboardIndexValue);
                                root.keyboardListOpen = false;
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: selectedUser.length > 0 ? 0 : 42
                visible: selectedUser.length === 0
                radius: 13
                color: root.roField
                border.color: root.roAccent
                border.width: 1

                TextInput {
                    id: fallbackUser
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.roText
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 15
                    clip: true
                }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: qsTr("User"); color: root.roMuted; font.pixelSize: 14; visible: fallbackUser.text.length === 0 }
            }

            Rectangle {
                width: parent.width
                height: 48
                radius: 14
                color: root.roField
                border.color: passwordInput.activeFocus ? root.roAction : root.roSurfaceSoft
                border.width: 1

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 50
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                    color: root.roText
                    font.family: "Inter, Noto Sans, Sans Serif"
                    font.pixelSize: 15
                    clip: true
                    Keys.onEnterPressed: root.doLogin()
                    Keys.onReturnPressed: root.doLogin()
                }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: qsTr("Password"); color: root.roMuted; font.pixelSize: 14; visible: passwordInput.text.length === 0 && !passwordInput.activeFocus }

                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: showMouse.pressed ? root.roFieldHover : (showMouse.containsMouse ? root.roSurfaceSoft : "transparent")
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    Text { anchors.centerIn: parent; text: root.passwordVisible ? "●" : "◌"; color: root.roText; font.pixelSize: 17 }
                    MouseArea { id: showMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.passwordVisible = !root.passwordVisible }
                }
            }

            Rectangle {
                width: parent.width
                height: 46
                radius: 14
                color: loginMouse.pressed ? "#7FB4BD" : (loginMouse.containsMouse ? root.roActionHover : root.roAction)
                Text { anchors.centerIn: parent; text: qsTr("Log In"); color: root.roBg; font.family: "Inter, Noto Sans, Sans Serif"; font.pixelSize: 15; font.bold: true }
                MouseArea { id: loginMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
            }

            Row {
                width: parent.width
                height: 44
                spacing: 10
                Repeater {
                    model: [
                        { icon: "☾", label: qsTr("Sleep"), action: "suspend" },
                        { icon: "↻", label: qsTr("Restart"), action: "reboot" },
                        { icon: "⏻", label: qsTr("Shut Down"), action: "powerOff" }
                    ]
                    delegate: Rectangle {
                        width: (parent.width - 20) / 3
                        height: 42
                        radius: 15
                        color: actionMouse.pressed ? root.roFieldHover : (actionMouse.containsMouse ? root.roSurfaceSoft : root.roField)
                        border.color: actionMouse.containsMouse ? root.roAction : root.roSurfaceSoft
                        border.width: 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: root.roText; font.pixelSize: 15 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.roMuted; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.power(modelData.action) }
                    }
                }
            }
        }
    }

    Connections {
        target: (typeof sddm === "undefined") ? null : sddm
        function onLoginFailed() {
            passwordInput.selectAll();
            passwordInput.forceActiveFocus();
        }
    }
}
