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

    vec2 totalForce = vec2(0, 0);
    for (uint i = 0; i < params.num_particles; i++) {
        if (i == index) continue;

        vec2 other_pos = particles_pos[i];
        float other_color = colors[i];

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

    ivec2 pixel_pos = ivec2(
        int(mod(index, params.image_size)),
        int(index / params.image_size)
    );

    imageStore(particles_data, pixel_pos, vec4(my_pos.x, my_pos.y, 0, my_color));
}
