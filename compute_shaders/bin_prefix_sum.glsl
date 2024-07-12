#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

void main(){
    int index = int(gl_GlobalInvocationID.x);
    if(index >= bin_params.num_bins) return;

    bin_prefix_sum.data[index] = 0;

    for(int i = 0; i <= index; i++){
        bin_prefix_sum.data[index] += bin_sum.data[i];
    }

    barrier();

    bin_index_tracker.data[index] = 0;
    if(index > 0){
        bin_index_tracker.data[index] = bin_prefix_sum.data[index - 1];
    }
}