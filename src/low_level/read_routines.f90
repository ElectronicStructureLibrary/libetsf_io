  subroutine etsf_io_low_read_dim(ncid, dimname, dimvalue, lstat, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: dimname
    integer, intent(out)                           :: dimvalue
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !local
    character(len = *), parameter :: me = "etsf_io_low_read_dim"
    integer :: s, dimid

    lstat = .false.
    ! will inq_dimid() and inq_dimlen() + error handling
    s = nf90_inq_dimid(ncid, dimname, dimid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_DID, me, tgtname = dimname, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    s = nf90_inquire_dimension(ncid, dimid, len = dimvalue)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_DIM, me, tgtname = dimname, &
                     & tgtid = dimid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.    
  end subroutine etsf_io_low_read_dim
  
  subroutine etsf_io_low_check_var(ncid, ncvarid, varname, vartype, vardims, &
                                 & nbvardims, lstat, error_data)
    integer, intent(in)                            :: ncid
    integer, intent(out)                           :: ncvarid
    character(len = *), intent(in)                 :: varname
    integer, intent(in)                            :: vartype, nbvardims
    integer, intent(in)                            :: vardims(1:nbvardims)
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_check_var"
    character(len = 80) :: err
    integer :: i, s, nctype, ncdims, dimvalue
    integer, allocatable :: ncdimids(:)
    
    lstat = .false.
    ! will inq_varid()
    s = nf90_inq_varid(ncid, varname, ncvarid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_VID, me, tgtname = varname, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! will inq_vartype()
    ! will inq_varndims()
    s = nf90_inquire_variable(ncid, ncvarid, xtype = nctype, ndims = ncdims)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_VAR, me, tgtname = varname, &
                     & tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! Check the type
    if (nctype /= vartype) then
      write(err, "(A,I5,A,I5,A)") "wrong type (read = ", nctype, &
                                & ", awaited = ", vartype, ")"
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_VAR, me, tgtname = varname, &
                     & tgtid = ncvarid, errmess = err)
      end if
      return
    end if
    ! Check the dimensions
    if (ncdims /= nbvardims) then
      write(err, "(A,I5,A,I5,A)") "wrong number of dimensions (read = ", ncdims, &
                                & ", awaited = ", nbvardims, ")"
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_VAR, me, tgtname = varname, &
                     & tgtid = ncvarid, errmess = err)
      end if
      return
    end if
    ! will inq_vardimid()
    allocate(ncdimids(1:nbvardims))
    s = nf90_inquire_variable(ncid, ncvarid, dimids = ncdimids)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_VAR, me, tgtname = varname, &
                     & tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      deallocate(ncdimids)
      return
    end if
    do i = 1, nbvardims, 1
      ! will inq_dimlen()
      s = nf90_inquire_dimension(ncid, ncdimids(i), len = dimvalue)
      if (s /= nf90_noerr) then
        if (present(error_data)) then
          call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_DIM, me, &
                       & tgtid = ncdimids(i), errid = s, errmess = nf90_strerror(s))
        end if
        deallocate(ncdimids)
        return
      end if
      ! Test the dimensions
      if (dimvalue /= vardims(i)) then
        write(err, "(A,I0,A,I5,A,I5,A)") "wrong dimension length for index ", i, &
                                       & " (read = ", dimvalue, &
                                       & ", awaited = ", vardims(i), ")"
        if (present(error_data)) then
          call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_VAR, me, tgtname = varname, &
                       & tgtid = ncvarid, errmess = err)
        end if
        deallocate(ncdimids)
        return
      end if
    end do
    deallocate(ncdimids)
    lstat = .true.
  end subroutine etsf_io_low_check_var
  
  subroutine etsf_io_low_check_att(ncid, ncvarid, attname, atttype, attlen, lstat, error_data)
    integer, intent(in)                            :: ncid
    integer, intent(in)                            :: ncvarid
    character(len = *), intent(in)                 :: attname
    integer, intent(in)                            :: atttype, attlen
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data
    
    !Local
    character(len = *), parameter :: me = "etsf_io_low_check_att"
    character(len = 80) :: err
    integer :: s, nctype, nclen

    lstat = .false.    
    s = nf90_inquire_attribute(ncid, ncvarid, attname, xtype = nctype, len = nclen) 
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_INQ, ERROR_TYPE_ATT, me, tgtname = attname, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! Check the type
    if (nctype /= atttype) then
      write(err, "(A,I5,A,I5,A)") "wrong type (read = ", nctype, &
                                & ", awaited = ", atttype, ")"
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, me, tgtname = attname, &
                     & errmess = err)
      end if
      return
    end if
    ! Check the dimensions
    if ((atttype == NF90_CHAR .and. nclen > attlen) .or. &
      & (atttype /= NF90_CHAR .and. nclen /= attlen)) then
      write(err, "(A,I5,A,I5,A)") "wrong length (read = ", nclen, &
                                & ", awaited = ", attlen, ")"
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, me, tgtname = attname, &
                     & errmess = err)
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_check_att
  
  subroutine etsf_io_low_check_header(ncid, lstat, version_min, error_data)
    integer, intent(in)                            :: ncid
    logical, intent(out)                           :: lstat
    real, intent(in), optional                     :: version_min
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_check_header"
    character(len = 80) :: err, format
    integer :: s
    real :: version_real
    logical :: stat

    lstat = .false.
    ! Check the header
    write(format, "(A80)") " "
    if (present(error_data)) then
      call etsf_io_low_read_att(ncid, NF90_GLOBAL, "file_format", 80, format, stat, error_data) 
    else
      call etsf_io_low_read_att(ncid, NF90_GLOBAL, "file_format", 80, format, stat) 
    end if
    if (.not. stat) then
      call etsf_io_low_close(ncid, stat)
      return
    end if
    if (trim(adjustl(format)) /= "ETSF Nanoquanta") then
      write(err, "(A,A,A)") "wrong value: '", trim(adjustl(format(1:60))), "'"
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, me, tgtname = "file_format", &
                     & errmess = err)
      end if
      call etsf_io_low_close(ncid, stat)
      return
    end if
    ! Check the version
    if (present(error_data)) then
      call etsf_io_low_read_att(ncid, NF90_GLOBAL, "file_format_version", &
                              & version_real, stat, error_data) 
    else
      call etsf_io_low_read_att(ncid, NF90_GLOBAL, "file_format_version", &
                              & version_real, stat)
    end if
    if (.not. stat) then
      call etsf_io_low_close(ncid, stat)
      return
    end if
    if (present(version_min)) then
      stat = (version_real >= version_min)
    else
      stat = (version_real >= 1.3)
    end if
    if (.not. stat) then
      write(err, "(A,F10.5)") "wrong value: ", version_real
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ATT, me, tgtname = "file_format_version", &
                     & errmess = err)
      end if
      call etsf_io_low_close(ncid, stat)
      return
    end if
    ! Check for the Conventions flag
    if (present(error_data)) then
      call etsf_io_low_check_att(ncid, NF90_GLOBAL, "Conventions", &
                               & NF90_CHAR, 80, stat, error_data) 
    else
      call etsf_io_low_check_att(ncid, NF90_GLOBAL, "Conventions", NF90_CHAR, 80, stat) 
    end if
    if (.not. stat) then
      call etsf_io_low_close(ncid, stat)
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_check_header
  
  subroutine etsf_io_low_open_read(ncid, filename, lstat, version_min, error_data)
    integer, intent(out)                           :: ncid
    character(len = *), intent(in)                 :: filename
    logical, intent(out)                           :: lstat
    real, intent(in), optional                     :: version_min
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_open_read"
    integer :: s
    
    lstat = .false.
    ! Open file for reading
    s = nf90_open(path = filename, mode = NF90_NOWRITE, ncid = ncid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_IO, ERROR_TYPE_ORD, me, tgtname = filename, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    ! From now on the file is open. If an error occur,
    ! we should close it.

    if (present(error_data)) then
      if (present(version_min)) then
        call etsf_io_low_check_header(ncid, lstat, version_min, error_data)
      else
        call etsf_io_low_check_header(ncid, lstat, error_data = error_data)
      end if
    else
      if (present(version_min)) then
        call etsf_io_low_check_header(ncid, lstat, version_min = version_min)
      else
        call etsf_io_low_check_header(ncid, lstat)
      end if
    end if
  end subroutine etsf_io_low_open_read
