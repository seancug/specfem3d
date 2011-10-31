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


  subroutine write_seismograms()

! writes the seismograms with time shift

  use specfem_par
  use specfem_par_acoustic
  use specfem_par_elastic
  use specfem_par_poroelastic
  implicit none
  ! local parameters
  real(kind=CUSTOM_REAL),dimension(NDIM,NGLLX,NGLLY,NGLLZ):: displ_element,veloc_element
  double precision :: dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd
  integer :: irec_local,irec
  integer :: iglob,ispec,i,j,k
  ! adjoint locals
  real(kind=CUSTOM_REAL),dimension(NDIM,NDIM):: eps_s
  real(kind=CUSTOM_REAL),dimension(NDIM):: eps_m_s
  real(kind=CUSTOM_REAL):: stf_deltat
  double precision :: stf

  ! gets resulting array values onto CPU
  if(GPU_MODE) then
    if( nrec_local > 0 ) then
      ! this transfers fields only in elements with stations for efficiency
      if( ACOUSTIC_SIMULATION ) then
        ! only copy corresponding elements to CPU host
        ! timing: Elapsed time: 5.230904e-04
        call transfer_station_ac_from_device( &
                        potential_acoustic,potential_dot_acoustic,potential_dot_dot_acoustic, &
                        b_potential_acoustic,b_potential_dot_acoustic,b_potential_dot_dot_acoustic, &
                        Mesh_pointer,number_receiver_global, &
                        ispec_selected_rec,ispec_selected_source,ibool,SIMULATION_TYPE)

        ! alternative: transfers whole fields
        ! timing: Elapsed time: 4.138947e-03
        !call transfer_fields_ac_from_device(NGLOB_AB,potential_acoustic, &
        !          potential_dot_acoustic,potential_dot_dot_acoustic,Mesh_pointer)
      endif

      ! this transfers fields only in elements with stations for efficiency
      if( ELASTIC_SIMULATION ) then
        call transfer_station_el_from_device( &
                    displ,veloc,accel, &
                    b_displ,b_veloc,b_accel, &
                    Mesh_pointer,number_receiver_global, &
                    ispec_selected_rec,ispec_selected_source, &
                    ibool,SIMULATION_TYPE)

        ! alternative: transfers whole fields
        !  call transfer_fields_el_from_device(NDIM*NGLOB_AB,displ,veloc, accel, Mesh_pointer)
      endif
    endif
  endif

  do irec_local = 1,nrec_local

    ! gets global number of that receiver
    irec = number_receiver_global(irec_local)

    ! gets local receiver interpolators
    ! (1-D Lagrange interpolators)
    hxir(:) = hxir_store(irec_local,:)
    hetar(:) = hetar_store(irec_local,:)
    hgammar(:) = hgammar_store(irec_local,:)

    ! forward simulations
    if (SIMULATION_TYPE == 1)  then

      ! receiver's spectral element
      ispec = ispec_selected_rec(irec)

      ! elastic wave field
      if( ispec_is_elastic(ispec) ) then
        ! interpolates displ/veloc/accel at receiver locations
        call compute_interpolated_dva(displ,veloc,accel,NGLOB_AB, &
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)
      endif !elastic

      ! acoustic wave field
      if( ispec_is_acoustic(ispec) ) then
        ! displacement vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_AB, &
                        potential_acoustic, displ_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)
        ! velocity vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_AB, &
                        potential_dot_acoustic, veloc_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)

        ! interpolates displ/veloc/pressure at receiver locations
        call compute_interpolated_dva_ac(displ_element,veloc_element,&
                        potential_dot_dot_acoustic,potential_dot_acoustic,&
                        potential_acoustic,NGLOB_AB, &
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)
      endif ! acoustic

    !adjoint simulations
    else if (SIMULATION_TYPE == 2) then

      ! adjoint source is placed at receiver
      ispec = ispec_selected_source(irec)

      ! elastic wave field
      if( ispec_is_elastic(ispec) ) then
        ! interpolates displ/veloc/accel at receiver locations
        call compute_interpolated_dva(displ,veloc,accel,NGLOB_AB, &
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)

        ! stores elements displacement field
        do k = 1,NGLLZ
          do j = 1,NGLLY
            do i = 1,NGLLX
              iglob = ibool(i,j,k,ispec)
              displ_element(:,i,j,k) = displ(:,iglob)
            enddo
          enddo
        enddo

        ! gets derivatives of local receiver interpolators
        hpxir(:) = hpxir_store(irec_local,:)
        hpetar(:) = hpetar_store(irec_local,:)
        hpgammar(:) = hpgammar_store(irec_local,:)

        ! computes the integrated derivatives of source parameters (M_jk and X_s)
        call compute_adj_source_frechet(displ_element,Mxx(irec),Myy(irec),Mzz(irec),&
                      Mxy(irec),Mxz(irec),Myz(irec),eps_s,eps_m_s, &
                      hxir,hetar,hgammar,hpxir,hpetar,hpgammar, &
                      hprime_xx,hprime_yy,hprime_zz, &
                      xix(:,:,:,ispec),xiy(:,:,:,ispec),xiz(:,:,:,ispec), &
                      etax(:,:,:,ispec),etay(:,:,:,ispec),etaz(:,:,:,ispec), &
                      gammax(:,:,:,ispec),gammay(:,:,:,ispec),gammaz(:,:,:,ispec))

        stf = comp_source_time_function(dble(NSTEP-it)*DT-t0-tshift_cmt(irec),hdur_gaussian(irec))
        stf_deltat = stf * deltat
        Mxx_der(irec_local) = Mxx_der(irec_local) + eps_s(1,1) * stf_deltat
        Myy_der(irec_local) = Myy_der(irec_local) + eps_s(2,2) * stf_deltat
        Mzz_der(irec_local) = Mzz_der(irec_local) + eps_s(3,3) * stf_deltat
        Mxy_der(irec_local) = Mxy_der(irec_local) + 2 * eps_s(1,2) * stf_deltat
        Mxz_der(irec_local) = Mxz_der(irec_local) + 2 * eps_s(1,3) * stf_deltat
        Myz_der(irec_local) = Myz_der(irec_local) + 2 * eps_s(2,3) * stf_deltat

        sloc_der(:,irec_local) = sloc_der(:,irec_local) + eps_m_s(:) * stf_deltat
      endif ! elastic

      ! acoustic wave field
      if( ispec_is_acoustic(ispec) ) then
        ! displacement vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_AB, &
                        potential_acoustic, displ_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)
        ! velocity vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_AB, &
                        potential_dot_acoustic, veloc_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)

        ! interpolates displ/veloc/pressure at receiver locations
        call compute_interpolated_dva_ac(displ_element,veloc_element,&
                        potential_dot_dot_acoustic,potential_dot_acoustic,&
                        potential_acoustic,NGLOB_AB, &
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)
      endif ! acoustic

    !adjoint simulations
    else if (SIMULATION_TYPE == 3) then

      ispec = ispec_selected_rec(irec)

      ! elastic wave field
      if( ispec_is_elastic(ispec) ) then
        ! backward fields: interpolates displ/veloc/accel at receiver locations
        call compute_interpolated_dva(b_displ,b_veloc,b_accel,NGLOB_ADJOINT,&
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)
      endif ! elastic

      ! acoustic wave field
      if( ispec_is_acoustic(ispec) ) then
        ! backward fields: displacement vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_ADJOINT, &
                        b_potential_acoustic, displ_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)
        ! backward fields: velocity vector
        call compute_gradient(ispec,NSPEC_AB,NGLOB_ADJOINT, &
                        b_potential_dot_acoustic, veloc_element,&
                        hprime_xx,hprime_yy,hprime_zz, &
                        xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz, &
                        ibool,rhostore)

        ! backward fields: interpolates displ/veloc/pressure at receiver locations
        call compute_interpolated_dva_ac(displ_element,veloc_element,&
                        b_potential_dot_dot_acoustic,b_potential_dot_acoustic,&
                        b_potential_acoustic,NGLOB_ADJOINT, &
                        ispec,NSPEC_AB,ibool, &
                        xi_receiver(irec),eta_receiver(irec),gamma_receiver(irec), &
                        hxir,hetar,hgammar, &
                        dxd,dyd,dzd,vxd,vyd,vzd,axd,ayd,azd)
      endif ! acoustic

    endif ! SIMULATION_TYPE

! store North, East and Vertical components
! distinguish between single and double precision for reals
    if(CUSTOM_REAL == SIZE_REAL) then
      seismograms_d(:,irec_local,it) = sngl((nu(:,1,irec)*dxd + nu(:,2,irec)*dyd + nu(:,3,irec)*dzd))
      seismograms_v(:,irec_local,it) = sngl((nu(:,1,irec)*vxd + nu(:,2,irec)*vyd + nu(:,3,irec)*vzd))
      seismograms_a(:,irec_local,it) = sngl((nu(:,1,irec)*axd + nu(:,2,irec)*ayd + nu(:,3,irec)*azd))
    else
      seismograms_d(:,irec_local,it) = (nu(:,1,irec)*dxd + nu(:,2,irec)*dyd + nu(:,3,irec)*dzd)
      seismograms_v(:,irec_local,it) = (nu(:,1,irec)*vxd + nu(:,2,irec)*vyd + nu(:,3,irec)*vzd)
      seismograms_a(:,irec_local,it) = (nu(:,1,irec)*axd + nu(:,2,irec)*ayd + nu(:,3,irec)*azd)
    endif

    !adjoint simulations
    if (SIMULATION_TYPE == 2) seismograms_eps(:,:,irec_local,it) = eps_s(:,:)

  enddo ! nrec_local

! write the current or final seismograms
  if((mod(it,NTSTEP_BETWEEN_OUTPUT_SEISMOS) == 0 .or. it == NSTEP) .and. (.not.SU_FORMAT)) then
    if (SIMULATION_TYPE == 1 .or. SIMULATION_TYPE == 3) then
      call write_seismograms_to_file(myrank,seismograms_d,number_receiver_global,station_name, &
            network_name,nrec,nrec_local,it,DT,NSTEP,t0,LOCAL_PATH,1,SIMULATION_TYPE)
      call write_seismograms_to_file(myrank,seismograms_v,number_receiver_global,station_name, &
            network_name,nrec,nrec_local,it,DT,NSTEP,t0,LOCAL_PATH,2,SIMULATION_TYPE)
      call write_seismograms_to_file(myrank,seismograms_a,number_receiver_global,station_name, &
            network_name,nrec,nrec_local,it,DT,NSTEP,t0,LOCAL_PATH,3,SIMULATION_TYPE)
    else
      call write_adj_seismograms_to_file(myrank,seismograms_d,number_receiver_global, &
            nrec_local,it,DT,NSTEP,t0,LOCAL_PATH,1)
    endif
  endif

! write ONE binary file for all receivers (nrec_local) within one proc
! SU format, with 240-byte-header for each trace
  if ((mod(it,NTSTEP_BETWEEN_OUTPUT_SEISMOS) == 0 .or. it==NSTEP) .and. SU_FORMAT) &
     call write_seismograms_su()

  end subroutine write_seismograms


!================================================================


! write seismograms to text files

  subroutine write_seismograms_to_file(myrank,seismograms,number_receiver_global, &
               station_name,network_name,nrec,nrec_local, &
               it,DT,NSTEP,t0,LOCAL_PATH,istore,SIMULATION_TYPE)

  implicit none

  include "constants.h"

  integer :: NSTEP,it
  integer :: nrec,nrec_local
  integer :: myrank,istore
  integer :: SIMULATION_TYPE

  integer, dimension(nrec_local) :: number_receiver_global
  real(kind=CUSTOM_REAL), dimension(NDIM,nrec_local,NSTEP) :: seismograms

  double precision t0,DT

  character(len=256) LOCAL_PATH
  character(len=MAX_LENGTH_STATION_NAME), dimension(nrec) :: station_name
  character(len=MAX_LENGTH_NETWORK_NAME), dimension(nrec) :: network_name

  ! local parameters
  integer irec,irec_local
  integer irecord

  character(len=1) component

  ! parameters for master collects seismograms
  real(kind=CUSTOM_REAL), dimension(:,:), allocatable :: one_seismogram
  integer :: nrec_local_received,NPROCTOT,total_seismos,receiver,sender
  integer :: iproc,ier
  integer,dimension(1) :: tmp_nrec_local_received,tmp_irec,tmp_nrec_local

  ! saves displacement, velocity or acceleration
  if(istore == 1) then
    component = 'd'
  else if(istore == 2) then
    component = 'v'
  else if(istore == 3) then
    component = 'a'
  else
    call exit_MPI(myrank,'wrong component to save for seismograms')
  endif

  allocate(one_seismogram(NDIM,NSTEP),stat=ier)
  if(ier /= 0) stop 'error while allocating one temporary seismogram'

  ! all processes write their local seismograms themselves
  if( .not. WRITE_SEISMOGRAMS_BY_MASTER ) then

    ! loop on all the local receivers
    do irec_local = 1,nrec_local

      ! get global number of that receiver
      irec = number_receiver_global(irec_local)

      ! save three components of displacement vector
      irecord = 1

      ! writes out this seismogram
      one_seismogram = seismograms(:,irec_local,:)

      call write_one_seismogram(one_seismogram,irec, &
              station_name,network_name,nrec, &
              DT,t0,it,NSTEP,SIMULATION_TYPE, &
              myrank,irecord,component,LOCAL_PATH)

    enddo ! nrec_local

! now only the master process does the writing of seismograms and
! collects the data from all other processes
  else ! WRITE_SEISMOGRAMS_BY_MASTER

    if(myrank == 0) then ! on the master, gather all the seismograms

      total_seismos = 0

      ! loop on all the slices
      call world_size(NPROCTOT)
      do iproc = 0,NPROCTOT-1

        ! receive except from proc 0, which is me and therefore I already have this value
        sender = iproc
        if(iproc /= 0) then
          call recv_i(tmp_nrec_local_received,1,sender,itag)
          nrec_local_received = tmp_nrec_local_received(1)
          if(nrec_local_received < 0) call exit_MPI(myrank,'error while receiving local number of receivers')
        else
          nrec_local_received = nrec_local
        endif

        if (nrec_local_received > 0) then
          do irec_local = 1,nrec_local_received
            ! receive except from proc 0, which is myself and therefore I already have these values
            if(iproc == 0) then
              ! get global number of that receiver
              irec = number_receiver_global(irec_local)
              one_seismogram(:,:) = seismograms(:,irec_local,:)
            else
              call recv_i(tmp_irec,1,sender,itag)
              irec = tmp_irec(1)
              if(irec < 1 .or. irec > nrec) call exit_MPI(myrank,'error while receiving global receiver number')

              call recvv_cr(one_seismogram,NDIM*NSTEP,sender,itag)
            endif

            total_seismos = total_seismos + 1

            ! save three components of displacement vector
            irecord = 1

            ! writes out this seismogram
            call write_one_seismogram(one_seismogram,irec, &
                              station_name,network_name,nrec, &
                              DT,t0,it,NSTEP,SIMULATION_TYPE, &
                              myrank,irecord,component,LOCAL_PATH)

          enddo ! nrec_local_received
        endif ! if(nrec_local_received > 0 )
      enddo ! NPROCTOT-1

      write(IMAIN,*) 'Component: .sem'//component
      write(IMAIN,*) '  total number of receivers saved is ',total_seismos,' out of ',nrec
      write(IMAIN,*)

      if(total_seismos /= nrec) call exit_MPI(myrank,'incorrect total number of receivers saved')

    else  ! on the nodes, send the seismograms to the master
       receiver = 0
       tmp_nrec_local(1) = nrec_local
       call send_i(tmp_nrec_local,1,receiver,itag)
       if (nrec_local > 0) then
         do irec_local = 1,nrec_local
           ! get global number of that receiver
           irec = number_receiver_global(irec_local)
           tmp_irec(1) = irec
           call send_i(tmp_irec,1,receiver,itag)

           ! sends seismogram of that receiver
           one_seismogram(:,:) = seismograms(:,irec_local,:)
           call sendv_cr(one_seismogram,NDIM*NSTEP,receiver,itag)
         enddo
       endif
    endif ! myrank

  endif ! WRITE_SEISMOGRAMS_BY_MASTER

  deallocate(one_seismogram)

  end subroutine write_seismograms_to_file

!=====================================================================

  subroutine write_one_seismogram(one_seismogram,irec, &
              station_name,network_name,nrec, &
              DT,t0,it,NSTEP,SIMULATION_TYPE, &
              myrank,irecord,component,LOCAL_PATH)

  implicit none

  include "constants.h"

  integer :: NSTEP,it,SIMULATION_TYPE
  real(kind=CUSTOM_REAL), dimension(NDIM,NSTEP) :: one_seismogram

  integer myrank,irecord
  double precision t0,DT

  integer :: nrec,irec
  character(len=MAX_LENGTH_STATION_NAME), dimension(nrec) :: station_name
  character(len=MAX_LENGTH_NETWORK_NAME), dimension(nrec) :: network_name
  character(len=1) component
  character(len=256) LOCAL_PATH

  ! local parameters
  integer iorientation
  integer length_station_name,length_network_name
  character(len=256) sisname,clean_LOCAL_PATH,final_LOCAL_PATH
  character(len=3) channel

  ! loops over each seismogram component
  do iorientation = 1,NDIM

    ! gets channel name
    call write_channel_name(iorientation,channel)

    ! create the name of the seismogram file for each slice
    ! file name includes the name of the station, the network and the component
    length_station_name = len_trim(station_name(irec))
    length_network_name = len_trim(network_name(irec))

    ! check that length conforms to standard
    if(length_station_name < 1 .or. length_station_name > MAX_LENGTH_STATION_NAME) &
       call exit_MPI(myrank,'wrong length of station name')

    if(length_network_name < 1 .or. length_network_name > MAX_LENGTH_NETWORK_NAME) &
       call exit_MPI(myrank,'wrong length of network name')

    write(sisname,"(a,'.',a,'.',a3,'.sem',a1)") station_name(irec)(1:length_station_name),&
       network_name(irec)(1:length_network_name),channel,component

    ! directory to store seismograms
    if( USE_OUTPUT_FILES_PATH ) then
      final_LOCAL_PATH = OUTPUT_FILES_PATH(1:len_trim(OUTPUT_FILES_PATH)) // '/'
    else
      ! suppress white spaces if any
      clean_LOCAL_PATH = adjustl(LOCAL_PATH)
      ! create full final local path
      final_LOCAL_PATH = clean_LOCAL_PATH(1:len_trim(clean_LOCAL_PATH)) // '/'
    endif

    ! ASCII output format
    call write_output_ASCII(one_seismogram, &
              NSTEP,it,SIMULATION_TYPE,DT,t0,myrank, &
              iorientation,irecord,sisname,final_LOCAL_PATH)

  enddo ! do iorientation

  end subroutine write_one_seismogram

!=====================================================================

! write adjoint seismograms (displacement) to text files

  subroutine write_adj_seismograms_to_file(myrank,seismograms,number_receiver_global, &
               nrec_local,it,DT,NSTEP,t0,LOCAL_PATH,istore)

  implicit none

  include "constants.h"

  integer nrec_local,NSTEP,it,myrank,istore
  integer, dimension(nrec_local) :: number_receiver_global
  real(kind=CUSTOM_REAL), dimension(NDIM,nrec_local,NSTEP) :: seismograms
  double precision t0,DT
  character(len=256) LOCAL_PATH


  integer irec,irec_local
  integer iorientation,irecord,isample

  character(len=3) channel
  character(len=1) component
  character(len=256) sisname,clean_LOCAL_PATH,final_LOCAL_PATH

! save displacement, velocity or acceleration
  if(istore == 1) then
    component = 'd'
  else if(istore == 2) then
    component = 'v'
  else if(istore == 3) then
    component = 'a'
  else
    call exit_MPI(myrank,'wrong component to save for seismograms')
  endif

  do irec_local = 1,nrec_local

    ! get global number of that receiver
    irec = number_receiver_global(irec_local)

    ! save three components of displacement vector
    irecord = 1

    do iorientation = 1,NDIM

      ! gets channel name
      call write_channel_name(iorientation,channel)

      ! create the name of the seismogram file for each slice
      ! file name includes the name of the station, the network and the component
      write(sisname,"(a,i5.5,'.',a,'.',a3,'.sem',a1)") 'S',irec_local,&
           'NT',channel,component

      ! directory to store seismograms
      if( USE_OUTPUT_FILES_PATH ) then
        final_LOCAL_PATH = OUTPUT_FILES_PATH(1:len_trim(OUTPUT_FILES_PATH)) // '/'
      else
        ! suppress white spaces if any
        clean_LOCAL_PATH = adjustl(LOCAL_PATH)
        ! create full final local path
        final_LOCAL_PATH = clean_LOCAL_PATH(1:len_trim(clean_LOCAL_PATH)) // '/'
      endif


      ! save seismograms in text format with no subsampling.
      ! Because we do not subsample the output, this can result in large files
      ! if the simulation uses many time steps. However, subsampling the output
      ! here would result in a loss of accuracy when one later convolves
      ! the results with the source time function
      open(unit=IOUT,file=final_LOCAL_PATH(1:len_trim(final_LOCAL_PATH))//sisname(1:len_trim(sisname)),status='unknown')

      ! make sure we never write more than the maximum number of time steps
      ! subtract half duration of the source to make sure travel time is correct
      do isample = 1,min(it,NSTEP)
        if(irecord == 1) then
          ! distinguish between single and double precision for reals
          if(CUSTOM_REAL == SIZE_REAL) then
            write(IOUT,*) sngl(dble(isample-1)*DT - t0),' ',seismograms(iorientation,irec_local,isample)
          else
            write(IOUT,*) dble(isample-1)*DT - t0,' ',seismograms(iorientation,irec_local,isample)
          endif
        else
          call exit_MPI(myrank,'incorrect record label')
        endif
      enddo

      close(IOUT)

    enddo

  enddo

  end subroutine write_adj_seismograms_to_file

!=====================================================================

! write adjoint seismograms (strain) to text files

  subroutine write_adj_seismograms2_to_file(myrank,seismograms,number_receiver_global, &
               nrec_local,it,DT,NSTEP,t0,LOCAL_PATH)

  implicit none

  include "constants.h"

  integer nrec_local,NSTEP,it,myrank
  integer, dimension(nrec_local) :: number_receiver_global
  real(kind=CUSTOM_REAL), dimension(NDIM,NDIM,nrec_local,NSTEP) :: seismograms
  double precision t0,DT
  character(len=256) LOCAL_PATH


  integer irec,irec_local
  integer idim,jdim,irecord,isample

  character(len=4) chn
  character(len=1) component
  character(len=256) sisname,clean_LOCAL_PATH,final_LOCAL_PATH

  do irec_local = 1,nrec_local

    ! get global number of that receiver
    irec = number_receiver_global(irec_local)

    ! save three components of displacement vector
    irecord = 1

    do idim = 1, 3
      do jdim = idim, 3

        if(idim == 1 .and. jdim == 1) then
          chn = 'SNN'
        else if(idim == 1 .and. jdim == 2) then
          chn = 'SEN'
        else if(idim == 1 .and. jdim == 3) then
          chn = 'SEZ'
        else if(idim == 2 .and. jdim == 2) then
          chn = 'SEE'
        else if(idim == 2 .and. jdim == 3) then
          chn = 'SNZ'
        else if(idim == 3 .and. jdim == 3) then
          chn = 'SZZ'
        else
          call exit_MPI(myrank,'incorrect channel value')
        endif

        ! create the name of the seismogram file for each slice
        ! file name includes the name of the station, the network and the component
        write(sisname,"(a,i5.5,'.',a,'.',a3,'.sem',a1)") 'S',irec_local,&
           'NT',chn,component

        ! directory to store seismograms
        if( USE_OUTPUT_FILES_PATH ) then
          final_LOCAL_PATH = OUTPUT_FILES_PATH(1:len_trim(OUTPUT_FILES_PATH)) // '/'
        else
          ! suppress white spaces if any
          clean_LOCAL_PATH = adjustl(LOCAL_PATH)
          ! create full final local path
          final_LOCAL_PATH = clean_LOCAL_PATH(1:len_trim(clean_LOCAL_PATH)) // '/'
        endif

        ! save seismograms in text format with no subsampling.
        ! Because we do not subsample the output, this can result in large files
        ! if the simulation uses many time steps. However, subsampling the output
        ! here would result in a loss of accuracy when one later convolves
        ! the results with the source time function
        open(unit=IOUT,file=final_LOCAL_PATH(1:len_trim(final_LOCAL_PATH))//sisname(1:len_trim(sisname)),status='unknown')

        ! make sure we never write more than the maximum number of time steps
        ! subtract half duration of the source to make sure travel time is correct
        do isample = 1,min(it,NSTEP)
          if(irecord == 1) then
            ! distinguish between single and double precision for reals
            if(CUSTOM_REAL == SIZE_REAL) then
              write(IOUT,*) sngl(dble(isample-1)*DT - t0),' ',seismograms(jdim,idim,irec_local,isample)
            else
              write(IOUT,*) dble(isample-1)*DT - t0,' ',seismograms(jdim,idim,irec_local,isample)
            endif
          else
            call exit_MPI(myrank,'incorrect record label')
          endif
        enddo

        close(IOUT)

      enddo ! jdim
    enddo ! idim
  enddo ! irec_local

end subroutine write_adj_seismograms2_to_file

!=====================================================================

subroutine write_channel_name(iorientation,channel)

  use specfem_par,only: DT,SUPPRESS_UTM_PROJECTION
  implicit none

  integer :: iorientation
  character(len=3) :: channel

  ! local parameters
  character(len=2) :: bic
  double precision:: sampling_rate

  ! gets band and instrument code
  sampling_rate = DT
  call band_instrument_code(sampling_rate,bic)

  ! sets channel name
  if( SUPPRESS_UTM_PROJECTION ) then

    ! no UTM, pure Cartesian reference
    ! uses Cartesian X/Y/Z direction to denote channel
    select case(iorientation)
    case(1)
      channel = bic(1:2)//'X'
    case(2)
      channel = bic(1:2)//'Y'
    case(3)
      channel = bic(1:2)//'Z'
    case default
      call exit_mpi(0,'error channel orientation value')
    end select

  else

    ! UTM conversion
    ! uses convention for N/E/Z to denote channel
    select case(iorientation)
    case(1)
      channel = bic(1:2)//'E'
    case(2)
      channel = bic(1:2)//'N'
    case(3)
      channel = bic(1:2)//'Z'
    case default
      call exit_mpi(0,'error channel orientation value')
    end select

  endif

end subroutine write_channel_name

!=====================================================================

subroutine band_instrument_code(DT,bic)
  ! This subroutine is to choose the appropriate band and instrument codes for channel names of seismograms
  ! based on the IRIS convention (first two letters of channel codes, respectively,
  ! which were LH(Z/E/N) previously).
  ! For consistency with observed data, we now use the IRIS convention for band codes (first letter in channel codes) of
  ! SEM seismograms governed by their sampling rate.
  ! Instrument code (second letter in channel codes) is fixed to "X" which is assigned by IRIS for synthetic seismograms.
  ! See the manual for further explanations!
  ! Ebru, November 2010
  implicit none
  double precision :: DT
  character(len=2) :: bic
  ! local parameter
  logical,parameter :: SUPPRESS_IRIS_CONVENTION = .false.

  ! see manual for ranges
  if (DT .ge. 1.0d0)  bic = 'LX'
  if (DT .lt. 1.0d0 .and. DT .gt. 0.1d0) bic = 'MX'
  if (DT .le. 0.1d0 .and. DT .gt. 0.0125d0) bic = 'BX'
  if (DT .le. 0.0125d0 .and. DT .gt. 0.004d0) bic = 'HX'
  if (DT .le. 0.004d0 .and. DT .gt. 0.001d0) bic = 'CX'
  if (DT .le. 0.001d0) bic = 'FX'

  ! ignores IRIS convention, uses previous, constant band and instrument code
  if( SUPPRESS_IRIS_CONVENTION ) then
    bic = 'BH'
  endif

 end subroutine band_instrument_code

!=====================================================================

 subroutine write_seismograms_su()

 use specfem_par
 use specfem_par_acoustic
 use specfem_par_elastic
 use specfem_par_poroelastic

 implicit none

 character(len=256) procname,final_LOCAL_PATH
 integer :: irec_local,irec

 ! headers
 integer,parameter :: nheader=240      ! 240 bytes
 integer(kind=2) :: i2head(nheader/2)  ! 2-byte-integer
 integer(kind=4) :: i4head(nheader/4)  ! 4-byte-integer
 real(kind=4)    :: r4head(nheader/4)  ! 4-byte-real
 equivalence (i2head,i4head,r4head)    ! share the same 240-byte-memory

 double precision, allocatable, dimension(:) :: x_found,y_found,z_found
 double precision :: x_found_source,y_found_source,z_found_source

 allocate(x_found(nrec))
 allocate(y_found(nrec))
 allocate(z_found(nrec))
 open(unit=IIN_SU1,file=trim(OUTPUT_FILES)//'/output_list_stations.txt',status='unknown')
 do irec=1,nrec
   read(IIN_SU1,*) x_found(irec),y_found(irec),z_found(irec)
 enddo
 close(IIN_SU1)
 open(unit=IIN_SU1,file=trim(OUTPUT_FILES)//'/output_list_sources.txt',status='unknown')
 read(IIN_SU1,*) x_found_source,y_found_source,z_found_source
 close(IIN_SU1)
 ! directory to store seismograms
 if( USE_OUTPUT_FILES_PATH ) then
   final_LOCAL_PATH = OUTPUT_FILES_PATH(1:len_trim(OUTPUT_FILES_PATH)) // '/'
 else
   ! create full final local path
   final_LOCAL_PATH = trim(adjustl(LOCAL_PATH)) // '/'
 endif
 write(procname,"(i4)") myrank

 ! write seismograms (dx)
 open(unit=IOUT_SU, file=trim(adjustl(final_LOCAL_PATH))//trim(adjustl(procname))//'_dx_SU' ,&
      form='unformatted', access='direct', recl=240+4*(NSTEP))
 do irec_local = 1,nrec_local
   irec = number_receiver_global(irec_local)
   i4head(1)  =irec
   i4head(11) =z_found(irec)
   i4head(13) =z_found_source
   i4head(19) =x_found_source !utm_x_source(1)
   i4head(20) =y_found_source !utm_y_source(1)
   i4head(21) =x_found(irec)  !stutm_x(irec)
   i4head(22) =y_found(irec)  !stutm_y(irec)
   i2head(58) =NSTEP
   i2head(59) =DT*1.0d6
   write(IOUT_SU,rec=irec_local) r4head, seismograms_d(1,irec_local,:)
 enddo
 close(IOUT_SU)
 ! write seismograms (dy)
 open(unit=IOUT_SU, file=trim(adjustl(final_LOCAL_PATH))//trim(adjustl(procname))//'_dy_SU' ,&
      form='unformatted', access='direct', recl=240+4*(NSTEP))
 do irec_local = 1,nrec_local
   irec = number_receiver_global(irec_local)
   i4head(1)  =irec
   i4head(11) =z_found(irec)
   i4head(13) =z_found_source
   i4head(19) =x_found_source !utm_x_source(1)
   i4head(20) =y_found_source !utm_y_source(1)
   i4head(21) =x_found(irec)  !stutm_x(irec)
   i4head(22) =y_found(irec)  !stutm_y(irec)
   i2head(58) =NSTEP
   i2head(59) =DT*1.0d6
   write(IOUT_SU,rec=irec_local) r4head, seismograms_d(2,irec_local,:)
 enddo
 close(IOUT_SU)

 ! write seismograms (dz)
 open(unit=IOUT_SU, file=trim(adjustl(final_LOCAL_PATH))//trim(adjustl(procname))//'_dz_SU' ,&
      form='unformatted', access='direct', recl=240+4*(NSTEP))
 do irec_local = 1,nrec_local
   irec = number_receiver_global(irec_local)
   i4head(1)  =irec
   i4head(11) =z_found(irec)
   i4head(13) =z_found_source
   i4head(19) =x_found_source !utm_x_source(1)
   i4head(20) =y_found_source !utm_y_source(1)
   i4head(21) =x_found(irec)  !stutm_x(irec)
   i4head(22) =y_found(irec)  !stutm_y(irec)
   i2head(58) =NSTEP
   i2head(59) =DT*1.0d6
   write(IOUT_SU,rec=irec_local) r4head, seismograms_d(3,irec_local,:)
 enddo
 close(IOUT_SU)

 end subroutine write_seismograms_su

