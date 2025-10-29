#!/bin/bash

echo "🔧 Quick Fix - Installing Missing QML Modules"
echo "=============================================="
echo ""

echo "Installing QtQuick Controls and required QML modules..."
sudo apt-get install -y \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    qml6-module-qtquick-window \
    qml6-module-qtqml-workerscript \
    qt6-declarative-dev

echo ""
echo "✅ QML modules installed!"
echo ""
echo "Now try running your app again:"
echo "  python3 main.py"
echo ""
