# Particle Life GPU Simulator
 
This project simulates up to 100K particles interacting with each other using a GPU backend through compute shaders. The simulation leverages spatial binning to handle particle interactions efficiently, ensuring high performance even with a large number of particles.

### Simulation Parameters  
NUM_PARTICLES: Specifies the number of particles in the simulation  
NUM_COLORS: Defines the number of different particle colors/types in the simulation  
PARTICLE_SCALE: Sets the scale/size of the particles  
UNIT_DISTANCE: The unit distance used in particle interaction calculations. Determines the range within which particles influence each other  
FRICTION: The friction factor applied to particle velocities, affecting how quickly they slow down  
MAX_VELOCITY: The maximum velocity a particle can attain  
TIME_SCALE: Scales the simulation time step, affecting the speed of the simulation  
FORCE_SCALE: Scales the force applied during particle interactions  
interaction_forces: A 2D array where each element represents the interaction force between different particle colors/types   
interaction_distances: A 2D array where each element represents the interaction distance between different particle colors/types  

### Tested on:  
CPU: AMD Ryzen 5 4600H 3.00 GHz  
RAM: 8 GB  
OS: Windows 11, Ubuntu 24.04  
GPU: Nvidia GTX 1650 Ti 4GB  

![Screenshot from 2024-07-02 17-48-40](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/a88aa28a-acac-448b-bd63-a746b547de90)
![Screenshot from 2024-07-02 18-47-57](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/876c213b-85c6-4155-a2f2-5b03e1ad5fd0)
![Screenshot from 2024-07-03 12-59-41](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/fdb51b9d-3a9c-438c-9e91-eaab4e609525)
![Screenshot from 2024-07-03 13-02-03](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/3373e851-00b7-4d10-a3b0-7a7193ce1d88)
![Screenshot from 2024-07-03 20-57-37](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/0a510534-73cc-41a7-a7d6-abb988d908a8)
![Screenshot from 2024-07-04 11-34-37](https://github.com/Subash-A-A/particle-life-gpu/assets/83503341/248beded-4706-48a9-9eef-077a506d9f32)
