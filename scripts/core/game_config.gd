extends RefCounted

## Shared map projection and order identification palette.
const MAP_MARGIN := Rect2(0.0, 0.0, 1280.0, 675.0)
const INVENTORY_PANEL := Rect2(940, 8, 340, 105)
const CAMERA_CENTER := Vector2(10.0, 5.0)
const CAMERA_HALF_HEIGHT := 50.0
const VIEW_WORLD_MIN := CAMERA_CENTER - Vector2(CAMERA_HALF_HEIGHT * 1280.0 / 675.0, CAMERA_HALF_HEIGHT)
const VIEW_WORLD_MAX := CAMERA_CENTER + Vector2(CAMERA_HALF_HEIGHT * 1280.0 / 675.0, CAMERA_HALF_HEIGHT)
const COLORS := [Color("#0a84ff"), Color("#ffd60a"), Color("#bf5af2"), Color("#ff9f0a"), Color("#32d74b"), Color("#ff00ff"), Color(0.5, 0.7, 0.039), Color(1, 0.5, 0.5), Color(0, 0.7, 0.7), Color(0.68, 0.56, 0.17), Color(0.57, 0.99, 0.95)]
const COURIER_SPAWN := Vector2(-24.7, -39.8)
