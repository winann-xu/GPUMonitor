#!/bin/bash
set -e
echo "=== GPUMonitor Build Script ==="

# 切换到项目根目录
cd "$(dirname "$0")/.."

# 1. 清理
echo "[1/6] Cleaning..."
rm -rf GPUMonitor.app GPUMonitor.dmg

# 2. 编译
echo "[2/6] Building..."
swift build 2>&1

# 3. 查找编译产物
BUILD_PATH="$(pwd)/.build/arm64-apple-macosx/debug/GPUMonitor"
if [ ! -f "$BUILD_PATH" ]; then
    BUILD_PATH=$(find .build -name GPUMonitor -type f 2>/dev/null | head -1)
fi
if [ -z "$BUILD_PATH" ] || [ ! -f "$BUILD_PATH" ]; then
    echo "Error: Build artifact not found"
    exit 1
fi
echo "   Found: $BUILD_PATH"

# 4. 打包 .app
echo "[3/6] Packing .app..."
APP_PATH="GPUMonitor.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>GPUMonitor</string>
    <key>CFBundleIdentifier</key><string>com.gpu-monitor.app</string>
    <key>CFBundleIconFile</key><string>GPUMonitor</string>
    <key>CFBundleName</key><string>GPU Monitor</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSUserNotificationAlertStyle</key><string>alert</string>
</dict>
</plist>
PLIST

cp "$BUILD_PATH" "$APP_PATH/Contents/MacOS/"
chmod +x "$APP_PATH/Contents/MacOS/GPUMonitor"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

# 应用图标
echo "[3.3/6] Adding app icon..."
if [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "$APP_PATH/Contents/Resources/GPUMonitor.icns"
fi

# 本地分发：ad-hoc 签名，保证 Gatekeeper 结构校验通过
echo "[3.4/6] Signing (ad-hoc)..."
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep -s - "$APP_PATH" 2>&1 || echo "Warning: ad-hoc 签名失败（不影响本地直接运行）"
else
    echo "Warning: codesign 不可用，跳过签名"
fi

# 5. 打包 .dmg
echo "[3.5/6] Creating DMG..."
DMG_NAME="GPUMonitor.dmg"
WORK_DIR="/tmp/dmg_work_$$_$RANDOM"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -R GPUMonitor.app "$WORK_DIR/"
ln -s /Applications "$WORK_DIR/Applications"
hdiutil create -volname "GPUMonitor Install" -srcfolder "$WORK_DIR" -ov -format UDRO "$DMG_NAME"
rm -rf "$WORK_DIR"

# 6. 统计代码
echo "[4/6] Statistics..."
FILE_COUNT=$(find GPUMonitor -name "*.swift" | wc -l | tr -d ' ')
LINE_COUNT=$(find GPUMonitor -name "*.swift" -exec cat {} + | wc -l | tr -d ' ')
echo "   Swift 文件: $FILE_COUNT"
echo "   代码行数: $LINE_COUNT"

# 7. 完成
echo "[5/6] Done!"
echo ""
echo "🎉 Build complete!"
echo "   DMG:    $(pwd)/GPUMonitor.dmg ($(du -h GPUMonitor.dmg | cut -f1))"
echo "   App:    $(pwd)/GPUMonitor.app ($(du -h GPUMonitor.app | cut -f1))"
echo ""
echo "📦 安装方式："
echo "   1. 双击挂载 GPUMonitor.dmg"
echo "   2. 拖拽 GPU Monitor.app 到 Applications"
echo "   3. 从 Launchpad 打开 GPU Monitor"
echo ""
echo "✅ 功能清单："
echo "   - 原生 API 实时采集（无 macmon/外部依赖）"
echo "   - 菜单栏实时显示 (GPU% + 温度)"
echo "   - 弹出面板 (GPU/CPU/内存/网络)"
echo "   - 动态配色 (绿→黄→橙→红)"
echo "   - 趋势图 (300 点折线图)"
echo "   - 告警通知 (温度/负载/内存)"
echo "   - 告警面板 (历史记录)"
echo "   - 电池电量/电源状态"
echo "   - 多显示器管理"
echo "   - 性能优化 (自适应刷新)"
echo "   - 数据导出 (CSV/JSON)"
echo "   - 历史记录视图"
echo "   - UserDefaults 配置持久化"
