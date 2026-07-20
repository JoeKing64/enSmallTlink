#!/bin/zsh

set -e

# ============================================================
# 可调整参数
# ============================================================

APP="/Applications/Tlink.app"

# 图标主体占原尺寸的比例：
# 0.78 = 78%
# 0.80 = 80%
# 0.75 = 75%
SCALE="0.78"

# ============================================================
# 路径设置
# ============================================================

RESOURCE_DIR="$APP/Contents/Resources"
SOURCE_ICON="$RESOURCE_DIR/icon.icns"
BACKUP_ICON="$RESOURCE_DIR/icon.icns.original-backup"

WORK="$HOME/Desktop/tlink_icon"
ORIGINAL="$WORK/icon-original.icns"
ICONSET="$WORK/icon.iconset"
OUTPUT="$WORK/icon-new.icns"
SWIFT_SCRIPT="$WORK/resize_icon.swift"

# ============================================================
# 基础检查
# ============================================================

echo
echo "========================================"
echo "Tlink 图标缩放工具"
echo "缩放比例：${SCALE}"
echo "========================================"
echo

if [ ! -d "$APP" ]; then
    echo "错误：找不到应用："
    echo "$APP"
    exit 1
fi

if [ ! -f "$SOURCE_ICON" ]; then
    echo "错误：找不到图标文件："
    echo "$SOURCE_ICON"
    exit 1
fi

# ============================================================
# 1. 退出应用
# ============================================================

echo "1/9 正在退出 Tlink..."

osascript -e 'tell application "Tlink" to quit' \
    2>/dev/null || true

pkill -x Tlink 2>/dev/null || true

sleep 1

# ============================================================
# 2. 创建原始备份
# ============================================================

echo "2/9 正在检查原始图标备份..."

if [ ! -f "$BACKUP_ICON" ]; then
    echo "首次运行，正在备份原始图标..."

    sudo cp "$SOURCE_ICON" "$BACKUP_ICON"
    sudo chmod 644 "$BACKUP_ICON"

    echo "原始图标已备份至："
    echo "$BACKUP_ICON"
else
    echo "原始备份已经存在，将继续使用该备份。"
fi

# ============================================================
# 3. 清理旧工作目录
# ============================================================

echo "3/9 正在清理旧工作文件..."

mkdir -p "$WORK"

rm -rf "$ICONSET"
rm -f "$ORIGINAL"
rm -f "$OUTPUT"
rm -f "$SWIFT_SCRIPT"

# 必须始终从原始备份重新开始，
# 避免多次运行时重复缩小。
cp "$BACKUP_ICON" "$ORIGINAL"

# ============================================================
# 4. 从 ICNS 导出所有 PNG 尺寸
# ============================================================

echo "4/9 正在导出所有图标尺寸..."

iconutil \
    -c iconset \
    -o "$ICONSET" \
    "$ORIGINAL"

PNG_COUNT=$(
    find "$ICONSET" \
        -type f \
        -name '*.png' |
    wc -l |
    tr -d ' '
)

if [ "$PNG_COUNT" -eq 0 ]; then
    echo "错误：没有从 ICNS 中导出任何 PNG 文件。"
    exit 1
fi

echo "成功导出 $PNG_COUNT 个 PNG 图标。"

# ============================================================
# 5. 创建 Core Graphics 像素级缩放脚本
# ============================================================

echo "5/9 正在创建图像处理程序..."

cat > "$SWIFT_SCRIPT" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(
        Data(("错误：" + message + "\n").utf8)
    )
    exit(1)
}

guard CommandLine.arguments.count == 3 else {
    fail("用法：swift resize_icon.swift 图片路径 缩放比例")
}

let inputPath = CommandLine.arguments[1]

guard let scale = Double(CommandLine.arguments[2]),
      scale > 0.0,
      scale <= 1.0 else {
    fail("缩放比例必须大于 0 且不超过 1")
}

let inputURL = URL(fileURLWithPath: inputPath) as CFURL

guard let imageSource =
        CGImageSourceCreateWithURL(inputURL, nil),
      let sourceImage =
        CGImageSourceCreateImageAtIndex(
            imageSource,
            0,
            [
                kCGImageSourceShouldCache: true
            ] as CFDictionary
        ) else {
    fail("无法读取图片：\(inputPath)")
}

let canvasWidth = sourceImage.width
let canvasHeight = sourceImage.height

let targetWidth = max(
    1,
    Int((Double(canvasWidth) * scale).rounded())
)

let targetHeight = max(
    1,
    Int((Double(canvasHeight) * scale).rounded())
)

let offsetX =
    CGFloat(canvasWidth - targetWidth) / 2.0

let offsetY =
    CGFloat(canvasHeight - targetHeight) / 2.0

guard let colorSpace =
        CGColorSpace(name: CGColorSpace.sRGB) else {
    fail("无法创建 sRGB 色彩空间")
}

guard let context =
        CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo
                    .premultipliedLast
                    .rawValue
        ) else {
    fail("无法创建透明画布")
}

/*
 清空整个画布，使四周完全透明。
*/
context.clear(
    CGRect(
        x: 0,
        y: 0,
        width: CGFloat(canvasWidth),
        height: CGFloat(canvasHeight)
    )
)

context.interpolationQuality = .high

/*
 使用真实像素坐标缩放并居中绘制。

 不使用 NSImage 的“点”坐标，
 避免 Retina 图标缩小成一半或偏向左下角。
*/
context.draw(
    sourceImage,
    in: CGRect(
        x: offsetX,
        y: offsetY,
        width: CGFloat(targetWidth),
        height: CGFloat(targetHeight)
    )
)

guard let outputImage = context.makeImage() else {
    fail("无法生成输出图片")
}

let temporaryPath =
    inputPath +
    ".tmp-" +
    UUID().uuidString +
    ".png"

let temporaryURL =
    URL(fileURLWithPath: temporaryPath) as CFURL

guard let destination =
        CGImageDestinationCreateWithURL(
            temporaryURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
    fail("无法创建 PNG 输出文件")
}

CGImageDestinationAddImage(
    destination,
    outputImage,
    nil
)

guard CGImageDestinationFinalize(destination) else {
    try? FileManager.default.removeItem(
        atPath: temporaryPath
    )
    fail("无法写入 PNG 文件")
}

do {
    try FileManager.default.removeItem(
        atPath: inputPath
    )

    try FileManager.default.moveItem(
        atPath: temporaryPath,
        toPath: inputPath
    )
} catch {
    try? FileManager.default.removeItem(
        atPath: temporaryPath
    )

    fail("保存失败：\(error.localizedDescription)")
}

let filename =
    URL(fileURLWithPath: inputPath).lastPathComponent

print(
    "\(filename)：画布 \(canvasWidth)x\(canvasHeight)，" +
    "主体 \(targetWidth)x\(targetHeight)，" +
    "居中偏移 \(offsetX), \(offsetY)"
)
SWIFT

# ============================================================
# 6. 缩放所有图标
# ============================================================

echo "6/9 正在将所有图标缩小到 ${SCALE}..."

cd "$ICONSET"

for file in ./*.png; do
    [ -f "$file" ] || continue

    swift \
        "$SWIFT_SCRIPT" \
        "$file" \
        "$SCALE"
done

# ============================================================
# 7. 重新生成 ICNS
# ============================================================

echo "7/9 正在重新生成 ICNS..."

cd "$WORK"

iconutil \
    -c icns \
    -o "$OUTPUT" \
    "$ICONSET"

if [ ! -f "$OUTPUT" ]; then
    echo "错误：新 ICNS 文件生成失败。"
    exit 1
fi

echo
file "$OUTPUT"
echo

# ============================================================
# 8. 安装图标并重新签名
# ============================================================

echo "8/9 正在安装新图标..."

sudo cp \
    "$OUTPUT" \
    "$SOURCE_ICON"

sudo chmod 644 "$SOURCE_ICON"

echo "正在重新签名应用..."

sudo codesign \
    --force \
    --deep \
    --sign - \
    "$APP"

echo "正在验证签名..."

codesign \
    --verify \
    --deep \
    --strict \
    --verbose=2 \
    "$APP"

# ============================================================
# 9. 刷新系统图标缓存
# ============================================================

echo "9/9 正在刷新 Dock 和 Finder..."

sudo touch "$APP"

killall iconservicesagent 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

sleep 2

echo
echo "========================================"
echo "处理完成"
echo "========================================"
echo
echo "新图标文件："
echo "$OUTPUT"
echo
echo "原始图标备份："
echo "$BACKUP_ICON"
echo
echo "现在正在重新打开 Tlink。"
echo

open "$APP"