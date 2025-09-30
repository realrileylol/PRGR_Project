import sys
import os

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Material"

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import qInstallMessageHandler   # ✅ from PySide6, not PyQt5

def handler(msg_type, context, message):
    print("QML:", message)

qInstallMessageHandler(handler)

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    #engine.load("main1.qml")
    engine.load('main.qml')
    if not engine.rootObjects():
        print("❌ QML failed to load. See messages above.")
        sys.exit(-1)

    sys.exit(app.exec())
