extends RefCounted
## Physical service berths, shared by world signs, proximity checks and the HUD.

const Layout := preload("res://systems/crescent_harbor_layout.gd")
const STATION_SCALE := Layout.STATION_SCALE
const INTERACTION_RADIUS := 12.0
const SECTIONS: Array[Dictionary] = [
	{"id": &"launch_bay", "title": "LAUNCH BAY", "description": "Choose your ship and launch an expedition.", "color": Color("ffd66d"), "position": Layout.DOCK_POSITION, "station_node": &"Wayfarer_Core"},
	{"id": &"hangar", "title": "HANGAR", "description": "Upgrade ship systems, unlock hulls and spend salvage.", "color": Color("5ce8df"), "position": Vector3(82, 0, -46), "station_node": &"Relay_05_RefuelRepair"},
	{"id": &"flight_school", "title": "FLIGHT SCHOOL", "description": "Learn flight controls and practice boost reflection.", "color": Color("8bbdff"), "position": Vector3(-84, 0, -10), "station_node": &"Relay_01_TrafficMast"},
	{"id": &"expedition_map", "title": "ROUTE MAP", "description": "Explore the route home and discovered sectors.", "color": Color("ac9bff"), "position": Vector3(48, 0, -98), "station_node": &"Relay_04_PortApproach"},
	{"id": &"archives", "title": "ARCHIVES", "description": "Read recovered signals and expedition records.", "color": Color("f4a2cf"), "position": Vector3(-5, 0, -98), "station_node": &"Relay_03_OrbitalLogistics"},
	{"id": &"settings", "title": "SETTINGS", "description": "Adjust controls, sound, display and accessibility.", "color": Color("98de9b"), "position": Vector3(-45, 0, -51), "station_node": &"Relay_02_PowerDistribution"},
]


static func find(section_id: StringName) -> Dictionary:
	for section in SECTIONS:
		if section.id == section_id:
			return section
	return {}


static func nearest(point: Vector3) -> Dictionary:
	var closest: Dictionary = SECTIONS[0]
	var distance := INF
	for section in SECTIONS:
		var candidate: float = point.distance_squared_to(section.position)
		if candidate < distance:
			distance = candidate
			closest = section
	return closest
