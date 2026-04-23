#!/usr/bin/env bash

set -euo pipefail

PROJECT_PATH="${1:-$(pwd)}"
GODOT_BIN="${GODOT_BIN:-godot}"
QUIT_AFTER_SECONDS="${QUIT_AFTER_SECONDS:-3}"

"${GODOT_BIN}" --headless --editor --path "${PROJECT_PATH}" --quit
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --quit-after "${QUIT_AFTER_SECONDS}"
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_track_layouts.gd
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_track_geometry.gd
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_track_mutator.gd
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_sphere_car.gd
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_physics_car.gd
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://scripts/validate_car_options.gd
