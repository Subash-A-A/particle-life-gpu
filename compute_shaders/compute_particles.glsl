#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position{
  vec2 particles_pos[];
};

layout(set = 0, binding = 1, std430) restrict buffer Velocity{
  vec2 particles_vel[];
};

layout(set = 0, binding = 2, std430) restrict buffer Color{
  float colors[];
};

layout(set = 0, binding = 3, std430) restrict buffer Params{
  float num_particles;
  float num_colors;
  float unit_distance;
  float time_scale;
  float image_size;
  float viewport_x;
  float viewport_y;
  float delta_time;
} params;

layout(set = 0, binding = 4) restrict buffer InteractionForces {
  float interaction_forces[];
};

layout(set = 0, binding = 5) restrict buffer InteractionDistances {
  float interaction_distances[];
};

layout(rgba16f, binding = 6) uniform image2D particles_data;

int get_index(float i, float j, float num_types) {
  return int(i * num_types + j);
}

float compute_force_val(float dist, float interaction_force_val, float interaction_dist_val){
  if(dist <= interaction_dist_val){
    return dist / interaction_dist_val - 1.0;
  }
  else if(dist > interaction_dist_val && interaction_dist_val < 1){
    return interaction_force_val * (1 - abs(2 * dist - 1 - interaction_dist_val) / (1 - interaction_dist_val));
  }
  return 0.0;
}

void main(){
  uint index = gl_GlobalInvocationID.x;
  if(index >= params.num_particles) return;

  vec2 my_pos = particles_pos[index];
  vec2 my_vel = particles_vel[index];
  float my_color = colors[index];

  vec2 totalForce = vec2(0, 0);
  for(uint i = 0; i < params.num_particles; i++){
    if (i == index) continue;

    vec2 other_pos = particles_pos[i];
    vec2 other_vel = particles_vel[i];
    float other_color = colors[i];

    vec2 direction = other_pos - my_pos;

    if(direction.x > params.viewport_x / 2){
      direction.x -= params.viewport_x;
    } else if(direction.x < -params.viewport_x / 2){
      direction.x += params.viewport_x;
    }
    if(direction.y > params.viewport_y / 2){
      direction.y -= params.viewport_y;
    } else if(direction.y < -params.viewport_y / 2){
      direction.y += params.viewport_y;
    }

    float dist = length(direction);

    int interaction_index = get_index(my_color, other_color, params.num_colors);
    float interaction_force_val = interaction_forces[interaction_index];
    float interaction_dist_val = interaction_distances[interaction_index];

    if(dist > 0.0 && dist < params.unit_distance){
      float force = compute_force_val(dist / params.unit_distance, interaction_force_val, interaction_dist_val);
      totalForce += (direction/dist) * force;
    }
  }

  totalForce *= params.unit_distance * 100.0;
  
  my_vel *= 0.05;
  my_vel += totalForce * params.delta_time * params.time_scale;
  my_pos += my_vel * params.delta_time * params.time_scale;

  my_pos = vec2(
    mod(my_pos.x, params.viewport_x),
    mod(my_pos.y, params.viewport_y)
  );

  particles_vel[index] = my_vel;
  particles_pos[index] = my_pos;

  ivec2 pixel_pos = ivec2(
      int(mod(index, params.image_size)),
      int(index / params.image_size)
  );

  imageStore(particles_data, pixel_pos, vec4(my_pos.x, my_pos.y, 0, my_color));
}