extends Node3D

var mouse_aim = Vector3()
var debug_text: String
var debug
var player
var player_cam_rotate
var player_cam_pitch
var player_cam

var start_pos_local_cube
var start_pos_planet_cube
var start_pos_stellar_cube
var start_pos_galactic_cube

var x_line
var y_line
var z_line

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	debug = $BG/UI/Debug/DebugText
	player = $BG/TestPlayer
	player.world = self
	player_cam = $BG/TestPlayer/CamRotate/CamPitch/Cam
	player_cam_rotate = $BG/TestPlayer/CamRotate
	player_cam_pitch = $BG/TestPlayer/CamRotate/CamPitch
	
	x_line = $BG/UI/Line2D_X
	y_line = $BG/UI/Line2D_Y
	z_line = $BG/UI/Line2D_Z

	# Put player in middle of chunk
	player.position = Vector3(player.local_chunk_size/2, player.local_chunk_size/2, player.local_chunk_size/2)
	player.fake_pos = player.position
	
	start_pos_local_cube = player.local_chunk_size/2
	start_pos_planet_cube = player.local_chunk_size*player.large_chunk_size/2
	start_pos_stellar_cube = player.local_chunk_size*pow(player.large_chunk_size, 2)/2
	start_pos_galactic_cube = player.local_chunk_size*pow(player.large_chunk_size, 3)/2

	$BG/LocalCube.mesh.set_size(Vector3(start_pos_local_cube*2, 1, start_pos_local_cube*2))
	$BG/LocalCube.set_position(Vector3(start_pos_local_cube, 0, start_pos_local_cube))

	$BG/PlanetCube.mesh.set_size(Vector3(start_pos_planet_cube*2, 1, start_pos_planet_cube*2))
	$BG/PlanetCube.set_position(Vector3(start_pos_planet_cube, 0, start_pos_planet_cube))

	$BG/StellarCube.mesh.set_size(Vector3(start_pos_stellar_cube*2, 1, start_pos_stellar_cube*2))
	$BG/StellarCube.set_position(Vector3((start_pos_stellar_cube), 0, (start_pos_stellar_cube)))

	$BG/GalacticCube.mesh.set_size(Vector3(start_pos_galactic_cube*2, 1, start_pos_galactic_cube*2))
	$BG/GalacticCube.set_position(Vector3((start_pos_galactic_cube), 0, (start_pos_galactic_cube)))

func _process(delta: float) -> void:
	
	## <--- Move cubes according player's chunk positions --->
	$BG/PlanetCube.position.x 
	
	## <--- Quit --->
	if Input.is_action_just_pressed("q"):
		get_tree().quit()
	
	## <--- Uncapture mouse --->
	if Input.is_action_just_pressed("esc"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	## <--- Teleport player an arbitrary "smaller" distance to test floating point precision --->
	var small_teleport_axis = Input.get_axis("j", "u")
	if Input.is_action_just_pressed("u") or Input.is_action_just_pressed("j"):
		var dir = -player_cam_pitch.get_node("Cam").global_basis.z * small_teleport_axis
		player.position += dir * 100000.0
		player.get_new_chunks()

	## <--- Teleport player an arbitrary "massive" distance to test floating point precision --->
	var large_teleport_axis = Input.get_axis("k", "i")
	if Input.is_action_just_pressed("i") or Input.is_action_just_pressed("k"):
		var dir = -player_cam_pitch.get_node("Cam").global_basis.z * large_teleport_axis
		player.position += dir * 1000000.0
		player.get_new_chunks()
		
	var player_global_pos = player.get_global_pos_in_chunk()

	debug_text = "All distances in METERS
Player position in Local chunk: {0}
Chunk coordinates:
	0: {1}
	1: {2}
	2: {3}
	3: {4}
Global position: ({5}, {6}, {7})
Distance from origin: {8}
Player Velocity: {9}

	".format([
		player.position.snappedf(0.001),
		player.chunk_levels[0]["coord"],
		player.chunk_levels[1]["coord"],
		player.chunk_levels[2]["coord"],
		player.chunk_levels[3]["coord"],
		snapped(player_global_pos[0], 0.001),
		snapped(player_global_pos[1], 0.001),
		snapped(player_global_pos[2], 0.001),
		snapped(sqrt(pow(player_global_pos[0], 2)+pow(player_global_pos[1], 2)+pow(player_global_pos[2], 2)), 0.001),
		snapped(player.linear_velocity.length(), 0.001)
	])

	debug.text = debug_text
	$FG/Viewport/FarPlayer.position = player.fake_pos
	$FG/Viewport/FarPlayer/CamRotate.rotation.y = player_cam_rotate.rotation.y
	$FG/Viewport/FarPlayer/CamRotate/CamPitch.rotation.x = player_cam_pitch.rotation.x

	# Place indicator origin in front of the camera (always relative to cam basis)
	var origin3D = player_cam.global_transform.origin + -player_cam.global_transform.basis.z * 10.0

	# World axes, not player_camera basis
	var x_axis3D = origin3D + Vector3(1, 0, 0)
	var y_axis3D = origin3D + Vector3(0, 1, 0)
	var z_axis3D = origin3D + Vector3(0, 0, 1)

	# Project into 2D
	var origin2D = Vector2(player_cam.unproject_position(origin3D).y*-1, player_cam.unproject_position(origin3D).x)
	var x_axis2D = Vector2(player_cam.unproject_position(x_axis3D).y*-1, player_cam.unproject_position(x_axis3D).x)
	var y_axis2D = Vector2(player_cam.unproject_position(y_axis3D).y*-1, player_cam.unproject_position(y_axis3D).x)
	var z_axis2D = Vector2(player_cam.unproject_position(z_axis3D).y*-1, player_cam.unproject_position(z_axis3D).x)

	x_line.points = [origin2D, x_axis2D]
	y_line.points = [origin2D, y_axis2D]
	z_line.points = [origin2D, z_axis2D]

func chunk_update(change, sizes):
	$BG/PlanetCube.position -= change[0]*sizes[0]
	$BG/StellarCube.position -= change[0]*sizes[0] + change[1]*sizes[1]
	$BG/GalacticCube.position -= change[0]*sizes[0] + change[1]*sizes[1] + change[2]*sizes[2]
	
