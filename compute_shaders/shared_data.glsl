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

layout(set = 0, binding = 7, std430) restrict buffer BinParams {
    int bin_size;
    int bins_x;
    int bins_y;
    int num_bins;
} bin_params;

layout(set = 0, binding = 8, std430) restrict buffer Bin{
    int data[];
} bin;

layout(set = 0, binding = 9, std430) restrict buffer BinSum{
    int data[];
} bin_sum;

layout(set = 0, binding = 10, std430) restrict buffer BinPrefixSum{
    int data[];
} bin_prefix_sum;

layout(set = 0, binding = 11, std430) restrict buffer ReindexBin{
    int data[];
} bin_index_tracker;

layout(set = 0, binding = 12, std430) restrict buffer ReindexBinPositions{
    int data[];
} bin_reindex;

ivec2 one_to_two(int index, int grid_width){
    int row = int(index / grid_width);
    int col = int(mod(index, grid_width));
    return ivec2(col, row);
}

int two_to_one(vec2 index, int grid_width){
    int row = int(index.y);
    int col = int(index.x);
    return row * grid_width + col;
}