#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

void main(){

    int index = int(gl_GlobalInvocationID.x);

    if(index < bin_params.num_bins){
        bin_sum.data[index] = 0;
    }

    barrier();

    if(index < params.num_particles){
        atomicAdd(bin_sum.data[bin.data[index]], 1);
    }
}