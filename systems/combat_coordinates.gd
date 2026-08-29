extends RefCounted
class_name CombatCoordinates
## Explicit bridge between legacy 2D world coordinates and the native
## Combat Plane. UI layout coordinates stay Vector2; gameplay positions use
## Vector3 with a canonical Y=0.

static func from_2d(position: Vector2) -> Vector3:
	return Vector3(position.x, 0.0, position.y)


static func to_2d(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


static func flatten(position: Vector3) -> Vector3:
	return Vector3(position.x, 0.0, position.z)
