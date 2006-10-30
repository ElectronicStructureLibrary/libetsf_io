program tests_read

  use etsf_io_low_level
  
  implicit none

  integer :: ncid, nArg
  logical :: stat
  integer :: dimval
  character(len = 256) :: path
  
  nArg = iargc()
  if (nArg > 0) then
    call getarg(1, path)
  else
    write(path, "(A)") "."
  end if

  call tests_read_open(trim(path))
  call tests_read_dim(trim(path))
  call tests_check_var(trim(path))
  call tests_check_att(trim(path))
  
contains

  subroutine tests_read_status(name, lstat, error)
    character(len = *), intent(in)      :: name
    logical, intent(in)                 :: lstat
    type(etsf_io_low_error), intent(in) :: error
    
    if (lstat) then
      write(*, "(A,A,A,A)") "== ", name, repeat(" ", 68 - len(name)), "OK     =="
    else
      write(*, "(A,A,A,A)") "== ", name, repeat(" ", 68 - len(name)), "Failed =="
      call etsf_io_low_error_handle(error)
    end if
  end subroutine tests_read_status

  subroutine tests_read_open(path)
    character(len = *), intent(in) :: path
    integer :: ncid
    logical :: lstat
    type(etsf_io_low_error) :: error
    
    write(*,*)
    write(*,*) "Testing etsf_io_low_open_read()..."
    call etsf_io_low_open_read(ncid, "", lstat, error_data = error)
    call tests_read_status("argument filename: unknown file", (.not. lstat .and. &
      & error%access_mode_id == ERROR_MODE_IO .and. error%target_type_id == ERROR_TYPE_ORD), error)
    
    call etsf_io_low_open_read(ncid, path//"/tests_read.f90", lstat, error_data = error)
    call tests_read_status("argument filename: text file", (.not. lstat .and. &
      & error%access_mode_id == ERROR_MODE_IO .and. error%target_type_id == ERROR_TYPE_ORD), error)
    
    call etsf_io_low_open_read(ncid, path//"/open_read_t01.nc", lstat, error_data = error)
    call tests_read_status("argument filename: NetCDF without header", (.not. lstat .and. &
      & error%access_mode_id == ERROR_MODE_INQ), error)
    
    call etsf_io_low_open_read(ncid, path//"/open_read_t02.nc", lstat, error_data = error)
    call tests_read_status("argument filename: NetCDF with wrong file_format header", &
                         & (.not. lstat .and. error%access_mode_id == ERROR_MODE_SPEC), error)
                         
    call etsf_io_low_open_read(ncid, path//"/open_read_t03.nc", lstat, error_data = error)
    call tests_read_status("argument filename: NetCDF with obsolete file_format_version", &
                         & (.not. lstat .and. error%access_mode_id == ERROR_MODE_SPEC), error)
                         
    call etsf_io_low_open_read(ncid, path//"/open_read_t03.nc", lstat, version_min = 1.3, &
                            &  error_data = error)
    call tests_read_status("argument version_min: NetCDF with obsolete file_format_version", &
                         & (.not. lstat .and. error%access_mode_id == ERROR_MODE_SPEC), error)
                         
    call etsf_io_low_open_read(ncid, path//"/open_read_t04.nc", lstat, error_data = error)
    call tests_read_status("argument filename: NetCDF with a valid header", lstat, error)
    call etsf_io_low_close(ncid, lstat)
    
    write(*,*) 
  end subroutine tests_read_open
  
  subroutine tests_read_dim(path)
    character(len = *), intent(in) :: path
    integer :: ncid, dimvalue
    logical :: lstat
    type(etsf_io_low_error) :: error
    
    write(*,*)
    write(*,*) "Testing etsf_io_low_read_dim()..."
    call etsf_io_low_read_dim(0, "", dimvalue, lstat, error_data = error)
    call tests_read_status("argument ncid: wrong value", (.not. lstat .and. &
      & error%access_mode_id == ERROR_MODE_INQ), error)
    
    call etsf_io_low_open_read(ncid, path//"/read_dim_t01.nc", lstat)
    if (.not. lstat) then
      write(*,*) "Abort, can't open file"
      return
    end if
    call etsf_io_low_read_dim(ncid, "pouet", dimvalue, lstat, error_data = error)
    call tests_read_status("argument dimname: wrong value", (.not. lstat), error)
    
    call etsf_io_low_read_dim(ncid, "number_of_atoms", dimvalue, lstat, error_data = error)
    call tests_read_status("argument dimname: good value", (lstat .and. (dimvalue == 5)), error)

    call etsf_io_low_close(ncid, lstat)
    
    write(*,*) 
  end subroutine tests_read_dim

  subroutine tests_check_var(path)
    character(len = *), intent(in) :: path
    integer :: ncid, ncvarid, vartype, vardims(2)
    logical :: lstat
    type(etsf_io_low_error) :: error
    
    write(*,*)
    write(*,*) "Testing etsf_io_low_check_var()..."
    call etsf_io_low_check_var(0, ncvarid, "", vartype, vardims, 2, lstat, error_data = error)
    call tests_read_status("argument ncid: wrong value", (.not. lstat), error)
    
    call etsf_io_low_open_read(ncid, path//"/check_var_t01.nc", lstat)
    if (.not. lstat) then
      write(*,*) "Abort, can't open file"
      return
    end if

    call etsf_io_low_check_var(ncid, ncvarid, "pouet", vartype, vardims, 2, lstat, error_data = error)
    call tests_read_status("argument varname: wrong value", (.not. lstat), error)

    vartype = NF90_DOUBLE
    vardims(1) = 5
    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", vartype, vardims(1:1), &
                             & 1, lstat, error_data = error)
    call tests_read_status("argument vartype: wrong value", (.not. lstat), error)
    vartype = NF90_INT
    vardims(1) = 5
    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", vartype, vardims(1:1), &
                             & 1, lstat, error_data = error)
    call tests_read_status("argument vartype: good value", lstat, error)

    vartype = NF90_INT
    vardims(:) = (/ 5, 3 /)
    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", vartype, vardims, &
                             & 2, lstat, error_data = error)
    call tests_read_status("argument vardims: wrong dimension", (.not. lstat), error)
    vartype = NF90_INT
    vardims(1) = 10
    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", vartype, vardims(1:1), &
                             & 1, lstat, error_data = error)
    call tests_read_status("argument vardims: wrong values", (.not. lstat), error)
    vartype = NF90_DOUBLE
    vardims = (/ 3, 5 /)
    call etsf_io_low_check_var(ncid, ncvarid, "reduced_atom_positions", &
                             & vartype, vardims, 2, lstat, error_data = error)
    call tests_read_status("argument vardims: good values", lstat, error)
    
    call etsf_io_low_close(ncid, lstat)
    
    write(*,*) 
  end subroutine tests_check_var

  subroutine tests_check_att(path)
    character(len = *), intent(in) :: path
    integer :: ncid, atttype, attlen, ncvarid
    logical :: lstat
    type(etsf_io_low_error) :: error
    
    write(*,*)
    write(*,*) "Testing etsf_io_low_check_att()..."
    call etsf_io_low_check_att(0, NF90_GLOBAL, "", atttype, attlen, lstat, error_data = error)
    call tests_read_status("argument ncid: wrong value", (.not. lstat), error)
    
    call etsf_io_low_open_read(ncid, path//"/check_att_t01.nc", lstat)
    if (.not. lstat) then
      write(*,*) "Abort, can't open file"
      return
    end if
    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", NF90_INT, (/ 5 /), &
                             & 1, lstat, error_data = error)
    if (.not. lstat) then
      write(*,*) "Abort, can't get variable"
      call etsf_io_low_close(ncid, lstat)
      return
    end if

    call etsf_io_low_check_att(ncid, NF90_GLOBAL, "file_format", NF90_CHAR, 80, lstat, &
                             & error_data = error)
    call tests_read_status("argument ncvarid: NF90_GLOBAL value", lstat, error)

    call etsf_io_low_check_att(ncid, 0, "comment", NF90_CHAR, 80, lstat, error_data = error)
    call tests_read_status("argument ncvarid: wrong value", (.not. lstat), error)

    call etsf_io_low_check_att(ncid, ncvarid, "comment", NF90_CHAR, 80, lstat, &
                             & error_data = error)
    call tests_read_status("argument ncvarid: valid variable attribute", lstat, error)

    call etsf_io_low_check_att(ncid, NF90_GLOBAL, "file_format", NF90_INT, 80, lstat, &
                             & error_data = error)
    call tests_read_status("argument atttype: wrong value", (.not. lstat), error)

    call etsf_io_low_check_att(ncid, NF90_GLOBAL, "file_format_version", NF90_DOUBLE, 2, lstat, &
                             & error_data = error)
    call tests_read_status("argument attlen: wrong value", (.not. lstat), error)

    call etsf_io_low_check_att(ncid, NF90_GLOBAL, "file_format_version", NF90_DOUBLE, 1, lstat, &
                             & error_data = error)
    call tests_read_status("argument attlen: good value", lstat, error)
    call etsf_io_low_close(ncid, lstat)
    
    write(*,*) 
  end subroutine tests_check_att
  
!  subroutine tests_get_var_integer()
!    integer :: ncid, ncvarid
!    integer :: var(5)
!    logical :: lstat
!    
!    write(*,*)
!    write(*,*) "Testing etsf_io_low_get_var_integer()..."
!    call etsf_io_low_get_var(0, 0, var, 5, lstat)
!    call tests_read_status("argument ncid: wrong value", (.not. lstat))
!    
!    call etsf_io_low_open_read(ncid, "get_var_t01.nc", lstat)
!    if (.not. lstat) then
!      write(*,*) "Abort, can't open file"
!      return
!    end if
!    call etsf_io_low_check_var(ncid, ncvarid, "atom_species", NF90_INT, (/ 5 /), 1, lstat)
!    if (.not. lstat) then
!      write(*,*) "Abort, can't get variable"
!      call etsf_io_low_close(ncid, lstat)
!      return
!    end if
!
!    call etsf_io_low_get_var(ncid, 0, var, 5, lstat)
!    call tests_read_status("argument ncvarid: wrong value", (.not. lstat))
!
!    call etsf_io_low_get_var(ncid, ncvarid, var, 5, lstat, &
!                           & error_handle=etsf_io_low_error_handle)
!    call tests_read_status("argument ncvarid: good value", (lstat .and. &
!                         & var(1) == 1 .and. var(2) == 2 .and. var(3) == 2 .and. &
!                         & var(4) == 2 .and. var(5) == 2))
!
!    call etsf_io_low_close(ncid, lstat)
!    
!    write(*,*) 
!  end subroutine tests_get_var_integer
!
!  subroutine tests_get_var_double()
!    integer :: ncid, ncvarid, s
!    double precision :: var(3, 3), toto(9)
!    logical :: lstat
!    
!    write(*,*)
!    write(*,*) "Testing etsf_io_low_get_var_double()..."
!    call etsf_io_low_get_var(0, 0, var(1, :), 3, lstat)
!    call tests_read_status("argument ncid: wrong value", (.not. lstat))
!    
!    call etsf_io_low_open_read(ncid, "get_var_t01.nc", lstat)
!    if (.not. lstat) then
!      write(*,*) "Abort, can't open file"
!      return
!    end if
!    call etsf_io_low_check_var(ncid, ncvarid, "primitive_vectors", NF90_DOUBLE, (/ 3, 3 /), 2, !lstat)
!    if (.not. lstat) then
!      write(*,*) "Abort, can't get variable"
!      call etsf_io_low_close(ncid, lstat)
!      return
!    end if
!
!    call etsf_io_low_get_var(ncid, 0, var(1, :), 3, lstat)
!    call tests_read_status("argument ncvarid: wrong value", (.not. lstat))
!  
!    call etsf_io_low_get_var_double(ncid, ncvarid, toto, 9, lstat, &
!                           & error_handle=etsf_io_low_error_handle)
!    s = nf90_get_var(ncid, ncvarid, values = toto)
!    write(*,*) toto
!    s = nf90_get_var(ncid, ncvarid, values = var)
!    write(*,*) var
!    call tests_read_status("argument ncvarid: good value", (lstat .and. &
!                         & var(1, 1) == 10. .and. var(1, 2) == 0. .and. var(1, 3) == 0. .and. &
!                         & var(2, 1) == 0. .and. var(2, 2) == 10. .and. var(2, 3) == 0. .and. &
!                         & var(3, 1) == 0. .and. var(3, 2) == 0. .and. var(3, 3) == 10.))
!
!    call etsf_io_low_close(ncid, lstat)
!    
!    write(*,*) 
!  end subroutine tests_get_var_double
  
end program tests_read
