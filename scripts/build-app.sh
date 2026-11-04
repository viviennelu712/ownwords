#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/OwnWords.app"

cd "$ROOT"
swift build -c release --product LocalVoiceInputMac

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/Licenses"
cp "$ROOT/app/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/app/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
mkdir -p "$APP_DIR/Contents/Resources/proofreader"
cp "$ROOT/proofreader/proofread_server.py" "$ROOT/proofreader/proofread_core.py" "$ROOT/proofreader/system-prompt.txt" "$ROOT/proofreader/tidy-prompt.txt" "$APP_DIR/Contents/Resources/proofreader/"
cp "$BUILD_DIR/LocalVoiceInputMac" "$APP_DIR/Contents/MacOS/LocalVoiceInputMac"
cp "$ROOT/.build/checkouts/argmax-oss-swift/LICENSE" "$APP_DIR/Contents/Resources/Licenses/WhisperKit-MIT.txt"
cp "$ROOT/.build/checkouts/swift-transformers/LICENSE" "$APP_DIR/Contents/Resources/Licenses/swift-transformers-Apache-2.0.txt"
cp "$ROOT/.build/checkouts/swift-argument-parser/LICENSE.txt" "$APP_DIR/Contents/Resources/Licenses/swift-argument-parser-Apache-2.0.txt"
cp "$ROOT/app/ThirdPartyNotices.txt" "$APP_DIR/Contents/Resources/ThirdPartyNotices.txt"
chmod +x "$APP_DIR/Contents/MacOS/LocalVoiceInputMac"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
