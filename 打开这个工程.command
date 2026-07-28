#!/bin/bash
# 双击此文件，会自动打开正确的 MakeupChat 工程
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
open "$SCRIPT_DIR/MakeupChat.xcodeproj"
