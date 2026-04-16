#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${1:-$(pwd)}"
GODOT_BIN="${GODOT_BIN:-godot}"
QUIT_AFTER_SECONDS="${QUIT_AFTER_SECONDS:-3}"

"${GODOT_BIN}" --headless --editor --path "${PROJECT_PATH}" --quit
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --quit-after "${QUIT_AFTER_SECONDS}"
