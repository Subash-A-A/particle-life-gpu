layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 particles_pos[];
};

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec2 particles_vel[];
};

layout(set = 0, binding = 2, std430) restrict buffer Color {
    float colors[];
};

layout(set = 0, binding = 3, std430) restrict buffer Params {
    float num_particles;
    float num_colors;
    float unit_distance;
    float friction;
    float max_velocity;
    float time_scale;
    float force_scale;
    float image_size;
    float viewport_x;
    float viewport_y;
    float delta_time;
} params;

layout(set = 0, binding = 4, std430) restrict buffer InteractionForces {
    float interaction_forces[];
};

layout(set = 0, binding = 5, std430) restrict buffer InteractionDistances {
    float interaction_distances[];
};

layout(rgba16f, binding = 6) uniform image2D particles_data;