/*
 !=====================================================================
 !
 !               S p e c f e m 3 D  V e r s i o n  2 . 0
 !               ---------------------------------------
 !
 !          Main authors: Dimitri Komatitsch and Jeroen Tromp
 !    Princeton University, USA and University of Pau / CNRS / INRIA
 ! (c) Princeton University / California Institute of Technology and University of Pau / CNRS / INRIA
 !                            April 2011
 !
 ! This program is free software; you can redistribute it and/or modify
 ! it under the terms of the GNU General Public License as published by
 ! the Free Software Foundation; either version 2 of the License, or
 ! (at your option) any later version.
 !
 ! This program is distributed in the hope that it will be useful,
 ! but WITHOUT ANY WARRANTY; without even the implied warranty of
 ! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ! GNU General Public License for more details.
 !
 ! You should have received a copy of the GNU General Public License along
 ! with this program; if not, write to the Free Software Foundation, Inc.,
 ! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 !
 !=====================================================================
 */

#include <stdio.h>
#include <cuda.h>
#include <cublas.h>
#include <mpi.h>
#include <sys/types.h>
#include <unistd.h>

#include "config.h"
#include "mesh_constants_cuda.h"
// #include "epik_user.h"


/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(fortranflush,FORTRANFLUSH)(int* rank){
TRACE("fortranflush");

  fflush(stdout);
  fflush(stderr);
  printf("Flushing proc %d!\n",*rank);
}

/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(fortranprint,FORTRANPRINT)(int* id) {
TRACE("fortranprint");

  int procid;
  MPI_Comm_rank(MPI_COMM_WORLD,&procid);
  printf("%d: sends msg_id %d\n",procid,*id);
}

/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(fortranprintf,FORTRANPRINTF)(float* val) {
TRACE("fortranprintf");

  int procid;
  MPI_Comm_rank(MPI_COMM_WORLD,&procid);
  printf("%d: sends val %e\n",procid,*val);
}

/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(fortranprintd,FORTRANPRINTD)(double* val) {
TRACE("fortranprintd");

  int procid;
  MPI_Comm_rank(MPI_COMM_WORLD,&procid);
  printf("%d: sends val %e\n",procid,*val);
}

/* ----------------------------------------------------------------------------------------------- */

// randomize displ for testing
extern "C"
void FC_FUNC_(make_displ_rand,MAKE_DISPL_RAND)(long* Mesh_pointer_f,float* h_displ) {
TRACE("make_displ_rand");

  Mesh* mp = (Mesh*)(*Mesh_pointer_f); // get Mesh from fortran integer wrapper
  // float* displ_rnd = (float*)malloc(mp->NGLOB_AB*3*sizeof(float));
  for(int i=0;i<mp->NGLOB_AB*3;i++) {
    h_displ[i] = rand();
  }
  cudaMemcpy(mp->d_displ,h_displ,mp->NGLOB_AB*3*sizeof(float),cudaMemcpyHostToDevice);
}

/* ----------------------------------------------------------------------------------------------- */

__global__ void transfer_surface_to_host_kernel(int* free_surface_ispec,
                                                int* free_surface_ijk,
                                                int num_free_surface_faces,
                                                int* ibool,
                                                realw* displ,
                                                realw* noise_surface_movie) {
  int igll = threadIdx.x;
  int iface = blockIdx.x + blockIdx.y*gridDim.x;

  // int id = tx + blockIdx.x*blockDim.x + blockIdx.y*blockDim.x*gridDim.x;

  if(iface < num_free_surface_faces) {
    int ispec = free_surface_ispec[iface]-1; //-1 for C-based indexing

    int i = free_surface_ijk[INDEX3(NDIM,NGLL2,0,igll,iface)]-1;
    int j = free_surface_ijk[INDEX3(NDIM,NGLL2,1,igll,iface)]-1;
    int k = free_surface_ijk[INDEX3(NDIM,NGLL2,2,igll,iface)]-1;

    int iglob = ibool[INDEX4(5,5,5,i,j,k,ispec)]-1;

    noise_surface_movie[INDEX3(NDIM,NGLL2,0,igll,iface)] = displ[iglob*3];
    noise_surface_movie[INDEX3(NDIM,NGLL2,1,igll,iface)] = displ[iglob*3+1];
    noise_surface_movie[INDEX3(NDIM,NGLL2,2,igll,iface)] = displ[iglob*3+2];
  }
}

/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(transfer_surface_to_host,
              TRANSFER_SURFACE_TO_HOST)(long* Mesh_pointer_f,
                                        realw* h_noise_surface_movie) {
TRACE("transfer_surface_to_host");

  Mesh* mp = (Mesh*)(*Mesh_pointer_f); // get Mesh from fortran integer wrapper

  int num_blocks_x = mp->num_free_surface_faces;
  int num_blocks_y = 1;
  while(num_blocks_x > 65535) {
    num_blocks_x = ceil(num_blocks_x/2.0);
    num_blocks_y = num_blocks_y*2;
  }
  dim3 grid(num_blocks_x,num_blocks_y,1);
  dim3 threads(25,1,1);

  transfer_surface_to_host_kernel<<<grid,threads>>>(mp->d_free_surface_ispec,
                                                    mp->d_free_surface_ijk,
                                                    mp->num_free_surface_faces,
                                                    mp->d_ibool,
                                                    mp->d_displ,
                                                    mp->d_noise_surface_movie);

  cudaMemcpy(h_noise_surface_movie,mp->d_noise_surface_movie,
             3*25*(mp->num_free_surface_faces)*sizeof(realw),cudaMemcpyDeviceToHost);

#ifdef ENABLE_VERY_SLOW_ERROR_CHECKING
  exit_on_cuda_error("transfer_surface_to_host");
#endif
}

/* ----------------------------------------------------------------------------------------------- */

__global__ void noise_read_add_surface_movie_cuda_kernel(realw* accel, int* ibool,
                                                         int* free_surface_ispec,
                                                         int* free_surface_ijk,
                                                         int num_free_surface_faces,
                                                         realw* noise_surface_movie,
                                                         realw* normal_x_noise,
                                                         realw* normal_y_noise,
                                                         realw* normal_z_noise,
                                                         realw* mask_noise,
                                                         realw* free_surface_jacobian2Dw //,float* d_debug
                                                         ) {

  int iface = blockIdx.x + gridDim.x*blockIdx.y; // surface element id

  // when nspec_top > 65535, but mod(nspec_top,2) > 0, we end up with an extra block.
  if(iface < num_free_surface_faces) {
    int ispec = free_surface_ispec[iface]-1;

    int igll = threadIdx.x;

    int ipoin = 25*iface + igll;
    int i=free_surface_ijk[INDEX3(NDIM,NGLL2,0,igll,iface)]-1;
    int j=free_surface_ijk[INDEX3(NDIM,NGLL2,1,igll,iface)]-1;
    int k=free_surface_ijk[INDEX3(NDIM,NGLL2,2,igll,iface)]-1;

    int iglob = ibool[INDEX4(5,5,5,i,j,k,ispec)]-1;

    realw normal_x = normal_x_noise[ipoin];
    realw normal_y = normal_y_noise[ipoin];
    realw normal_z = normal_z_noise[ipoin];

    realw eta = (noise_surface_movie[INDEX3(NDIM,NGLL2,0,igll,iface)]*normal_x +
                noise_surface_movie[INDEX3(NDIM,NGLL2,1,igll,iface)]*normal_y +
                noise_surface_movie[INDEX3(NDIM,NGLL2,2,igll,iface)]*normal_z);

    // error from cuda-memcheck and ddt seems "incorrect", because we
    // are passing a __constant__ variable pointer around like it was
    // made using cudaMalloc, which *may* be "incorrect", but produces
    // correct results.

    // ========= Invalid __global__ read of size
    // 4 ========= at 0x00000cd8 in
    // compute_add_sources_cuda.cu:260:noise_read_add_surface_movie_cuda_kernel
    // ========= by thread (0,0,0) in block (3443,0) ========= Address
    // 0x203000c8 is out of bounds

    // non atomic version for speed testing -- atomic updates are needed for correctness
    // accel[3*iglob] +=   eta*mask_noise[ipoin] * normal_x * wgllwgll_xy[tx] * free_surface_jacobian2Dw[tx + 25*ispec2D];
    // accel[3*iglob+1] += eta*mask_noise[ipoin] * normal_y * wgllwgll_xy[tx] * free_surface_jacobian2Dw[tx + 25*ispec2D];
    // accel[3*iglob+2] += eta*mask_noise[ipoin] * normal_z * wgllwgll_xy[tx] * free_surface_jacobian2Dw[tx + 25*ispec2D];

    // Fortran version in SVN -- note deletion of wgllwgll_xy?
    // accel(1,iglob) = accel(1,iglob) + eta * mask_noise(ipoin) * normal_x_noise(ipoin) &
    // * free_surface_jacobian2Dw(igll,iface)
    // accel(2,iglob) = accel(2,iglob) + eta * mask_noise(ipoin) * normal_y_noise(ipoin) &
    // * free_surface_jacobian2Dw(igll,iface)
    // accel(3,iglob) = accel(3,iglob) + eta * mask_noise(ipoin) * normal_z_noise(ipoin) &
    // * free_surface_jacobian2Dw(igll,iface) ! wgllwgll_xy(i,j) * jacobian2D_top(i,j,iface)

    // atomicAdd(&accel[iglob*3]  ,eta*mask_noise[ipoin]*normal_x*wgllwgll_xy[tx]*free_surface_jacobian2Dw[igll+25*iface]);
    // atomicAdd(&accel[iglob*3+1],eta*mask_noise[ipoin]*normal_y*wgllwgll_xy[tx]*free_surface_jacobian2Dw[igll+25*iface]);
    // atomicAdd(&accel[iglob*3+2],eta*mask_noise[ipoin]*normal_z*wgllwgll_xy[tx]*free_surface_jacobian2Dw[igll+25*iface]);

    atomicAdd(&accel[iglob*3]  ,eta*mask_noise[ipoin]*normal_x*free_surface_jacobian2Dw[igll+25*iface]);
    atomicAdd(&accel[iglob*3+1],eta*mask_noise[ipoin]*normal_y*free_surface_jacobian2Dw[igll+25*iface]);
    atomicAdd(&accel[iglob*3+2],eta*mask_noise[ipoin]*normal_z*free_surface_jacobian2Dw[igll+25*iface]);

  }
}

/* ----------------------------------------------------------------------------------------------- */

extern "C"
void FC_FUNC_(noise_read_add_surface_movie_cu,
              NOISE_READ_ADD_SURFACE_MOVIE_CU)(long* Mesh_pointer_f,
                                               realw* h_noise_surface_movie,
                                               int* NOISE_TOMOGRAPHYf) {
TRACE("noise_read_add_surface_movie_cu");

  // EPIK_TRACER("noise_read_add_surface_movie_cu");

  Mesh* mp = (Mesh*)(*Mesh_pointer_f); //get mesh pointer out of fortran integer container
  int NOISE_TOMOGRAPHY = *NOISE_TOMOGRAPHYf;

  //float* d_noise_surface_movie;
  //cudaMalloc((void**)&d_noise_surface_movie,3*25*num_free_surface_faces*sizeof(float));
  //cudaMemcpy(d_noise_surface_movie, h_noise_surface_movie,
  //           3*25*num_free_surface_faces*sizeof(realw),cudaMemcpyHostToDevice);

  cudaMemcpy(mp->d_noise_surface_movie,h_noise_surface_movie,
             3*25*(mp->num_free_surface_faces)*sizeof(float),cudaMemcpyHostToDevice);

  int num_blocks_x = mp->num_free_surface_faces;
  int num_blocks_y = 1;
  while(num_blocks_x > 65535) {
    num_blocks_x = ceil(num_blocks_x/2.0);
    num_blocks_y = num_blocks_y*2;
  }
  dim3 grid(num_blocks_x,num_blocks_y,1);
  dim3 threads(25,1,1);

  // float* h_debug = (float*)calloc(128,sizeof(float));
  //float* d_debug;
  // cudaMalloc((void**)&d_debug,128*sizeof(float));
  // cudaMemcpy(d_debug,h_debug,128*sizeof(float),cudaMemcpyHostToDevice);

  if(NOISE_TOMOGRAPHY == 2) { // add surface source to forward field
    noise_read_add_surface_movie_cuda_kernel<<<grid,threads>>>(mp->d_accel,
                                                               mp->d_ibool,
                                                               mp->d_free_surface_ispec,
                                                               mp->d_free_surface_ijk,
                                                               mp->num_free_surface_faces,
                                                               mp->d_noise_surface_movie,
                                                               mp->d_normal_x_noise,
                                                               mp->d_normal_y_noise,
                                                               mp->d_normal_z_noise,
                                                               mp->d_mask_noise,
                                                               mp->d_free_surface_jacobian2Dw //,d_debug
                                                               );
  }
  else if(NOISE_TOMOGRAPHY == 3) { // add surface source to adjoint (backward) field
    noise_read_add_surface_movie_cuda_kernel<<<grid,threads>>>(mp->d_b_accel,
                                                               mp->d_ibool,
                                                               mp->d_free_surface_ispec,
                                                               mp->d_free_surface_ijk,
                                                               mp->num_free_surface_faces,
                                                               mp->d_noise_surface_movie,
                                                               mp->d_normal_x_noise,
                                                               mp->d_normal_y_noise,
                                                               mp->d_normal_z_noise,
                                                               mp->d_mask_noise,
                                                               mp->d_free_surface_jacobian2Dw //,d_debug
                                                               );
  }

  // cudaMemcpy(h_debug,d_debug,128*sizeof(float),cudaMemcpyDeviceToHost);
  // for(int i=0;i<8;i++) {
  // printf("debug[%d]= %e\n",i,h_debug[i]);
  // }
  // MPI_Abort(MPI_COMM_WORLD,1);
  //cudaFree(d_noise_surface_movie);
#ifdef ENABLE_VERY_SLOW_ERROR_CHECKING
  exit_on_cuda_error("noise_read_add_surface_movie_cuda_kernel");
#endif
}
