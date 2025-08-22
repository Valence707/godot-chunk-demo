extends RigidBody3D

var chunk_levels = [
	{"coord": Vector3i.ZERO, "size": 0 }, # local_chunk_size
	{"coord": Vector3i.ZERO, "size": 0 }, # to be filled later
	{"coord": Vector3i.ZERO, "size": 0 },
	{"coord": Vector3i.ZERO, "size": 0 }
]

var local_chunk_size = 1000.0
var large_chunk_size = 2
var input_dir
var mouse_aim = Vector3()
var accel = 1000.0
var world

var fake_pos = Vector3.ZERO
var fake_pos_offset = Vector3.ZERO

func _ready() -> void:
	
	# Set up initial chunk sizes
	chunk_levels[0].size = local_chunk_size
	for i in range(1, chunk_levels.size()):
		chunk_levels[i].size = chunk_levels[i-1].size * large_chunk_size

func _physics_process(delta: float) -> void:
	## <--- Get player movement input --->
	input_dir = Vector3(Input.get_axis("a", "d"), Input.get_axis("shift", "space"), Input.get_axis("w", "s")).normalized()

	if Input.is_action_pressed("e"):
		linear_damp = 10.0
	else:
		linear_damp = 1.0

	## <--- Rotate the camera --->
	if mouse_aim.length() > 0.0:
		$CamRotate.rotate_y(deg_to_rad(-mouse_aim.x / 10.0))
		$CamRotate/CamPitch.rotate_x(deg_to_rad(-mouse_aim.y / 10.0))

		# Optional: clamp vertical pitch
		$CamRotate/CamPitch.rotation.x = clamp(
			$CamRotate/CamPitch.rotation.x,
			deg_to_rad(-89),
			deg_to_rad(89)
		)
		mouse_aim = Vector2.ZERO

	if input_dir.length() > 0.0:
		# Use only yaw (CamRotate), ignore pitch
		var yaw_basis = $CamRotate.global_transform.basis

		# Project forward/right onto the XZ plane
		var forward = yaw_basis.z
		forward.y = 0
		forward = forward.normalized()

		var right = yaw_basis.x
		right.y = 0
		right = right.normalized()

		# Build movement from input_dir (x = left/right, z = forward/back, y = up/down)
		var force_dir = (forward * input_dir.z) + (right * input_dir.x) + Vector3.UP * input_dir.y
		force_dir = force_dir.normalized()

		apply_central_force(force_dir * accel)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if linear_velocity.length() > 0.0:
		#for i in ["x", "y", "z"]:
			#fake_pos[i] = position[i]
			#for j in range(chunk_levels.size()):
				#fake_pos[i] += chunk_levels[j]["coord"][i]*chunk_levels[0]["size"]

		get_new_chunks()

## <--- Update chunk coordinates, player position, and chunk delta --->
# Returns change in chunks and chunk sizes
func get_new_chunks(scale=0):
	var update = false
	var res
	var change = []
	var sizes = []
	var old_chunks = chunk_levels.duplicate(true)

	## <--- Detect changes in chunks --->
	# This part modifies the lowest chunk coords, which then affects the higher chunk coords
	# And also updates player's position to remain anchored in chunk.
	for i in ["x", "y", "z"]:
		res = divmod_floor(position[i], int(chunk_levels[0]["size"]))
		chunk_levels[0]["coord"][i] += res[0]
		position[i] = res[1]

	# For each chunk level, get the current position from the chunk below.
	for i in range(1+scale, chunk_levels.size()):
		chunk_levels[i]["last_coord"] = chunk_levels[i]["coord"]

		# Work on each axis separately
		for j in ["x", "y", "z"]:
			res = divmod_floor(chunk_levels[i-1]["coord"][j], large_chunk_size)
			chunk_levels[i]["coord"][j] += res[0]
			chunk_levels[i-1]["coord"][j] = res[1]
			
	for i in range(chunk_levels.size()):
		var chunk_change = Vector3i(chunk_levels[i]["coord"] - old_chunks[i]["coord"])
		change.append(chunk_change)
		sizes.append(chunk_levels[i]["size"])
		if chunk_change:
			update = true

	fake_pos = position + fake_pos_offset
	## <--- If a chunk update has occurred, call necessary updates --->
	if update:
		# Call chunk transition updates here
		fake_pos_offset = Vector3.ZERO
		for i in range(chunk_levels.size()):
			for j in ["x", "y", "z"]:
				fake_pos_offset[j] += chunk_levels[i]["coord"][j]*sizes[i]
				
		fake_pos += fake_pos_offset
		world.chunk_update(change, sizes)

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_aim = event.relative

func get_global_pos_in_chunk():
	var global_pos = [position.x, position.y, position.z]

	for i in range(chunk_levels.size()):
		var chunk = chunk_levels[i]
		global_pos[0] += chunk['coord'].x * chunk["size"]
		global_pos[1] += chunk['coord'].y * chunk["size"]
		global_pos[2] += chunk['coord'].z * chunk["size"]
	
	return global_pos

func divmod_floor(value: float, size: float) -> Array:
	var q = floor(value / size)
	var r = value - q * size
	return [int(q), r]
