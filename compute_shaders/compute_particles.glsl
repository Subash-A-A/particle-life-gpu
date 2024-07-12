#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

int get_index(float i, float j, float num_types) {
    return int(i * num_types + j);
}

float compute_force_val(float normalized_dist, float interaction_force_val, float interaction_dist_val) {
    if (normalized_dist <= interaction_dist_val) {
        return normalized_dist / interaction_dist_val - 1.0;
    } else if (normalized_dist > interaction_dist_val && interaction_dist_val < 1.0) {
        return interaction_force_val * (1.0 - abs(2.0 * normalized_dist - 1.0 - interaction_dist_val) / (1.0 - interaction_dist_val));
    }
    return 0.0;
}

void main() {
    uint index = gl_GlobalInvocationID.x;
    if (index >= params.num_particles) return;

    vec2 my_pos = particles_pos[index];
    vec2 my_vel = particles_vel[index];
    float my_color = colors[index];
    
    int my_bin = bin.data[index];
    vec2 totalForce = vec2(0, 0);

    vec2 my_bin_x_y = one_to_two(my_bin, bin_params.bins_x);
    vec2 starting_bin = my_bin_x_y - vec2(1, 1);
    vec2 current_bin = starting_bin;

    for(int y = 0; y < 3; y++){
        current_bin.y = mod(starting_bin.y + y + bin_params.bins_y, bin_params.bins_y); // Wrap around in Y

        for(int x = 0; x < 3; x++){
            current_bin.x = mod(starting_bin.x + x + bin_params.bins_x, bin_params.bins_x); // Wrap around in X

            int current_bin_index = two_to_one(current_bin, bin_params.bins_x);

            for(int i = bin_prefix_sum.data[current_bin_index - 1]; i < bin_prefix_sum.data[current_bin_index]; i++){
                int other_index = bin_reindex.data[i];
                if(other_index != index){
                    vec2 other_pos = particles_pos[other_index];
                    float other_color = colors[other_index];

                    vec2 direction = other_pos - my_pos;

                    // Torus-like environment. Find min distance b/w two particles
                    if (direction.x > params.viewport_x / 2.0) {
                        direction.x -= params.viewport_x;
                    } else if (direction.x < -params.viewport_x / 2.0) {
                        direction.x += params.viewport_x;
                    }
                    if (direction.y > params.viewport_y / 2.0) {
                        direction.y -= params.viewport_y;
                    } else if (direction.y < -params.viewport_y / 2.0) {
                        direction.y += params.viewport_y;
                    }

                    float dist = length(direction);

                    if (dist > 0.0 && dist < params.unit_distance) {
                        int interaction_index = get_index(my_color, other_color, params.num_colors);
                        float interaction_force_val = interaction_forces[interaction_index];
                        float interaction_dist_val = interaction_distances[interaction_index];

                        float force = compute_force_val(dist / params.unit_distance, interaction_force_val, interaction_dist_val);
                        totalForce += (direction / dist) * force;
                    }
                }
            }
        }
    }

    totalForce *= params.unit_distance * params.force_scale;
    my_vel *= params.friction;
    my_vel += totalForce * params.delta_time * params.time_scale;

    // Clamp the velocity
    float vel_magnitude = length(my_vel);
    if (vel_magnitude > params.max_velocity) {
        my_vel = (my_vel / vel_magnitude) * params.max_velocity;
    }

    my_pos += my_vel * params.delta_time * params.time_scale;

    // Wrap around
    my_pos = mod(my_pos + vec2(params.viewport_x, params.viewport_y), vec2(params.viewport_x, params.viewport_y));

    particles_vel[index] = my_vel;
    particles_pos[index] = my_pos;

    bin.data[index] = int(my_pos.x / bin_params.bin_size) + int(my_pos.y / bin_params.bin_size) * bin_params.bins_x;

    ivec2 pixel_pos = ivec2(
        int(mod(index, params.image_size)),
        int(index / params.image_size)
    );

    imageStore(particles_data, pixel_pos, vec4(my_pos.x, my_pos.y, 0, my_color));
}
