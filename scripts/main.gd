extends Node2D

@export_range(0, 100000) var NUM_PARTICLES := 60000 :set = _set_num_particles
@export_range(1, 16) var NUM_COLORS := 10
@export_range(0.5, 5) var PARTICLE_SCALE := 0.35
@export_range(1, 1000) var UNIT_DISTANCE := 64.0
@export_range(0.0, 1.0, 0.01) var FRICTION := .25
@export_range(0.0, 1000) var MAX_VELOCITY := 1000.0;
@export_range(1, 10) var TIME_SCALE := 0.05
@export_range(0, 1000) var FORCE_SCALE := 500.0
var COLORS: Array

var particles_pos: PackedVector2Array = PackedVector2Array()
var particles_vel: PackedVector2Array = PackedVector2Array()
var particles_color: PackedFloat32Array = PackedFloat32Array()

@export var interaction_forces: Array[Array] = []
@export var interaction_distances: Array[Array] = []

var IMAGE_SIZE: int
var particles_data: Image
var particles_data_texture: ImageTexture

# GPU Parameters
var rd: RenderingDevice
var particles_pipeline: RID
var particles_compute_shader: RID

var particles_pos_buffer: RID
var particles_vel_buffer: RID
var particles_color_buffer: RID
var params_buffer: RID
var params_uniform: RDUniform
var interaction_forces_buffer: RID
var interaction_forces_uniform: RDUniform
var interaction_distances_buffer: RID
var interaction_distances_uniform: RDUniform
var particles_data_buffer: RID

var bindings: Array
var uniform_set: RID

# Bin Variables
var BIN_SIZE : int = ceil(UNIT_DISTANCE)
var BINS : Vector2i = Vector2i.ZERO
var NUM_BINS : int = 0

var bin_sum_shader : RID
var bin_sum_pipeline : RID
var bin_prefix_sum_shader : RID
var bin_prefix_sum_pipeline : RID
var bin_reindex_shader : RID
var bin_reindex_pipeline : RID

var bin_buffer : RID
var bin_sum_buffer : RID
var bin_prefix_sum_buffer : RID
var bin_index_tracker_buffer : RID
var bin_reindex_buffer : RID
var bin_params_buffer : RID

# Temp variables
var original_time_scale = TIME_SCALE

func _ready():
	BINS = Vector2i(
		snapped(get_viewport_rect().size.x / BIN_SIZE + .4, 1),
		snapped(get_viewport_rect().size.y / BIN_SIZE + .4, 1)
	)
	NUM_BINS = BINS.x * BINS.y;
	print(NUM_BINS)
	
	_set_num_particles(NUM_PARTICLES)
	_generate_particles()
	_setup_random_matrices()
	
	particles_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	particles_data_texture = ImageTexture.create_from_image(particles_data)
	
	$GPUParticles2D.amount = NUM_PARTICLES
	$GPUParticles2D.process_material.set_shader_parameter("particles_data", particles_data_texture)
	$GPUParticles2D.process_material.set_shader_parameter("colors", COLORS)
	$GPUParticles2D.process_material.set_shader_parameter("scale", PARTICLE_SCALE)
	
	_setup_compute_shader()
	_update_particles(0)
	
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit(0)
		
	if Input.is_action_just_pressed("randomize_matrices"):
		pass
		
	TIME_SCALE = original_time_scale * 2.0 if Input.is_action_pressed("speed_up") else original_time_scale
	
	rd.sync()
	_update_data_texture()
	_update_particles(delta)

func _set_num_particles(value: int):
	NUM_PARTICLES = value
	IMAGE_SIZE = int(ceil(sqrt(NUM_PARTICLES)))

func _generate_particles():
	COLORS = generate_colors(NUM_COLORS)
	particles_pos = PackedVector2Array()
	particles_vel = PackedVector2Array()
	particles_color = PackedFloat32Array()
	
	for i in range(NUM_PARTICLES):
		particles_pos.push_back(Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y))
		particles_vel.push_back(Vector2.ZERO)
		particles_color.push_back(randi_range(0, NUM_COLORS - 1))

func _update_data_texture():
	var particles_data_image_data = rd.texture_get_data(particles_data_buffer, 0)
	particles_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH, particles_data_image_data)
	particles_data_texture.update(particles_data)

func _setup_random_matrices():
	interaction_forces = []
	interaction_distances = []
	for i in range(NUM_COLORS):
		var force_row = []
		var dist_row = []
		for j in range(NUM_COLORS):
			force_row.append(randf_range(-1, 1))
			dist_row.append(randf_range(0, 1))
		interaction_forces.append(force_row)
		interaction_distances.append(dist_row)

func _setup_compute_shader():
	rd = RenderingServer.create_local_rendering_device()
	var shader_file: RDShaderFile = load("res://compute_shaders/compute_particles.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	particles_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	particles_pipeline = rd.compute_pipeline_create(particles_compute_shader)
	
	particles_pos_buffer = _generate_vec2_buffer(particles_pos)
	var particles_pos_uniform = _generate_uniform(particles_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	particles_vel_buffer = _generate_vec2_buffer(particles_vel)
	var particles_vel_uniform = _generate_uniform(particles_vel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	particles_color_buffer = _generate_float_buffer(particles_color)
	var particles_color_uniform = _generate_uniform(particles_color_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	params_buffer = _generate_parameter_buffer(0)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	var interaction_forces_1d = []
	var interaction_distances_1d = []

	for i in range(NUM_COLORS):
		for j in range(NUM_COLORS):
			interaction_forces_1d.append(interaction_forces[i][j])
			interaction_distances_1d.append(interaction_distances[i][j])
	
	interaction_forces_buffer = _generate_float_buffer(interaction_forces_1d)
	interaction_forces_uniform = _generate_uniform(interaction_forces_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	
	interaction_distances_buffer = _generate_float_buffer(interaction_distances_1d)
	interaction_distances_uniform = _generate_uniform(interaction_distances_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()
	particles_data_buffer = rd.texture_create(fmt, view, [particles_data.get_data()])
	var particles_data_buffer_uniform = _generate_uniform(particles_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 6)
	
	shader_file = load("res://compute_shaders/bin_sum.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_sum_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_sum_pipeline = rd.compute_pipeline_create(bin_sum_shader)
	
	shader_file = load("res://compute_shaders/bin_prefix_sum.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_prefix_sum_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_prefix_sum_pipeline = rd.compute_pipeline_create(bin_prefix_sum_shader)
	
	shader_file = load("res://compute_shaders/bin_reindex.glsl")
	shader_spirv = shader_file.get_spirv()
	bin_reindex_shader = rd.shader_create_from_spirv(shader_spirv)
	bin_reindex_pipeline = rd.compute_pipeline_create(bin_reindex_shader)
	
	var bin_params_buffer_bytes = PackedInt32Array([BIN_SIZE, BINS.x, BINS.y, NUM_BINS]).to_byte_array()
	bin_params_buffer = rd.storage_buffer_create(bin_params_buffer_bytes.size(), bin_params_buffer_bytes)
	var bin_params_uniform = _generate_uniform(bin_params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 7)
	
	bin_buffer = _generate_int_buffer(NUM_PARTICLES)
	var bin_buffer_uniform = _generate_uniform(bin_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 8)
	
	bin_sum_buffer = _generate_int_buffer(NUM_PARTICLES)
	var bin_sum_buffer_uniform = _generate_uniform(bin_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 9)
	
	bin_prefix_sum_buffer = _generate_int_buffer(NUM_PARTICLES)
	var bin_prefix_sum_buffer_uniform = _generate_uniform(bin_prefix_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 10)
	
	bin_index_tracker_buffer = _generate_int_buffer(NUM_PARTICLES)
	var bin_index_tracker_buffer_uniform = _generate_uniform(bin_index_tracker_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 11)
	
	bin_reindex_buffer = _generate_int_buffer(NUM_PARTICLES)
	var bin_reindex_buffer_uniform = _generate_uniform(bin_reindex_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 12)
	
	bindings = [
		particles_pos_uniform, 
		particles_vel_uniform, 
		particles_color_uniform, 
		params_uniform, 
		interaction_forces_uniform, 
		interaction_distances_uniform, 
		particles_data_buffer_uniform,
		bin_params_uniform,
		bin_buffer_uniform,
		bin_sum_buffer_uniform,
		bin_prefix_sum_buffer_uniform,
		bin_index_tracker_buffer_uniform,
		bin_reindex_buffer_uniform
	]

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, int(ceil(NUM_PARTICLES / 1024.0)), 1, 1)
	rd.compute_list_end()
	rd.submit()

func _update_particles(delta):
	rd.free_rid(params_buffer)
	params_buffer = _generate_parameter_buffer(delta)
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	uniform_set = rd.uniform_set_create(bindings, particles_compute_shader, 0)
	
	_run_compute_shader(bin_sum_pipeline)
	rd.sync()
	_run_compute_shader(bin_prefix_sum_pipeline)
	rd.sync()
	_run_compute_shader(bin_reindex_pipeline)
	rd.sync()
	
	_run_compute_shader(particles_pipeline)

func _generate_int_buffer(size: int) -> RID:
	var data = []
	data.resize(size)
	var data_buffer_bytes = PackedInt32Array(data).to_byte_array()
	return rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)

func _generate_float_buffer(data: PackedFloat32Array) -> RID:
	var data_buffer_bytes = data.to_byte_array()
	return rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)

func _generate_vec2_buffer(data: PackedVector2Array) -> RID:
	var data_buffer_bytes = data.to_byte_array()
	return rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)

func _generate_uniform(data_buffer: RID, type: int, binding: int) -> RDUniform:
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform

func _generate_parameter_buffer(delta: float) -> RID:
	var params_buffer_bytes: PackedByteArray = PackedFloat32Array([
		float(NUM_PARTICLES),
		float(NUM_COLORS),
		UNIT_DISTANCE,
		FRICTION,
		MAX_VELOCITY,
		TIME_SCALE,
		FORCE_SCALE,
		float(IMAGE_SIZE),
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		delta
	]).to_byte_array()
	
	return rd.storage_buffer_create(params_buffer_bytes.size(), params_buffer_bytes)

func generate_colors(n: int) -> Array:
	var colors = []
	for i in range(n):
		var hue = float(i) / n
		var color = hsv_to_rgb(hue, 1.0, 1.0)
		colors.append(color)
	return colors

# Convert HSV to RGB
func hsv_to_rgb(h: float, s: float, v: float) -> Vector3:
	var r: float
	var g: float
	var b: float
	
	var i = int(h * 6.0)
	var f = h * 6.0 - i
	var p = v * (1.0 - s)
	var q = v * (1.0 - f * s)
	var t = v * (1.0 - (1.0 - f) * s)
	
	match (i % 6):
		0:
			r = v
			g = t
			b = p
		1:
			r = q
			g = v
			b = p
		2:
			r = p
			g = v
			b = t
		3:
			r = p
			g = q
			b = v
		4:
			r = t
			g = p
			b = v
		5:
			r = v
			g = p
			b = q
	
	return Vector3(r, g, b)

func _exit_tree():
	rd.sync()
	rd.free_rid(uniform_set)
	rd.free_rid(particles_data_buffer)
	rd.free_rid(params_buffer)
	rd.free_rid(particles_pos_buffer)
	rd.free_rid(particles_vel_buffer)
	rd.free_rid(particles_color_buffer)
	rd.free_rid(interaction_forces_buffer)
	rd.free_rid(interaction_distances_buffer)
	rd.free_rid(bin_buffer)
	rd.free_rid(bin_sum_buffer)
	rd.free_rid(bin_prefix_sum_buffer)
	rd.free_rid(bin_index_tracker_buffer)
	rd.free_rid(bin_reindex_buffer)
	rd.free_rid(bin_params_buffer)
	rd.free_rid(bin_sum_pipeline)
	rd.free_rid(bin_sum_shader)
	rd.free_rid(bin_prefix_sum_pipeline)
	rd.free_rid(bin_prefix_sum_shader)
	rd.free_rid(bin_reindex_pipeline)
	rd.free_rid(bin_reindex_shader)
	rd.free_rid(particles_pipeline)
	rd.free_rid(particles_compute_shader)
	rd.free()
