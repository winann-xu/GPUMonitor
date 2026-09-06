#!/bin/bash
# GPUMonitor P7 自动巡检
# 由 launchd (com.gpu-monitor.auto-check) 每 60 秒触发，单次执行、flock 防重入。
# 只有 P7_TEST_STANDARD.md 中 T1-T8 全部真实通过，才生成 P7_PASS。

LOG="/Users/winann/01-project/02-G_if/scripts/gpu-monitor-cron.log"
PROJECT_DIR="/Users/winann/01-project/02-G_if"
DMG="$PROJECT_DIR/GPUMonitor.dmg"
APP_BUNDLE="$PROJECT_DIR/GPUMonitor.app"
SWIFT_DIR="$PROJECT_DIR/GPUMonitor/GPUMonitor"
XCODE_PROJECT="$PROJECT_DIR/GPUMonitor/GPUMonitor.xcodeproj/project.pbxproj"
P7_PASS_FILE="$PROJECT_DIR/P7_PASS"
LOCK_DIR="/tmp/gpumonitor-auto-check.lock.d"

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# 防重入：已有实例在跑时，本次直接退出
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

cd "$PROJECT_DIR" || exit 1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

FAILED=""

fail() {
    local code="$1"
    shift
    FAILED="$FAILED $code"
    log "❌ P7-$code: $*"
}

# 若 .app / DMG 缺失，先按当前源码重建一次再检查
if [ ! -d "$APP_BUNDLE" ] || [ ! -f "$DMG" ]; then
    log "构建产物缺失，先运行 build.sh 重建"
    if ! bash "$PROJECT_DIR/scripts/build.sh" >> "$LOG" 2>&1; then
        fail T2 "build.sh 重建失败"
    fi
fi

# ---------- T1: swift build 无错误、无严重警告 ----------
BUILD_OUT="$(mktemp /tmp/gpumonitor-build.XXXXXX)"
if ! swift build > "$BUILD_OUT" 2>&1; then
    fail T1 "swift build 失败，见日志尾部"
    tail -20 "$BUILD_OUT" >> "$LOG"
elif grep -q "warning:" "$BUILD_OUT"; then
    fail T1 "swift build 存在警告"
    grep "warning:" "$BUILD_OUT" | head -5 >> "$LOG"
fi
rm -f "$BUILD_OUT"

# ---------- T2: DMG 可挂载且内容完整 ----------
MOUNT_POINT="$(mktemp -d /tmp/gpumonitor-dmg.XXXXXX)"
if ! hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG" 2>/dev/null; then
    fail T2 "DMG 无法挂载"
else
    if [ ! -d "$MOUNT_POINT/GPUMonitor.app" ]; then
        fail T2 "DMG 中缺少 GPUMonitor.app"
    fi
    if [ ! -L "$MOUNT_POINT/Applications" ]; then
        fail T2 "DMG 中缺少 Applications 快捷链接"
    fi
    DMG_SIZE=$(stat -f%z "$DMG")
    if [ "$DMG_SIZE" -ge 5242880 ]; then
        fail T2 "DMG 大小 $((DMG_SIZE / 1024))KB，要求 < 5MB"
    fi
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
fi
rmdir "$MOUNT_POINT" 2>/dev/null

# ---------- T3: .app 包结构 ----------
APP_INFO="$APP_BUNDLE/Contents/Info.plist"
if [ ! -f "$APP_INFO" ]; then
    fail T3 "Info.plist 不存在"
fi
if [ ! -x "$APP_BUNDLE/Contents/MacOS/GPUMonitor" ]; then
    fail T3 "可执行文件 GPUMonitor 不存在或不可执行"
fi
if [ -f "$APP_INFO" ]; then
    LSUI=$(plutil -extract LSUIElement raw -o - "$APP_INFO" 2>/dev/null)
    [ "$LSUI" != "true" ] && fail T3 "LSUIElement 不是 true"

    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$APP_INFO" 2>/dev/null)
    [ "$BUNDLE_ID" != "com.gpu-monitor.app" ] && fail T3 "CFBundleIdentifier 错误: $BUNDLE_ID"

    EXEC_NAME=$(plutil -extract CFBundleExecutable raw -o - "$APP_INFO" 2>/dev/null)
    [ "$EXEC_NAME" != "GPUMonitor" ] && fail T3 "CFBundleExecutable 错误: $EXEC_NAME"

    MIN_VER=$(plutil -extract LSMinimumSystemVersion raw -o - "$APP_INFO" 2>/dev/null)
    MAJOR=$(echo "$MIN_VER" | awk -F. '{print $1}')
    if [ -z "$MAJOR" ] || [ "$MAJOR" -lt 14 ] 2>/dev/null; then
        fail T3 "LSMinimumSystemVersion 不是 >= 14.0"
    fi
fi

# ---------- T4: 原生采集集成（不依赖 macmon）----------
if [ -x "$APP_BUNDLE/Contents/Resources/bin/macmon" ]; then
    fail T4 "不应再随包内置 macmon 二进制"
fi
if grep -rq "arguments = \[\"pipe\"\]" "$SWIFT_DIR"; then
    fail T4 "仍存在 macmon pipe 子进程调用"
fi
if ! grep -rq "HardwareSampler\|GPUSampler" "$SWIFT_DIR/Data"; then
    fail T4 "缺少原生硬件采集实现"
fi
if [ ! -f "$PROJECT_DIR/CSMCBridge/SMCBridge.c" ] || [ ! -f "$PROJECT_DIR/CSMCBridge/include/SMCBridge.h" ]; then
    fail T4 "缺少 SMC 原生温度桥接源码"
fi

# ---------- T5: 核心功能源码存在 ----------
if ! grep -rq "MenuBarExtra" "$SWIFT_DIR"; then fail T5 "缺少菜单栏实现"; fi
if ! grep -rq "MetricData\|PopoverView" "$SWIFT_DIR"; then fail T5 "缺少弹出面板实现"; fi
if ! grep -rq "DynamicColorTheme\|tempColor" "$SWIFT_DIR"; then fail T5 "缺少动态配色实现"; fi
if ! grep -rq "TrendChartView" "$SWIFT_DIR"; then fail T5 "缺少趋势图实现"; fi
if ! grep -rq "UNUserNotificationCenter\|checkAlerts" "$SWIFT_DIR"; then fail T5 "缺少告警通知实现"; fi
if ! grep -rq "UserDefaults" "$SWIFT_DIR"; then fail T5 "缺少 UserDefaults 配置持久化"; fi

# ---------- T6: 项目结构 ----------
SWIFT_COUNT=$(find "$SWIFT_DIR" -name "*.swift" | wc -l | tr -d ' ')
[ "$SWIFT_COUNT" -lt 10 ] && fail T6 "Swift 源文件仅 $SWIFT_COUNT 个 (<10)"
for DIR in App Data MenuBar Models Settings Views; do
    [ ! -d "$SWIFT_DIR/$DIR" ] && fail T6 "缺少模块目录 $DIR"
done
[ ! -f "$PROJECT_DIR/Package.swift" ] && fail T6 "Package.swift 缺失"
[ ! -f "$XCODE_PROJECT" ] && fail T6 "Xcode 工程文件缺失"
[ ! -f "$PROJECT_DIR/scripts/build.sh" ] && fail T6 "build.sh 缺失"

# ---------- T7: 代码质量 ----------
MAX_LINE=0
TOO_LONG=""
while IFS= read -r -d '' FILE; do
    LINES=$(wc -l < "$FILE" | tr -d ' ')
    if [ "$LINES" -gt 300 ]; then
        TOO_LONG="$TOO_LONG $FILE($LINES)"
    fi
    if [ "$LINES" -gt "$MAX_LINE" ]; then
        MAX_LINE=$LINES
    fi
done < <(find "$SWIFT_DIR" -name "*.swift" -print0)
[ -n "$TOO_LONG" ] && fail T7 "单文件超过 300 行:$TOO_LONG"
if grep -rqE 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|sk-[A-Za-z0-9]{20,}' "$SWIFT_DIR"; then
    fail T7 "发现疑似硬编码敏感信息"
fi
if ! grep -rq "catch\|throws" "$SWIFT_DIR/Data"; then
    fail T7 "数据层缺少错误处理"
fi

# ---------- T8: launchd 定时任务 ----------
if ! launchctl print "gui/$(id -u)/com.gpu-monitor.auto-check" > /dev/null 2>&1; then
    fail T8 "launchd 任务 com.gpu-monitor.auto-check 未加载"
fi
[ ! -f "$LOG" ] && fail T8 "巡检日志文件不存在"

# ---------- 汇总 ----------
if [ -z "$FAILED" ]; then
    touch "$P7_PASS_FILE"
    log "✅ P7 全部通过 (T1-T8, $SWIFT_COUNT 个 Swift 文件, 最大 $MAX_LINE 行)"
else
    rm -f "$P7_PASS_FILE"
    log "P7 未通过，失败项:$FAILED"
fi

exit 0
