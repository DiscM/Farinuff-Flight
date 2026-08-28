extends RefCounted
class_name PlayerFlightTuning
## Shared reference tuning. Distances and speeds are in baseline screen pixels;
## native flight converts them through FlightSpace3D, never through a 2D actor.

const SPEED := 280.0
const ACCELERATION := 12.0
const DRAG := 14.0

const BOOST_DURATION := 0.68
const BOOST_DISTANCE := 340.0
const BOOST_STEER_RATE := 10.0
const BOOST_COOLDOWN := 0.85
const BOOST_HEADING_MIN_SPEED := 1.0
const POST_BOOST_SLIDE_DURATION := 0.4

const DRIFT_BONUS_MAX := 2.0
const DRIFT_BONUS_RATE := 0.45
const DRIFT_DECAY_RATE := 0.8
const DRIFT_DRAG_BASE := 1.6
const DRIFT_ACCEL_BASE := 2.4
const DRIFT_SPEED_RATIO := 2.5
const DRIFT_MIN_DRAG_FACTOR := 0.15
const DRIFT_MIN_ACCEL_FACTOR := 0.4

const BRAKE_INPUT_THRESHOLD := 0.1
const BRAKE_MIN_SPEED := 100.0
const BRAKE_OPPOSITION_DOT := -0.7
const BRAKE_DRAG := 22.0
const BRAKE_ACCELERATION := 2.0
const BRAKE_BONUS_DECAY := 5.0

const AIM_STICK_DEADZONE := 0.4
const AIM_MOUSE_MIN_DISTANCE := 30.0
const AIM_MOUSE_MIN_SPEED := 10.0
const AIM_RETICLE_DISTANCE := 60.0
