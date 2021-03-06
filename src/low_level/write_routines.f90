  !!****m* etsf_io_low_file_group/etsf_io_low_open_create
  !! NAME
  !!  etsf_io_low_open_create
  !!
  !! FUNCTION
  !!  This method is used to open a NetCDF file. The file should not already exist.
  !!  The ETSF header for the created file is automatically added by this method.
  !!  When finished, the file handled by @ncid, is in define mode, which means
  !!  that dimensions (see etsf_io_low_write_dim()), variables (see
  !!  etsf_io_low_def_var()) and attributes (see etsf_io_low_write_att()) can be defined.
  !!  To use etsf_io_low_write_var(), the file should be switched to data mode using
  !!  etsf_io_low_set_write_mode().
  !!
  !!  If title or history are given and are too long, they will be truncated.
  !!
  !!  If one wants to modify an already existing file, one should use
  !!  etsf_io_low_open_modify() instead.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006, 2007 (Damien Caliste)
  !!  This file is distributed under the terms of the
  !!  GNU Lesser General Public License, see the COPYING file
  !!  or http://www.gnu.org/copyleft/lesser.txt .
  !!
  !! INPUTS
  !!  * filename = the path to the file to open.
  !!  * version = the number of version to be created.
  !!  * title = (optional) a title for the file (80 characters max).
  !!  * history = (optional) the first line of history (1024 characters max).
  !!  * with_etsf_header = (optional) if true, will create a header
  !!                       as defined in the ETSF specifications (default is .true.).
  !!                       When value is .false., arguments title, history and version
  !!                       are ignored.
  !!  * overwrite = (optional) if true, an existing file with the same name as @filename
  !!                would be overwritten. Default is .false., which means that an IO
  !!                error is raised if a file already exists.
  !!
  !! OUTPUT
  !!  * ncid = the NetCDF handler, opened with write access (define mode).
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! SOURCE
  subroutine etsf_io_low_open_create(ncid, filename, version, lstat, &
                                   & title, history, error_data, with_etsf_header, &
                                   & overwrite, mpi_comm, mpi_info)
    integer, intent(out)                           :: ncid
    character(len = *), intent(in)                 :: filename
    real, intent(in)                               :: version
    logical, intent(out)                           :: lstat
    character(len = *), intent(in), optional       :: title
    character(len = *), intent(in), optional       :: history
    type(etsf_io_low_error), intent(out), optional :: error_data
    logical, intent(in), optional                  :: with_etsf_header
    logical, intent(in), optional                  :: overwrite
    integer, intent(in), optional                  :: mpi_comm, mpi_info
    
    !Local
    character(len = *), parameter :: me = "etsf_io_low_open_create"
    character(len = 256) :: err
    integer :: s, cmode
    logical :: stat
    
    lstat = .false.
    ! Checking that @version argument is valid.
    if (version < 1.0) then
      if (present(error_data)) then
        write(err, "(A,I0,A)") "Wrong version argument (given: ", version, " ; awaited >= 1.0)"
        call etsf_io_low_error_set(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, me, &
                     & tgtname = "file_format_version", errmess = err)
      end if
      return
    end if
    ! Checking that optional arguments are coherent.
    if ((present(mpi_comm) .and. .not. present(mpi_info)) .or. &
         & (.not. present(mpi_comm) .and. present(mpi_info))) then
      if (present(error_data)) then
        write(err, "(A)") "Both MPI_comm and MPI_info argument must be provided together."
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_OWR, me, &
                     & tgtname = "MPI_comm or MPI_info", errmess = err)
      end if
      return
    end if
    ! Open file for writing
    cmode = NF90_NOCLOBBER
    if (present(overwrite)) then
      if (overwrite) then
        cmode = NF90_CLOBBER
      end if
    end if
    ! We don't use the 64bits flag since the specifications advice
    ! to split huge quantities of data into several smaller files.
    if (present(mpi_comm)) then
       call wrap_nf90_create(s, filename, cmode, ncid, .true., mpi_comm, mpi_info)
    else
       call wrap_nf90_create(s, filename, cmode, ncid, .false., 0, 0)
    end if
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_OWR, &
             & me, tgtname = filename, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! From now on the file is open. If an error occur,
    ! we should close it.
    
    ! We create the header if required.
    if (present(with_etsf_header)) then
      if (.not. with_etsf_header) then
        lstat = .true.
        return
      end if
    end if
    ! The file format
    s = nf90_put_att(ncid, NF90_GLOBAL, "file_format", etsf_io_low_file_format)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, &
             & me, tgtname = "file_format", errid = s, errmess = nf90_strerror(s))
      end if
      call etsf_io_low_close(ncid, stat)
      return
    end if
    ! The version
    s = nf90_put_att(ncid, NF90_GLOBAL, "file_format_version", version)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, me, &
             & tgtname = "file_format_version", errid = s, errmess = nf90_strerror(s))
      end if
      call etsf_io_low_close(ncid, stat)
      return
    end if
    ! The conventions
    s = nf90_put_att(ncid, NF90_GLOBAL, "Conventions", etsf_io_low_conventions)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, me, &
             & tgtname = "Conventions", errid = s, errmess = nf90_strerror(s))
      end if
      call etsf_io_low_close(ncid, stat)
      return
    end if
    ! The title if present
    if (present(title)) then
      s = nf90_put_att(ncid, NF90_GLOBAL, "title", title(1:min(80, len(title))))
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, &
               & me, tgtname = "title", errid = s, errmess = nf90_strerror(s))
        end if
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if
    ! The history if present
    if (present(history)) then
      s = nf90_put_att(ncid, NF90_GLOBAL, "history", history(1:min(1024, len(history))))
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, &
               & me, tgtname = "history", errid = s, errmess = nf90_strerror(s))
        end if
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if
    
    lstat = .true.
  end subroutine etsf_io_low_open_create
  !!***
    
  !!****m* etsf_io_low_file_group/etsf_io_low_open_modify
  !! NAME
  !!  etsf_io_low_open_modify
  !!
  !! FUNCTION
  !!  This method is used to open a NetCDF file for modifications. The file should
  !!  already exist and have a valid ETSF header (if @with_etsf_header is not set to
  !!  .false.).
  !!
  !!  When finished, the file handled by @ncid, is in define mode, which means
  !!  that dimensions (see etsf_io_low_write_dim()), variables (see
  !!  etsf_io_low_def_var()) and attributes (see etsf_io_low_write_att()) can be defined.
  !!  To use etsf_io_low_write_var(), the file should be switched to data mode using
  !!  etsf_io_low_set_write_mode().
  !!
  !!  If title or history are given and are too long, they will be truncated. Moreover
  !!  the given history is appended to the already existing history (if enough
  !!  place exists).
  !!
  !!  If one wants to create a new file, one should use etsf_io_low_open_create() instead.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006, 2007 (Damien Caliste)
  !!  This file is distributed under the terms of the
  !!  GNU Lesser General Public License, see the COPYING file
  !!  or http://www.gnu.org/copyleft/lesser.txt .
  !!
  !! INPUTS
  !!  * filename = the path to the file to open.
  !!  * title = (optional) a title for the file (80 characters max).
  !!  * history = (optional) the first line of history (1024 characters max).
  !!  * version = (optional) the number of version to be changed (>= 1.0).
  !!
  !! OUTPUT
  !!  * ncid = the NetCDF handler, opened with write access (define mode).
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!  * with_etsf_header = (optional) if true, will check that there is a header
  !!                       as defined in the ETSF specifications (default is .true.).
  !!
  !! SOURCE
  subroutine etsf_io_low_open_modify(ncid, filename, lstat, &
                                   & title, history, version, error_data, with_etsf_header, &
                                   & mpi_comm, mpi_info)
    integer, intent(out)                           :: ncid
    character(len = *), intent(in)                 :: filename
    logical, intent(out)                           :: lstat
    character(len = *), intent(in), optional       :: title
    character(len = *), intent(in), optional       :: history
    real, intent(in), optional                     :: version
    type(etsf_io_low_error), intent(out), optional :: error_data
    logical, intent(in), optional                  :: with_etsf_header
    integer, intent(in), optional                  :: mpi_comm, mpi_info
    
    !Local
    character(len = *), parameter :: me = "etsf_io_low_open_modify"
    character(len = 256) :: err
    character(len = 1024) :: current_history
    integer :: s
    logical :: stat
    logical :: my_with_etsf_header
    
    lstat = .false.
    ! Checking that @version argument is valid.
    if (present(version)) then
      if (version < 1.0) then
        if (present(error_data)) then
          write(err, "(A,I0,A)") "Wrong version argument (given: ", version, " ; awaited >= 1.0)"
          call etsf_io_low_error_set(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, &
               & me, tgtname = "file_format_version", errmess = err)
        end if
        return
      end if
    end if
    ! Checking that optional arguments are coherent.
    if ((present(mpi_comm) .and. .not. present(mpi_info)) .or. &
         & (.not. present(mpi_comm) .and. present(mpi_info))) then
      if (present(error_data)) then
        write(err, "(A)") "Both MPI_comm and MPI_info argument must be provided together."
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_OWR, me, &
                     & tgtname = "MPI_comm or MPI_info", errmess = err)
      end if
      return
    end if
    ! Open file for writing
    if (present(mpi_comm)) then
       call wrap_nf90_open(s, filename, NF90_WRITE, ncid, .true., mpi_comm, mpi_info)
    else
       call wrap_nf90_open(s, filename, NF90_WRITE, ncid, .false., 0, 0)
    end if
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_OWR, &
             & me, tgtname = filename, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! From now on the file is open. If an error occur,
    ! we should close it.
    
    ! Before according access to modifications, we check
    ! that the header is valid.
    if (present(with_etsf_header)) then
      my_with_etsf_header = with_etsf_header
    else
      my_with_etsf_header = .true.
    end if
    if (my_with_etsf_header) then
      if (present(error_data)) then
        call etsf_io_low_check_header(ncid, stat, error_data = error_data)
        if (.not. stat) call etsf_io_low_error_update(error_data, me)
      else
        call etsf_io_low_check_header(ncid, stat)
      end if
      if (.not. stat) then
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if

    ! We switch to define mode to set attributes.
    if (present(error_data)) then
      call etsf_io_low_set_define_mode(ncid, stat, error_data = error_data)
      if (.not. stat) call etsf_io_low_error_update(error_data, me)
    else
      call etsf_io_low_set_define_mode(ncid, stat)
    end if
    if (.not. stat) then
      call etsf_io_low_close(ncid, stat)
      return
    end if
    if (.not. my_with_etsf_header) then
      lstat = .true.
      return
    end if

    ! If a title is given, we change it.
    if (present(title)) then
      s = nf90_put_att(ncid, NF90_GLOBAL, "title", title(1:min(80, len(title))))
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, &
                                   & ERROR_TYPE_ATT, me, tgtname = "title", &
                                   & errid = s, errmess = nf90_strerror(s))
        end if
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if
    ! If a new version is given, we change it.
    if (present(version)) then
      s = nf90_put_att(ncid, NF90_GLOBAL, "file_format_version", version)
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, me, &
                       & tgtname = "file_format_version", &
                       & errid = s, errmess = nf90_strerror(s))
        end if
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if
    ! If an history value is given, we append it.
    if (present(history)) then
      call etsf_io_low_read_att(ncid, NF90_GLOBAL, "history", 1024, &
           & current_history, stat)
      if (stat) then
        ! appending mode
        if (len(trim(current_history)) + len(history) < 1024) then
          current_history = trim(current_history) // char(10) // history
        end if
      else
        ! overwriting mode
        current_history = history
      end if
      s = nf90_put_att(ncid, NF90_GLOBAL, "history", current_history)
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_PUT, ERROR_TYPE_ATT, me, &
                       & tgtname = "history", &
                       & errid = s, errmess = nf90_strerror(s))
        end if
        call etsf_io_low_close(ncid, stat)
        return
      end if
    end if
    
    lstat = .true.
  end subroutine etsf_io_low_open_modify
  !!***
  
  !!****m* etsf_io_low_write_group/etsf_io_low_write_dim
  !! NAME
  !!  etsf_io_low_write_dim
  !!
  !! FUNCTION
  !!  This method is a wraper add a dimension to a NetCDF file. As in pure NetCDF
  !!  calls, overwriting a value is not permitted. Nevertheless, the method returns
  !!  .true. in @lstat, if the dimension already exists and has the same value.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006, 2007 (Damien Caliste)
  !!  This file is distributed under the terms of the
  !!  GNU Lesser General Public License, see the COPYING file
  !!  or http://www.gnu.org/copyleft/lesser.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access (define mode).
  !!  * dimname = a string identifying a dimension.
  !!  * dimvalue = a positive integer which is the length of the dimension.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * ncdimid = (optional) the id used by NetCDF to identify the written dimension.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! SOURCE
  subroutine etsf_io_low_write_dim(ncid, dimname, dimvalue, lstat, ncdimid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: dimname
    integer, intent(in)                            :: dimvalue
    logical, intent(out)                           :: lstat
    integer, intent(out), optional                 :: ncdimid
    type(etsf_io_low_error), intent(out), optional :: error_data
    
    ! Local
    character(len = *), parameter :: me = "etsf_io_low_write_dim"
    character(len = 500) :: message
    integer :: s, dimid, readvalue
    
    ! Check if dimension already exists.
    call etsf_io_low_read_dim(ncid, dimname, readvalue, lstat)
    if (lstat) then
      ! Dimension already exists.
      if (readvalue /= dimvalue) then
        ! Dimension differs, raise error.
        if (present(error_data)) then
          write(message, "(2A,I0,A,I0,A)") "dimension already exists with a different", &
                                         & " value (read = ", readvalue, " ; write = ", &
                                         & dimvalue, ")."
          call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_DIM, me, &
                                   & tgtname = dimname, errmess = message)
        end if
        lstat = .false.
        return
      else
        ! Dimension matches, return.
        return
      end if        
    end if
    ! Define dimension since it don't already exist.
    lstat = .false.
    s = nf90_def_dim(ncid, dimname, dimvalue, dimid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_DIM, me, &
                                 & tgtname = dimname, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    if (present(ncdimid)) then
      ncdimid = dimid
    end if    
    lstat = .true.
  end subroutine etsf_io_low_write_dim
  !!***
  
  ! Interfaced routine:
  ! See etsf_io_low_level.f90 for documentation
  subroutine etsf_io_low_def_var_0D(ncid, varname, vartype, lstat, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    integer, intent(in)                            :: vartype
    logical, intent(out)                           :: lstat
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data
    
    ! Local
    character(len = *), parameter :: me = "etsf_io_low_def_var_0D"
    type(etsf_io_low_var_infos) :: var_infos
    integer :: s, varid

    ! We put a default value.
    if (present(ncvarid)) then
      ncvarid = -1
    end if
    lstat = .false.

    ! Check if dimension already exists.
    call etsf_io_low_read_var_infos(ncid, varname, var_infos, lstat)
    if (lstat) then
      ! Variable already exists.
      lstat = (var_infos%nctype == vartype .and. var_infos%ncshape == 0)
      if (.not. lstat) then
        ! Variable differs, raise error.
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_VAR, me, &
                                   & tgtname = varname, errmess = &
                                   & "variable already exists with a different definition.")
        end if
        lstat = .false.
        return
      else
        ! Dimension matches, return.
        return
      end if        
    end if
    ! Define variable since it don't already exist.
    lstat = .false.    
    ! Special case where dimension is null
    s = nf90_def_var(ncid, varname, vartype, varid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_VAR, me, &
                      & tgtname = varname, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    if (present(ncvarid)) then
      ncvarid = varid
    end if    
    lstat = .true.
  end subroutine etsf_io_low_def_var_0D
  
  ! Interfaced routine:
  ! See etsf_io_low_level.f90 for documentation
  subroutine etsf_io_low_def_var_nD(ncid, varname, vartype, vardims, lstat, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    integer, intent(in)                            :: vartype
    character(len = *), intent(in)                 :: vardims(:)
    logical, intent(out)                           :: lstat
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data
    
    ! Local
    character(len = *), parameter :: me = "etsf_io_low_def_var_nD"
    type(etsf_io_low_var_infos) :: var_infos
    integer :: s, varid, ndims, i
    integer, allocatable :: ncdims(:, :)
    logical :: stat

    ! We put a default value.
    if (present(ncvarid)) then
      ncvarid = -1
    end if
    lstat = .false.

    ! The dimension are given by their names, we must first fetch them.
    ndims = size(vardims)
    allocate(ncdims(0:1, 1:ndims))
    do i = 1, ndims, 1
      if (present(error_data)) then
        call etsf_io_low_read_dim(ncid, trim(vardims(i)), ncdims(0, i), &
                                & stat, ncdimid = ncdims(1, i), error_data = error_data)
        if (.not. stat) call etsf_io_low_error_update(error_data, me)
      else
        call etsf_io_low_read_dim(ncid, trim(vardims(i)), ncdims(0, i), &
                                & stat, ncdimid = ncdims(1, i))
      end if
      if (.not. stat) then
        deallocate(ncdims)
        return
      end if
    end do
    ! Check if dimension already exists.
    call etsf_io_low_read_var_infos(ncid, varname, var_infos, lstat)
    if (lstat) then
      ! Variable already exists.
      lstat = (var_infos%nctype == vartype .and. var_infos%ncshape == ndims)
      do i = 1, min(var_infos%ncshape, ndims), 1
        lstat = lstat .and. (ncdims(0, i) == var_infos%ncdims(i))
      end do
      if (.not. lstat) then
        ! Variable differs, raise error.
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_VAR, me, &
               & tgtname = varname, errmess = &
               & "variable already exists with a different definition.")
        end if
      end if        
      deallocate(ncdims)
      return
    end if
    ! Define variable since it don't already exist.
    s = nf90_def_var(ncid, varname, vartype, ncdims(1, :), varid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_DEF, ERROR_TYPE_VAR, me, &
                      & tgtname = varname, errid = s, errmess = nf90_strerror(s))
      end if
      deallocate(ncdims)
      return
    end if
    deallocate(ncdims)
    if (present(ncvarid)) then
      ncvarid = varid
    end if    
    lstat = .true.
  end subroutine etsf_io_low_def_var_nD

  !!****m* etsf_io_low_write_group/etsf_io_low_copy_all_att
  !! NAME
  !!  etsf_io_low_copy_all_att
  !!
  !! FUNCTION
  !!  Copy all attributes from the given variable of the given file to an other
  !!  variable (of a different file, but not necessary). The variable ids from and to
  !!  can be either valid variables or etsf_io_low_global_att.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006, 2007 (Damien Caliste)
  !!  This file is distributed under the terms of the
  !!  GNU Lesser General Public License, see the COPYING file
  !!  or http://www.gnu.org/copyleft/lesser.txt .
  !!
  !! INPUTS
  !!  * ncid_from = a NetCDF handler, opened with read access.
  !!  * ncid_to = a NetCDF handler, opened with write access.
  !!  * ncvarid_from = a NetCDF variable id with attributes to copy.
  !!  * ncvarid_to = a NetCDF variable id to copy the attributes to.
  !!
  !! OUTPUT
  !!  * lstat = .true. if the file has been read without error.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !!
  !! SOURCE
  subroutine etsf_io_low_copy_all_att(ncid_from, ncid_to, ncvarid_from, &
       & ncvarid_to, lstat, error_data)
    integer, intent(in)                            :: ncid_from, ncid_to
    integer, intent(in)                            :: ncvarid_from, ncvarid_to
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    character(len = *), parameter :: me = "etsf_io_low_copy_all_att"
    type(etsf_io_low_var_infos) :: var_infos
    integer :: i, s, n
    character(len = NF90_MAX_NAME) :: ncname    

    lstat = .true.
    if (ncvarid_from /= etsf_io_low_global_att) then
       if (present(error_data)) then
          call read_var_infos_id(ncid_from, ncvarid_from, var_infos, lstat, &
               & error_data = error_data, dim_name = .false., att_name = .true.)
          if (.not. lstat) call etsf_io_low_error_update(error_data, me)
       else
          call read_var_infos_id(ncid_from, ncvarid_from, var_infos, lstat, &
               & dim_name = .false., att_name = .true.)
       end if
       if (.not. lstat) return
    else
       s = nf90_inquire(ncid_from, nAttributes = n)
       if (s /= nf90_noerr) then
          if (present(error_data)) then
             call etsf_io_low_error_set(error_data, ERROR_MODE_INQ, ERROR_TYPE_ATT, &
                  & me, tgtname = "global attributes", errid = s, &
                  & errmess = nf90_strerror(s))
          end if
          lstat = .false.
          return
       end if
       if (n > 0) then
          allocate(var_infos%ncattnames(1:n))
          do i = 1, n, 1
             s = nf90_inq_attname(ncid_from, etsf_io_low_global_att, i, ncname)
             if (s /= nf90_noerr) then
                if (present(error_data)) then
                   call etsf_io_low_error_set(error_data, ERROR_MODE_INQ, &
                        & ERROR_TYPE_ATT, me, tgtid = i, errid = s, &
                        & errmess = nf90_strerror(s))
                end if
                call etsf_io_low_free_var_infos(var_infos)
                lstat = .false.
                return
             end if
             write(var_infos%ncattnames(i), "(A)") ncname(1:min(80, len(ncname)))
          end do
       end if
    end if

    if (associated(var_infos%ncattnames)) then
       do i = 1, size(var_infos%ncattnames, 1), 1
          s = nf90_copy_att(ncid_from, ncvarid_from, trim(var_infos%ncattnames(i)), &
               & ncid_to, ncvarid_to)
          if (s /= nf90_noerr) then
             if (present(error_data)) then
                call etsf_io_low_error_set(error_data, ERROR_MODE_COPY, ERROR_TYPE_ATT, &
                     & me, tgtname = trim(var_infos%ncattnames(i)), errid = s, &
                     & errmess = nf90_strerror(s))
             end if
             lstat = .false.
             exit
          end if
       end do
    end if
    call etsf_io_low_free_var_infos(var_infos)
  end subroutine etsf_io_low_copy_all_att
  !!***
  
  ! Generic routine, documented in the module file.
  subroutine write_var_double_var(ncid, varname, var, lstat, &
                                & start, count, map, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    type(etsf_io_low_var_double), intent(in)       :: var
    logical, intent(out)                           :: lstat
    integer, intent(in), optional                  :: start(:), count(:), map(:)
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "write_var_double_var"
    integer :: varid
    type(etsf_io_low_error) :: error
    
    if (associated(var%data1D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_1D(ncid, varname, var%data1D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_1D(ncid, varname, var%data1D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data2D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_2D(ncid, varname, var%data2D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_2D(ncid, varname, var%data2D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data3D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_3D(ncid, varname, var%data3D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_3D(ncid, varname, var%data3D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data4D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_4D(ncid, varname, var%data4D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_4D(ncid, varname, var%data4D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data5D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_5D(ncid, varname, var%data5D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_5D(ncid, varname, var%data5D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data6D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_6D(ncid, varname, var%data6D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_6D(ncid, varname, var%data6D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data7D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_double_7D(ncid, varname, var%data7D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_double_7D(ncid, varname, var%data7D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else
      call etsf_io_low_error_set(error, ERROR_MODE_SPEC, ERROR_TYPE_ARG, me, &
                   & tgtname = "var", errmess = "no data array associated")
      lstat = .false.
    end if
    if (present(error_data)) then
      error_data = error
      if (.not. lstat) call etsf_io_low_error_update(error_data, me)
    end if
    if (present(ncvarid)) then
      ncvarid = varid
    end if
  end subroutine write_var_double_var
  
  ! Generic routine, documented in the module file.
  subroutine write_var_integer_var(ncid, varname, var, lstat, &
                                 & start, count, map, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    type(etsf_io_low_var_integer), intent(in)      :: var
    logical, intent(out)                           :: lstat
    integer, intent(in), optional                  :: start(:), count(:), map(:)
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "write_var_integer_var"
    integer :: varid
    type(etsf_io_low_error) :: error
    
    if (associated(var%data1D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_1D(ncid, varname, var%data1D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data2D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_2D(ncid, varname, var%data2D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data3D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_3D(ncid, varname, var%data3D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data4D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_4D(ncid, varname, var%data4D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data5D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_5D(ncid, varname, var%data5D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data6D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_6D(ncid, varname, var%data6D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else if (associated(var%data7D)) then
      if (present(start) .and. present(count) .and. present(map)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(count)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(start) .and. present(map)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, &
                               & start = start, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(count) .and. present(map)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, &
                               & count = count, map = map, &
                               & ncvarid = varid, error_data = error)
      else if (present(start)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, start = start, &
                               & ncvarid = varid, error_data = error)
      else if (present(count)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, count = count, &
                               & ncvarid = varid, error_data = error)
      else if (present(map)) then
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, map = map, &
                               & ncvarid = varid, error_data = error)
      else
        call write_var_integer_7D(ncid, varname, var%data7D, lstat, &
                               & ncvarid = varid, error_data = error)
      end if
    else
      call etsf_io_low_error_set(error, ERROR_MODE_SPEC, ERROR_TYPE_ARG, me, &
                   & tgtname = "var", errmess = "no data array associated")
      lstat = .false.
    end if
    if (present(error_data)) then
      error_data = error
      if (.not. lstat) call etsf_io_low_error_update(error_data, me)
    end if
    if (present(ncvarid)) then
      ncvarid = varid
    end if
  end subroutine write_var_integer_var
