extends Node2D

@export_range(0, 100000) var NUM_PARTICLES := 30000 :set = _set_num_particles
@export_range(1, 16) var NUM_COLORS := 3
@export_range(0.5, 5) var PARTICLE_SCALE := 0.5
@export_range(1, 1000) var UNIT_DISTANCE := 100.0
@export_range(0.0, 1.0, 0.01) var FRICTION := 0.05
@export_range(0.0, 1000) var MAX_VELOCITY := 1000.0;
@export_range(1, 10) var TIME_SCALE := 0.05
@export_range(0, 1000) var FORCE_SCALE := 50.0
@export var COLORS: PackedVector3Array

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
var pipeline: RID
var compute_shader: RID

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

var original_time_scale = TIME_SCALE

func _ready():
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
		_setup_random_matrices()
		
	TIME_SCALE = original_time_scale * 2.0 if Input.is_action_pressed("speed_up") else original_time_scale
	
	rd.sync()
	_update_data_texture()
	_update_particles(delta)

func _set_num_particles(value: int):
	NUM_PARTICLES = value
	IMAGE_SIZE = int(ceil(sqrt(NUM_PARTICLES)))

func _generate_particles():
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
			dist_row.append(randf_range(0.25, 1))
		interaction_forces.append(force_row)
		interaction_distances.append(dist_row)

func _setup_compute_shader():
	rd = RenderingServer.create_local_rendering_device()
	var shader_file: RDShaderFile = load("res://compute_shaders/compute_particles.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	compute_shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(compute_shader)
	
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
	
	bindings = [
		particles_pos_uniform, particles_vel_uniform, particles_color_uniform, 
		params_uniform, interaction_forces_uniform, interaction_distances_uniform, 
		particles_data_buffer_uniform
	]

func _update_particles(delta):
	rd.free_rid(params_buffer)
	params_buffer = _generate_parameter_buffer(delta)
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	uniform_set = rd.uniform_set_create(bindings, compute_shader, 0)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, int(ceil(NUM_PARTICLES / 1024.0)), 1, 1)
	rd.compute_list_end()
	rd.submit()

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
	rd.free_rid(pipeline)
	rd.free_rid(compute_shader)
	rd.free()
