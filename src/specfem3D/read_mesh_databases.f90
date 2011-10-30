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
!
! United States and French Government Sponsorship Acknowledged.

  subroutine read_mesh_databases()

  use specfem_par
  use specfem_par_elastic
  use specfem_par_acoustic
  use specfem_par_poroelastic
  implicit none
  real(kind=CUSTOM_REAL):: minl,maxl,min_all,max_all
  integer :: ier,inum

! start reading the databasesa

! info about external mesh simulation
  call create_name_database(prname,myrank,LOCAL_PATH)
  open(unit=27,file=prname(1:len_trim(prname))//'external_mesh.bin',status='old',&
      action='read',form='unformatted',iostat=ier)
  if( ier /= 0 ) then
    print*,'error: could not open database '
    print*,'path: ',prname(1:len_trim(prname))//'external_mesh.bin'
    call exit_mpi(myrank,'error opening database')
  endif

  read(27) NSPEC_AB
  read(27) NGLOB_AB

  read(27) ibool

  read(27) xstore
  read(27) ystore
  read(27) zstore

  read(27) xix
  read(27) xiy
  read(27) xiz
  read(27) etax
  read(27) etay
  read(27) etaz
  read(27) gammax
  read(27) gammay
  read(27) gammaz
  read(27) jacobian

  read(27) kappastore
  read(27) mustore

  read(27) ispec_is_acoustic
  read(27) ispec_is_elastic
  read(27) ispec_is_poroelastic

  ! acoustic
  ! all processes will have acoustic_simulation set if any flag is .true.
  call any_all_l( ANY(ispec_is_acoustic), ACOUSTIC_SIMULATION )
  if( ACOUSTIC_SIMULATION ) then
    ! potentials
    allocate(potential_acoustic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array potential_acoustic'
    allocate(potential_dot_acoustic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array potential_dot_acoustic'
    allocate(potential_dot_dot_acoustic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array potential_dot_dot_acoustic'

    ! mass matrix, density
    allocate(rmass_acoustic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rmass_acoustic'
    allocate(rhostore(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rhostore'

    read(27) rmass_acoustic
    read(27) rhostore
  endif

  ! elastic
  call any_all_l( ANY(ispec_is_elastic), ELASTIC_SIMULATION )
  if( ELASTIC_SIMULATION ) then
    ! displacement,velocity,acceleration
    allocate(displ(NDIM,NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array displ'
    allocate(veloc(NDIM,NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array veloc'
    allocate(accel(NDIM,NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array accel'

    allocate(rmass(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rmass'
    allocate(rho_vp(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rho_vp'
    allocate(rho_vs(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rho_vs'
    allocate(c11store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c12store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c13store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c14store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c15store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c16store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c22store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c23store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c24store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c25store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c26store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c33store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c34store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c35store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c36store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c44store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c45store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c46store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c55store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c56store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO), &
            c66store(NGLLX,NGLLY,NGLLZ,NSPEC_ANISO),stat=ier)
    if( ier /= 0 ) stop 'error allocating array c11store etc.'

    ! note: currently, they need to be defined, as they are used in the routine arguments
    !          for compute_forces_elastic_Deville()
    allocate(R_xx(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            R_yy(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            R_xy(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            R_xz(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            R_yz(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS),stat=ier)
    if( ier /= 0 ) stop 'error allocating array R_xx etc.'

    ! needed for attenuation and/or kernel computations
    allocate(epsilondev_xx(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            epsilondev_yy(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            epsilondev_xy(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            epsilondev_xz(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            epsilondev_yz(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY),stat=ier)
    if( ier /= 0 ) stop 'error allocating array epsilondev_xx etc.'

    ! note: needed for argument of deville routine
    allocate(epsilon_trace_over_3(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array epsilon_trace_over_3'

    ! needed for attenuation
    allocate(one_minus_sum_beta(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB), &
            factor_common(N_SLS,NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array one_minus_sum_beta etc.'

    ! reads mass matrices
    read(27) rmass

    if( OCEANS ) then
      ! ocean mass matrix
      allocate(rmass_ocean_load(NGLOB_AB),stat=ier)
      if( ier /= 0 ) stop 'error allocating array rmass_ocean_load'
      read(27) rmass_ocean_load
    else
      ! dummy allocation
      allocate(rmass_ocean_load(1),stat=ier)
      if( ier /= 0 ) stop 'error allocating dummy array rmass_ocean_load'
    endif

    !pll material parameters for stacey conditions
    read(27) rho_vp
    read(27) rho_vs

  else
    ! no elastic attenuation & anisotropy
    ATTENUATION = .false.
    ANISOTROPY = .false.
  endif

  ! poroelastic
  call any_all_l( ANY(ispec_is_poroelastic), POROELASTIC_SIMULATION )
  if( POROELASTIC_SIMULATION ) then

    stop 'not implemented yet: read rmass_solid_poroelastic .. '

    allocate(rmass_solid_poroelastic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rmass_solid_poroelastic'
    allocate(rmass_fluid_poroelastic(NGLOB_AB),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rmass_fluid_poroelastic'

    read(27) rmass_solid_poroelastic
    read(27) rmass_fluid_poroelastic
  endif

! checks simulation types are valid
  if( (.not. ACOUSTIC_SIMULATION ) .and. &
     (.not. ELASTIC_SIMULATION ) .and. &
     (.not. POROELASTIC_SIMULATION ) ) then
     close(27)
     call exit_mpi(myrank,'error no simulation type defined')
  endif

! absorbing boundary surface
  read(27) num_abs_boundary_faces
  allocate(abs_boundary_ispec(num_abs_boundary_faces), &
          abs_boundary_ijk(3,NGLLSQUARE,num_abs_boundary_faces), &
          abs_boundary_jacobian2Dw(NGLLSQUARE,num_abs_boundary_faces), &
          abs_boundary_normal(NDIM,NGLLSQUARE,num_abs_boundary_faces),stat=ier)
  if( ier /= 0 ) stop 'error allocating array abs_boundary_ispec etc.'
  if( num_abs_boundary_faces > 0 ) then
    read(27) abs_boundary_ispec
    read(27) abs_boundary_ijk
    read(27) abs_boundary_jacobian2Dw
    read(27) abs_boundary_normal
  endif

! free surface
  read(27) num_free_surface_faces
  allocate(free_surface_ispec(num_free_surface_faces), &
          free_surface_ijk(3,NGLLSQUARE,num_free_surface_faces), &
          free_surface_jacobian2Dw(NGLLSQUARE,num_free_surface_faces), &
          free_surface_normal(NDIM,NGLLSQUARE,num_free_surface_faces),stat=ier)
  if( ier /= 0 ) stop 'error allocating array free_surface_ispec etc.'
  if( num_free_surface_faces > 0 ) then
    read(27) free_surface_ispec
    read(27) free_surface_ijk
    read(27) free_surface_jacobian2Dw
    read(27) free_surface_normal
  endif
! acoustic-elastic coupling surface
  read(27) num_coupling_ac_el_faces
  allocate(coupling_ac_el_normal(NDIM,NGLLSQUARE,num_coupling_ac_el_faces), &
          coupling_ac_el_jacobian2Dw(NGLLSQUARE,num_coupling_ac_el_faces), &
          coupling_ac_el_ijk(3,NGLLSQUARE,num_coupling_ac_el_faces), &
          coupling_ac_el_ispec(num_coupling_ac_el_faces),stat=ier)
  if( ier /= 0 ) stop 'error allocating array coupling_ac_el_normal etc.'
  if( num_coupling_ac_el_faces > 0 ) then
    read(27) coupling_ac_el_ispec
    read(27) coupling_ac_el_ijk
    read(27) coupling_ac_el_jacobian2Dw
    read(27) coupling_ac_el_normal
  endif

! MPI interfaces
  read(27) num_interfaces_ext_mesh
  allocate(my_neighbours_ext_mesh(num_interfaces_ext_mesh), &
          nibool_interfaces_ext_mesh(num_interfaces_ext_mesh),stat=ier)
  if( ier /= 0 ) stop 'error allocating array my_neighbours_ext_mesh etc.'
  if( num_interfaces_ext_mesh > 0 ) then
    read(27) max_nibool_interfaces_ext_mesh
    allocate(ibool_interfaces_ext_mesh(max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh),stat=ier)
    if( ier /= 0 ) stop 'error allocating array ibool_interfaces_ext_mesh'
    read(27) my_neighbours_ext_mesh
    read(27) nibool_interfaces_ext_mesh
    read(27) ibool_interfaces_ext_mesh
  else
    max_nibool_interfaces_ext_mesh = 0
    allocate(ibool_interfaces_ext_mesh(0,0),stat=ier)
  endif

  if( ANISOTROPY ) then
    read(27) c11store
    read(27) c12store
    read(27) c13store
    read(27) c14store
    read(27) c15store
    read(27) c16store
    read(27) c22store
    read(27) c23store
    read(27) c24store
    read(27) c25store
    read(27) c26store
    read(27) c33store
    read(27) c34store
    read(27) c35store
    read(27) c36store
    read(27) c44store
    read(27) c45store
    read(27) c46store
    read(27) c55store
    read(27) c56store
    read(27) c66store
  endif

  close(27)

  call sum_all_i(count(ispec_is_acoustic(:)),inum)
  if( myrank == 0 ) then
    write(IMAIN,*) 'total acoustic elements:',inum
  endif
  call sum_all_i(count(ispec_is_elastic(:)),inum)
  if( myrank == 0 ) then
    write(IMAIN,*) 'total elastic elements :',inum
  endif
  call sum_all_i(num_interfaces_ext_mesh,inum)
  if(myrank == 0) then
    write(IMAIN,*) 'number of MPI partition interfaces: ',inum
    write(IMAIN,*)
  endif


! MPI communications
  allocate(buffer_send_vector_ext_mesh(NDIM,max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
    buffer_recv_vector_ext_mesh(NDIM,max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
    buffer_send_scalar_ext_mesh(max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
    buffer_recv_scalar_ext_mesh(max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
    request_send_vector_ext_mesh(num_interfaces_ext_mesh), &
    request_recv_vector_ext_mesh(num_interfaces_ext_mesh), &
    request_send_scalar_ext_mesh(num_interfaces_ext_mesh), &
    request_recv_scalar_ext_mesh(num_interfaces_ext_mesh),stat=ier)
  if( ier /= 0 ) stop 'error allocating array buffer_send_vector_ext_mesh etc.'

! locate inner and outer elements
  call rmd_setup_inner_outer_elemnts()

!daniel: todo mesh coloring
!  call rmd_setup_color_perm()

! gets model dimensions
  minl = minval( xstore )
  maxl = maxval( xstore )
  call min_all_all_cr(minl,min_all)
  call max_all_all_cr(maxl,max_all)
  LONGITUDE_MIN = min_all
  LONGITUDE_MAX = max_all

  minl = minval( ystore )
  maxl = maxval( ystore )
  call min_all_all_cr(minl,min_all)
  call max_all_all_cr(maxl,max_all)
  LATITUDE_MIN = min_all
  LATITUDE_MAX = max_all

! check courant criteria on mesh
  if( ELASTIC_SIMULATION ) then
    call check_mesh_resolution(myrank,NSPEC_AB,NGLOB_AB, &
                              ibool,xstore,ystore,zstore, &
                              kappastore,mustore,rho_vp,rho_vs, &
                              DT,model_speed_max,min_resolved_period )
  else if( ACOUSTIC_SIMULATION ) then
      allocate(rho_vp(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
      if( ier /= 0 ) stop 'error allocating array rho_vp'
      allocate(rho_vs(NGLLX,NGLLY,NGLLZ,NSPEC_AB),stat=ier)
      if( ier /= 0 ) stop 'error allocating array rho_vs'
      rho_vp = sqrt( kappastore / rhostore ) * rhostore
      rho_vs = 0.0_CUSTOM_REAL
      call check_mesh_resolution(myrank,NSPEC_AB,NGLOB_AB, &
                                ibool,xstore,ystore,zstore, &
                                kappastore,mustore,rho_vp,rho_vs, &
                                DT,model_speed_max,min_resolved_period )
      deallocate(rho_vp,rho_vs)
  endif

! reads adjoint parameters
  call read_mesh_databases_adjoint()

  end subroutine read_mesh_databases

!
!-------------------------------------------------------------------------------------------------
!
  subroutine rmd_setup_inner_outer_elemnts()

  use specfem_par
  use specfem_par_elastic
  use specfem_par_acoustic
  implicit none
  ! local parameters
  integer :: i,j,k,ispec,iglob
  integer :: iinterface,ier
  character(len=256) :: filename
  logical,dimension(:),allocatable :: iglob_is_inner
  real :: percentage_edge

  ! allocates arrays
  allocate(ispec_is_inner(NSPEC_AB),stat=ier)
  if( ier /= 0 ) stop 'error allocating array ispec_is_inner'
  allocate(iglob_is_inner(NGLOB_AB),stat=ier)
  if( ier /= 0 ) stop 'error allocating temporary array  iglob_is_inner'

  ! initialize flags
  ispec_is_inner(:) = .true.
  iglob_is_inner(:) = .true.
  do iinterface = 1, num_interfaces_ext_mesh
    do i = 1, nibool_interfaces_ext_mesh(iinterface)
      iglob = ibool_interfaces_ext_mesh(i,iinterface)
      iglob_is_inner(iglob) = .false.
    enddo
  enddo

  ! determines flags for inner elements (purely inside the partition)
  do ispec = 1, NSPEC_AB
    do k = 1, NGLLZ
      do j = 1, NGLLY
        do i = 1, NGLLX
          iglob = ibool(i,j,k,ispec)
          ispec_is_inner(ispec) = ( iglob_is_inner(iglob) .and. ispec_is_inner(ispec) )
        enddo
      enddo
    enddo
  enddo

  ! frees temporary array
  deallocate( iglob_is_inner )

  if( SAVE_MESH_FILES ) then
    filename = prname(1:len_trim(prname))//'ispec_is_inner'
    call write_VTK_data_elem_l(NSPEC_AB,NGLOB_AB, &
                        xstore,ystore,zstore,ibool, &
                        ispec_is_inner,filename)
  endif

  ! sets up elements for loops in acoustic simulations
  if( ACOUSTIC_SIMULATION ) then
    ! counts inner and outer elements
    nspec_inner_acoustic = 0
    nspec_outer_acoustic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_acoustic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          nspec_inner_acoustic = nspec_inner_acoustic + 1
        else
          nspec_outer_acoustic = nspec_outer_acoustic + 1
        endif
      endif
    enddo

    ! stores indices of inner and outer elements for faster(?) computation
    num_phase_ispec_acoustic = max(nspec_inner_acoustic,nspec_outer_acoustic)
    allocate( phase_ispec_inner_acoustic(num_phase_ispec_acoustic,2),stat=ier)
    phase_ispec_inner_acoustic(:,:) = 0

    if( ier /= 0 ) stop 'error allocating array phase_ispec_inner_acoustic'
    nspec_inner_acoustic = 0
    nspec_outer_acoustic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_acoustic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          nspec_inner_acoustic = nspec_inner_acoustic + 1
          phase_ispec_inner_acoustic(nspec_inner_acoustic,2) = ispec
        else
          nspec_outer_acoustic = nspec_outer_acoustic + 1
          phase_ispec_inner_acoustic(nspec_outer_acoustic,1) = ispec
        endif
      endif
    enddo
    !print *,'rank ',myrank,' acoustic inner spec: ',nspec_inner_acoustic
    !print *,'rank ',myrank,' acoustic outer spec: ',nspec_outer_acoustic
  endif

  ! sets up elements for loops in acoustic simulations
  if( ELASTIC_SIMULATION ) then
    ! counts inner and outer elements
    nspec_inner_elastic = 0
    nspec_outer_elastic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_elastic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          nspec_inner_elastic = nspec_inner_elastic + 1
        else
          nspec_outer_elastic = nspec_outer_elastic + 1
        endif
      endif
    enddo

    ! stores indices of inner and outer elements for faster(?) computation
    num_phase_ispec_elastic = max(nspec_inner_elastic,nspec_outer_elastic)
    if( num_phase_ispec_elastic <= 0 ) stop 'error elastic simulation: num_phase_ispec_elastic is zero'

    allocate( phase_ispec_inner_elastic(num_phase_ispec_elastic,2),stat=ier)
    if( ier /= 0 ) stop 'error allocating array phase_ispec_inner_elastic'
    phase_ispec_inner_elastic(:,:) = 0

    nspec_inner_elastic = 0
    nspec_outer_elastic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_elastic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          nspec_inner_elastic = nspec_inner_elastic + 1
          phase_ispec_inner_elastic(nspec_inner_elastic,2) = ispec
        else
          nspec_outer_elastic = nspec_outer_elastic + 1
          phase_ispec_inner_elastic(nspec_outer_elastic,1) = ispec
        endif
      endif
    enddo
    !print *,'rank ',myrank,' elastic inner spec: ',nspec_inner_elastic
    !print *,'rank ',myrank,' elastic outer spec: ',nspec_outer_elastic
  endif

  if(myrank == 0) then
    percentage_edge = 100.*count(ispec_is_inner(:))/real(NSPEC_AB)
    write(IMAIN,*) 'for overlapping of communications with calculations:'
    write(IMAIN,*) '  percentage of   edge elements ',100. -percentage_edge,'%'
    write(IMAIN,*) '  percentage of volume elements ',percentage_edge,'%'
    write(IMAIN,*)
  endif


  end subroutine rmd_setup_inner_outer_elemnts

!
!-------------------------------------------------------------------------------------------------
!

!daniel: todo mesh coloring
  subroutine rmd_setup_color_perm()

  use specfem_par
  use specfem_par_elastic
  use specfem_par_acoustic
  implicit none
  ! local parameters
  ! added for color permutation
  integer :: nb_colors_outer_elements,nb_colors_inner_elements
  integer, dimension(:), allocatable :: perm
  integer, dimension(:), allocatable :: first_elem_number_in_this_color
  integer, dimension(:), allocatable :: num_of_elems_in_this_color

  integer :: icolor,ispec,ispec_counter
  integer :: nspec_outer,nspec_outer_min_global,nspec_outer_max_global

  integer :: ispec_inner_acoustic,ispec_outer_acoustic
  integer :: ispec_inner_elastic,ispec_outer_elastic
  integer :: nspec,nglob

  ! added for sorting
  integer, dimension(:,:,:,:), allocatable :: temp_array_int
  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable :: temp_array_real
  logical, dimension(:), allocatable :: temp_array_logical_1D
  !integer, dimension(:), allocatable :: temp_array_int_1D

  nspec = NSPEC_AB
  nglob = NGLOB_AB

  !!!! David Michea: detection of the edges, coloring and permutation separately
  allocate(perm(nspec))

  ! implement mesh coloring for GPUs if needed, to create subsets of disconnected elements
  ! to remove dependencies and the need for atomic operations in the sum of
  ! elemental contributions in the solver
  if(USE_MESH_COLORING_GPU) then

    allocate(first_elem_number_in_this_color(MAX_NUMBER_OF_COLORS + 1))

    call get_perm_color_faster(ispec_is_inner,ibool,perm,nspec,nglob, &
                              nb_colors_outer_elements,nb_colors_inner_elements, &
                              nspec_outer,first_elem_number_in_this_color,myrank)

    ! for the last color, the next color is fictitious and its first (fictitious) element number is nspec + 1
    first_elem_number_in_this_color(nb_colors_outer_elements + nb_colors_inner_elements + 1) = nspec + 1

    allocate(num_of_elems_in_this_color(nb_colors_outer_elements + nb_colors_inner_elements))

    ! save mesh coloring
    open(unit=99,file=prname(1:len_trim(prname))//'num_of_elems_in_this_color.dat',status='unknown')

    ! number of colors for outer elements
    write(99,*) nb_colors_outer_elements

    ! number of colors for inner elements
    write(99,*) nb_colors_inner_elements

    ! number of elements in each color
    do icolor = 1, nb_colors_outer_elements + nb_colors_inner_elements
      num_of_elems_in_this_color(icolor) = first_elem_number_in_this_color(icolor+1) - first_elem_number_in_this_color(icolor)
      write(99,*) num_of_elems_in_this_color(icolor)
    enddo
    close(99)

    ! check that the sum of all the numbers of elements found in each color is equal
    ! to the total number of elements in the mesh
    if(sum(num_of_elems_in_this_color) /= nspec) then
      print *,'nspec = ',nspec
      print *,'total number of elements in all the colors of the mesh = ',sum(num_of_elems_in_this_color)
      call exit_MPI(myrank, 'incorrect total number of elements in all the colors of the mesh')
    endif

    ! check that the sum of all the numbers of elements found in each color for the outer elements is equal
    ! to the total number of outer elements found in the mesh
    if(sum(num_of_elems_in_this_color(1:nb_colors_outer_elements)) /= nspec_outer) then
      print *,'nspec_outer = ',nspec_outer
      print *,'total number of elements in all the colors of the mesh for outer elements = ',sum(num_of_elems_in_this_color)
      call exit_MPI(myrank, 'incorrect total number of elements in all the colors of the mesh for outer elements')
    endif

    deallocate(first_elem_number_in_this_color)
    deallocate(num_of_elems_in_this_color)

  else

!! DK DK for regular C + MPI version for CPUs: do not use colors but nonetheless put all the outer elements
!! DK DK first in order to be able to overlap non-blocking MPI communications with calculations

!! DK DK nov 2010, for Rosa Badia / StarSs:
!! no need for mesh coloring, but need to implement inner/outer subsets for non blocking MPI for StarSs
    ispec_counter = 0
    perm(:) = 0

    ! first generate all the outer elements
    do ispec = 1,nspec
      if( ispec_is_inner(ispec) .eqv. .false.) then
        ispec_counter = ispec_counter + 1
        perm(ispec) = ispec_counter
      endif
    enddo

    ! make sure we have detected some outer elements
    !if(ispec_counter <= 0) call exit_MPI(myrank, 'fatal error: no outer elements detected!')

    ! store total number of outer elements
    nspec_outer = ispec_counter

    ! then generate all the inner elements
    do ispec = 1,nspec
      if( ispec_is_inner(ispec) .eqv. .true.) then
        ispec_counter = ispec_counter + 1
        perm(ispec) = ispec_counter - nspec_outer ! starts again at 1
      endif
    enddo

    ! test that all the elements have been used once and only once
    if(ispec_counter /= nspec) call exit_MPI(myrank, 'fatal error: ispec_counter not equal to nspec')

    ! do basic checks
    if(minval(perm) /= 1) call exit_MPI(myrank, 'minval(perm) should be 1')
    !if(maxval(perm) /= nspec) call exit_MPI(myrank, 'maxval(perm) should be nspec')


  endif

  ! sets up elements for loops in acoustic simulations
  if( ACOUSTIC_SIMULATION ) then
    ispec_inner_acoustic = 0
    ispec_outer_acoustic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_acoustic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          !ispec_inner_acoustic = ispec_inner_acoustic + 1
          ispec_inner_acoustic = perm(ispec)
          if( ispec_inner_acoustic < 1 .or. ispec_inner_acoustic > num_phase_ispec_acoustic ) &
            call exit_MPI(myrank,'error inner acoustic permutation')

          phase_ispec_inner_acoustic(ispec_inner_acoustic,2) = ispec

        else
          !ispec_outer_acoustic = ispec_outer_acoustic + 1
          ispec_outer_acoustic = perm(ispec)
          if( ispec_outer_acoustic < 1 .or. ispec_outer_acoustic > num_phase_ispec_acoustic ) &
            call exit_MPI(myrank,'error outer acoustic permutation')

          phase_ispec_inner_acoustic(ispec_outer_acoustic,1) = ispec

        endif
      endif
    enddo
  endif

  ! sets up elements for loops in elastic simulations
  if( ELASTIC_SIMULATION ) then
    ispec_inner_elastic = 0
    ispec_outer_elastic = 0
    do ispec = 1, NSPEC_AB
      if( ispec_is_elastic(ispec) ) then
        if( ispec_is_inner(ispec) .eqv. .true. ) then
          !ispec_inner_elastic = ispec_inner_elastic + 1
          ispec_inner_elastic = perm(ispec)
          if( ispec_inner_elastic < 1 .or. ispec_inner_elastic > num_phase_ispec_elastic ) then
            print*,'error: inner elastic permutation',ispec_inner_elastic,num_phase_ispec_elastic,nspec_outer
            call exit_MPI(myrank,'error inner elastic permutation')
          endif
          phase_ispec_inner_elastic(ispec_inner_elastic,2) = ispec

        else
          !ispec_outer_elastic = ispec_outer_elastic + 1
          ispec_outer_elastic = perm(ispec)
          if( ispec_outer_elastic < 1 .or. ispec_outer_elastic > num_phase_ispec_elastic ) then
            print*,'error: outer elastic permutation',ispec_outer_elastic,num_phase_ispec_elastic,nspec_outer
            call exit_MPI(myrank,'error outer elastic permutation')
          endif
          phase_ispec_inner_elastic(ispec_outer_elastic,1) = ispec

        endif
      endif
    enddo
  endif

  ! sorts array according to permutation
  ! SORT_MESH_INNER_OUTER
!daniel
  if( .false. ) then

    ! permutation of ibool
    allocate(temp_array_int(NGLLX,NGLLY,NGLLZ,nspec))
    call permute_elements_integer(ibool,temp_array_int,perm,nspec)
    deallocate(temp_array_int)

    ! element domain flags
    allocate(temp_array_logical_1D(nglob))
    temp_array_logical_1D(:) = ispec_is_acoustic
    do ispec = 1, nspec
      ispec_is_acoustic(perm(ispec)) = temp_array_logical_1D(ispec)
    enddo
    temp_array_logical_1D(:) = ispec_is_elastic
    do ispec = 1, nspec
      ispec_is_elastic(perm(ispec)) = temp_array_logical_1D(ispec)
    enddo
    !temp_array_logical_1D(:) = ispec_is_poroelastic
    !do ispec = 1, nspec
    !  ispec_is_poroelastic(perm(ispec)) = temp_array_logical_1D(ispec)
    !enddo
    deallocate(temp_array_logical_1D)

    ! mesh arrays
    allocate(temp_array_real(NGLLX,NGLLY,NGLLZ,nspec))
    call permute_elements_real(xix,temp_array_real,perm,nspec)
    call permute_elements_real(xiy,temp_array_real,perm,nspec)
    call permute_elements_real(xiz,temp_array_real,perm,nspec)
    call permute_elements_real(etax,temp_array_real,perm,nspec)
    call permute_elements_real(etay,temp_array_real,perm,nspec)
    call permute_elements_real(etaz,temp_array_real,perm,nspec)
    call permute_elements_real(gammax,temp_array_real,perm,nspec)
    call permute_elements_real(gammay,temp_array_real,perm,nspec)
    call permute_elements_real(gammaz,temp_array_real,perm,nspec)
    call permute_elements_real(jacobian,temp_array_real,perm,nspec)

    call permute_elements_real(kappastore,temp_array_real,perm,nspec)
    call permute_elements_real(mustore,temp_array_real,perm,nspec)

    ! acoustic arrays
    if( ACOUSTIC_SIMULATION ) then
      call permute_elements_real(rhostore,temp_array_real,perm,nspec)
    endif

    ! elastic arrays
    if( ELASTIC_SIMULATION ) then
      call permute_elements_real(rho_vp,temp_array_real,perm,nspec)
      call permute_elements_real(rho_vs,temp_array_real,perm,nspec)
      if( ANISOTROPY ) then
        call permute_elements_real(c11store,temp_array_real,perm,nspec)
        call permute_elements_real(c12store,temp_array_real,perm,nspec)
        call permute_elements_real(c13store,temp_array_real,perm,nspec)
        call permute_elements_real(c14store,temp_array_real,perm,nspec)
        call permute_elements_real(c15store,temp_array_real,perm,nspec)
        call permute_elements_real(c16store,temp_array_real,perm,nspec)
        call permute_elements_real(c22store,temp_array_real,perm,nspec)
        call permute_elements_real(c23store,temp_array_real,perm,nspec)
        call permute_elements_real(c24store,temp_array_real,perm,nspec)
        call permute_elements_real(c25store,temp_array_real,perm,nspec)
        call permute_elements_real(c33store,temp_array_real,perm,nspec)
        call permute_elements_real(c34store,temp_array_real,perm,nspec)
        call permute_elements_real(c35store,temp_array_real,perm,nspec)
        call permute_elements_real(c36store,temp_array_real,perm,nspec)
        call permute_elements_real(c44store,temp_array_real,perm,nspec)
        call permute_elements_real(c45store,temp_array_real,perm,nspec)
        call permute_elements_real(c46store,temp_array_real,perm,nspec)
        call permute_elements_real(c55store,temp_array_real,perm,nspec)
        call permute_elements_real(c56store,temp_array_real,perm,nspec)
        call permute_elements_real(c66store,temp_array_real,perm,nspec)
      endif
    endif

    deallocate(temp_array_real)
  endif

  ! user output
  !call MPI_ALLREDUCE(nspec_outer,nspec_outer_min_global,1,MPI_INTEGER,MPI_MIN,MPI_COMM_WORLD,ier)
  !call MPI_ALLREDUCE(nspec_outer,nspec_outer_max_global,1,MPI_INTEGER,MPI_MAX,MPI_COMM_WORLD,ier)
  call min_all_i(nspec_outer,nspec_outer_min_global)
  call max_all_i(nspec_outer,nspec_outer_max_global)
  call min_all_i(nspec_outer,nspec_outer_min_global)
  call max_all_i(nspec_outer,nspec_outer_max_global)

  if(myrank == 0) then
    write(IMAIN,*) 'mesh coloring:'
    write(IMAIN,*) '  permutation   : use coloring = ',USE_MESH_COLORING_GPU
    write(IMAIN,*) '  outer elements: min = ',nspec_outer_min_global
    write(IMAIN,*) '                  max = ',nspec_outer_max_global
    write(IMAIN,*)
  endif

  deallocate(perm)

  end subroutine rmd_setup_color_perm

!
!-------------------------------------------------------------------------------------------------
!

  subroutine read_mesh_databases_adjoint()

! reads in moho meshes

  use specfem_par
  use specfem_par_elastic
  use specfem_par_acoustic
  use specfem_par_poroelastic
  implicit none

  integer :: ier

! allocates adjoint arrays for elastic simulations
  if( ELASTIC_SIMULATION .and. SIMULATION_TYPE == 3 ) then
    ! backward displacement,velocity,acceleration fields
    allocate(b_displ(NDIM,NGLOB_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_displ'
    allocate(b_veloc(NDIM,NGLOB_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_veloc'
    allocate(b_accel(NDIM,NGLOB_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_accel'

    ! adjoint kernels

    ! primary, isotropic kernels
    ! density kernel
    allocate(rho_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rho_kl'
    ! shear modulus kernel
    allocate(mu_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array mu_kl'
    ! compressional modulus kernel
    allocate(kappa_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array kappa_kl'

    ! derived kernels
    ! density prime kernel
    allocate(rhop_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rhop_kl'
    ! vp kernel
    allocate(alpha_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array alpha_kl'
    ! vs kernel
    allocate(beta_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array beta_kl'

    ! noise source strength kernel
    if (NOISE_TOMOGRAPHY == 3) then
      allocate(sigma_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
      if( ier /= 0 ) stop 'error allocating array sigma_kl'
    endif

    ! preconditioner
    if ( APPROXIMATE_HESS_KL ) then
      allocate(hess_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
      if( ier /= 0 ) stop 'error allocating array hess_kl'
    else
      ! dummy allocation
      allocate(hess_kl(0,0,0,0),stat=ier)
      if( ier /= 0 ) stop 'error allocating dummy array hess_kl'
    endif

    ! MPI handling
    allocate(b_request_send_vector_ext_mesh(num_interfaces_ext_mesh), &
      b_request_recv_vector_ext_mesh(num_interfaces_ext_mesh), &
      b_buffer_send_vector_ext_mesh(NDIM,max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
      b_buffer_recv_vector_ext_mesh(NDIM,max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_request_send_vector_ext_mesh etc.'

    ! allocates attenuation solids
    allocate(b_R_xx(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            b_R_yy(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            b_R_xy(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            b_R_xz(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS), &
            b_R_yz(NGLLX,NGLLY,NGLLZ,NSPEC_ATTENUATION_AB,N_SLS),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_R_xx etc.'

    ! note: these arrays are needed for attenuation and/or kernel computations
    allocate(b_epsilondev_xx(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            b_epsilondev_yy(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            b_epsilondev_xy(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            b_epsilondev_xz(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY), &
            b_epsilondev_yz(NGLLX,NGLLY,NGLLZ,NSPEC_STRAIN_ONLY),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_epsilon_dev_xx etc.'
    ! needed for kernel computations
    allocate(b_epsilon_trace_over_3(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_epsilon_trace_over_3'

  else
    ! modification: Camille Mazoyer
    ! dummy allocation
    allocate(b_displ(1,1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array b_displ'
    allocate(b_veloc(1,1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array b_veloc'
    allocate(b_accel(1,1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array b_accel'

  endif

! allocates adjoint arrays for acoustic simulations
  if( ACOUSTIC_SIMULATION .and. SIMULATION_TYPE == 3 ) then

    ! backward potentials
    allocate(b_potential_acoustic(NGLOB_ADJOINT), &
            b_potential_dot_acoustic(NGLOB_ADJOINT), &
            b_potential_dot_dot_acoustic(NGLOB_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_potential_acoustic etc.'

    ! kernels
    allocate(rho_ac_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT), &
            rhop_ac_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT), &
            kappa_ac_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT), &
            alpha_ac_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
    if( ier /= 0 ) stop 'error allocating array rho_ac_kl etc.'

    ! preconditioner
    if ( APPROXIMATE_HESS_KL ) then
      allocate(hess_ac_kl(NGLLX,NGLLY,NGLLZ,NSPEC_ADJOINT),stat=ier)
      if( ier /= 0 ) stop 'error allocating array hess_ac_kl'
    else
      ! dummy allocation
      allocate(hess_ac_kl(0,0,0,0),stat=ier)
      if( ier /= 0 ) stop 'error allocating dummy array hess_ac_kl'
    endif

    ! MPI handling
    allocate(b_request_send_scalar_ext_mesh(num_interfaces_ext_mesh), &
      b_request_recv_scalar_ext_mesh(num_interfaces_ext_mesh), &
      b_buffer_send_scalar_ext_mesh(max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh), &
      b_buffer_recv_scalar_ext_mesh(max_nibool_interfaces_ext_mesh,num_interfaces_ext_mesh),stat=ier)
    if( ier /= 0 ) stop 'error allocating array b_request_send_scalar_ext_mesh'

  else

    ! backward potentials
    allocate(b_potential_acoustic(1), &
            b_potential_dot_acoustic(1), &
            b_potential_dot_dot_acoustic(1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array b_potential_acoustic etc.'

    ! kernels
    allocate(rho_ac_kl(1,1,1,1), &
            rhop_ac_kl(1,1,1,1), &
            kappa_ac_kl(1,1,1,1), &
            alpha_ac_kl(1,1,1,1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array rho_ac_kl etc.'

    ! MPI handling
    allocate(b_request_send_scalar_ext_mesh(1), &
            b_request_recv_scalar_ext_mesh(1), &
            b_buffer_send_scalar_ext_mesh(1,1), &
            b_buffer_recv_scalar_ext_mesh(1,1),stat=ier)
    if( ier /= 0 ) stop 'error allocating dummy array b_request_send_scalar_ext_mesh etc.'

  endif

! ADJOINT moho
! moho boundary
  if( ELASTIC_SIMULATION ) then
    allocate( is_moho_top(NSPEC_BOUN),is_moho_bot(NSPEC_BOUN),stat=ier)
    if( ier /= 0 ) stop 'error allocating array is_moho_top etc.'

    if( SAVE_MOHO_MESH .and. SIMULATION_TYPE == 3 ) then

      ! boundary elements
      !open(unit=27,file=prname(1:len_trim(prname))//'ibelm_moho.bin',status='unknown',form='unformatted')
      open(unit=27,file=prname(1:len_trim(prname))//'ibelm_moho.bin',status='old',&
            form='unformatted',iostat=ier)
      if( ier /= 0 ) then
        print*,'error: could not open ibelm_moho '
        print*,'path: ',prname(1:len_trim(prname))//'ibelm_moho.bin'
        call exit_mpi(myrank,'error opening ibelm_moho')
      endif

      read(27) NSPEC2D_MOHO

      ! allocates arrays for moho mesh
      allocate(ibelm_moho_bot(NSPEC2D_MOHO), &
              ibelm_moho_top(NSPEC2D_MOHO), &
              normal_moho_top(NDIM,NGLLSQUARE,NSPEC2D_MOHO), &
              normal_moho_bot(NDIM,NGLLSQUARE,NSPEC2D_MOHO), &
              ijk_moho_bot(3,NGLLSQUARE,NSPEC2D_MOHO), &
              ijk_moho_top(3,NGLLSQUARE,NSPEC2D_MOHO),stat=ier)
      if( ier /= 0 ) stop 'error allocating array ibelm_moho_bot etc.'

      read(27) ibelm_moho_top
      read(27) ibelm_moho_bot
      read(27) ijk_moho_top
      read(27) ijk_moho_bot

      close(27)

      ! normals
      open(unit=27,file=prname(1:len_trim(prname))//'normal_moho.bin',status='old',&
            form='unformatted',iostat=ier)
      if( ier /= 0 ) then
        print*,'error: could not open normal_moho '
        print*,'path: ',prname(1:len_trim(prname))//'normal_moho.bin'
        call exit_mpi(myrank,'error opening normal_moho')
      endif

      read(27) normal_moho_top
      read(27) normal_moho_bot
      close(27)

      ! flags
      open(unit=27,file=prname(1:len_trim(prname))//'is_moho.bin',status='old',&
            form='unformatted',iostat=ier)
      if( ier /= 0 ) then
        print*,'error: could not open is_moho '
        print*,'path: ',prname(1:len_trim(prname))//'is_moho.bin'
        call exit_mpi(myrank,'error opening is_moho')
      endif

      read(27) is_moho_top
      read(27) is_moho_bot

      close(27)

      ! moho kernel
      allocate( moho_kl(NGLLSQUARE,NSPEC2D_MOHO),stat=ier)
      if( ier /= 0 ) stop 'error allocating array moho_kl'
      moho_kl = 0._CUSTOM_REAL

    else
      NSPEC2D_MOHO = 1
    endif

    allocate( dsdx_top(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,NSPEC2D_MOHO), &
             dsdx_bot(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,NSPEC2D_MOHO), &
             b_dsdx_top(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,NSPEC2D_MOHO), &
             b_dsdx_bot(NDIM,NDIM,NGLLX,NGLLY,NGLLZ,NSPEC2D_MOHO),stat=ier)
    if( ier /= 0 ) stop 'error allocating array dsdx_top etc.'
  endif

  end subroutine read_mesh_databases_adjoint
