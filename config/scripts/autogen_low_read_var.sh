#!/bin/sh

# This script auto generate the read method for the nD dimensional arrays.
# It create a new file for thiese read routines.
TARGET_FILE=src/low_level/read_routines_auto.f90
GENERATED_TYPES=( "integer" "double" "character" )
NF90_TYPES=( NF90_INT NF90_DOUBLE NF90_CHAR )

ATT_GENERATED_TYPES=( "integer" "real" "double" "character" )
ATT_NF90_TYPES=( NF90_INT NF90_FLOAT NF90_DOUBLE NF90_CHAR )

# If
if [ -f $TARGET_FILE ] ; then
  #echo "WARNING! target file already exists and will be overwritten."
  #echo "         Old version ($TARGET_FILE) is renamed with a '.old' extension."
  \cp $TARGET_FILE ${TARGET_FILE}.old
fi

# Echo a warning banner.
echo "!================================================================" > $TARGET_FILE
echo "! WARNING! this file is autogenerated. All modifications should" >> $TARGET_FILE
echo "! will be overwritten on next build. This file is automatically" >> $TARGET_FILE
echo "! produced by the scripts/autogen_read_arrays.sh." >> $TARGET_FILE
echo "!================================================================" >> $TARGET_FILE

# We append the new routines.
for ((i=0;i<3;i++)) ; do
  type=${GENERATED_TYPES[i]}
  nctype=${NF90_TYPES[i]}
  # We customize the type for the Fortran argument declaration.
  if test $type = "character" ; then
    fortrantype=${GENERATED_TYPES[i]}'(len = charlen)'
    # When character are concerned, one dimension is reserved for the length.
    start=2
    dimstart=1
    addarg=', charlen'
    charcomment=
  else
    if test $type = "double" ; then
      fortrantype=${GENERATED_TYPES[i]}' precision'
    else
      fortrantype=${GENERATED_TYPES[i]}
    fi
    start=1
    dimstart=0
    addarg=
    charcomment='!'
  fi
  for ((dim=${dimstart};dim<8;dim++)) ; do
    # We create the dimension declaration for the var array.
    if test $start -le $dim ; then
      vardims="("
      for ((j=$start;j<$dim;j++)) ; do
        vardims=${vardims}":,"
      done
      vardims=${vardims}":)"
      addcomment=
      
    else
      vardims=
      addcomment='!'
    fi
    cat >> $TARGET_FILE << EOF
  subroutine read_var_${type}_${dim}D(ncid, varname, var${addarg}, lstat, sub, ncvarid, error_data)
    integer, intent(in)                            :: ncid${addarg}
    character(len = *), intent(in)                 :: varname
    ${fortrantype}, intent(out) :: var${vardims}
    logical, intent(out)                           :: lstat
    integer, intent(in), optional                  :: sub(:)
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_read_var_${type}_${dim}D"
    character(len = 80) :: err
    type(etsf_io_low_var_infos) :: var_nc, var_user
    integer :: s, lvl, i, sub_value
    integer :: start(1:16), count(1:16)
    logical :: stat, sub_set

    lstat = .false.
    ! We get the dimensions and shape of the ref variable in the NetCDF file.
    if (present(error_data)) then
      call etsf_io_low_read_var_infos(ncid, varname, var_nc, stat, error_data = error_data)
    else
      call etsf_io_low_read_var_infos(ncid, varname, var_nc, stat)
    end if
    if (.not. stat) then
      return
    end if
    ! Consistency checks, when sub is present
    if (present(sub)) then
      if (size(sub) /= var_nc%ncshape) then
        write(err, "(A)") "inconsistent length (must be the shape of the ETSF variable)"
        if (present(error_data)) then
          call etsf_io_low_error_set(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ARG, me, &
                       & tgtname = "sub", errmess = err)
        end if
        return
      end if
      ! Build the start and count argument for the nf90_get_var() routine
      sub_value = var_nc%ncshape
      sub_set = .false.
      do i = 1, var_nc%ncshape, 1
        if (sub(i) == 0) then
          if (sub_set) then
            write(err, "(A)") "sub argument must not contain zero values after non-zero values."
            if (present(error_data)) then
              call etsf_io_low_error_set(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ARG, me, &
                                       & tgtname = "sub", errmess = err)
            end if
            return
          end if
          start(i) = 1
          count(i) = var_nc%ncdims(i)
        else
          if (.not. sub_set) then
            sub_value = i - 1
            sub_set = .true.
          end if
          start(i) = sub(i)
          count(i) = 1
          if (sub(i) < 0 .or. sub(i) > var_nc%ncdims(i)) then
            write(err, "(A,I0,A,I0,A)") "inconsistent value at index ", i, &
                                      & " (must be within ]0;", var_nc%ncdims(i), "])"
            if (present(error_data)) then
              call etsf_io_low_error_set(error_data, ERROR_MODE_SPEC, ERROR_TYPE_ARG, me, &
                                       & tgtname = "sub", errmess = err)
            end if
            return
          end if
        end if
      end do
    else
      ! Normal case, no sub reading
      start(:) = 1
      count = var_nc%ncdims
      sub_value = var_nc%ncshape
    end if
    var_user%nctype = ${nctype}
    var_user%ncshape = ${dim}
    ${addcomment}var_user%ncdims(${start}:${dim}) = shape(var)
    ${charcomment}var_user%ncdims(1) = charlen
    if (present(error_data)) then
      call etsf_io_low_check_var(var_nc, var_user, stat, level = lvl, sub = sub_value, &
                               & error_data = error_data)
    else
      call etsf_io_low_check_var(var_nc, var_user, stat, level = lvl, sub = sub_value)
    end if
    if (.not. stat) then
      return
    end if
    
    ! Now that we are sure that the read var has compatible type and dimension
    ! that the argument one, we can do the get action securely.
    if (modulo(lvl / etsf_io_low_var_shape_dif, 2) == 1 .or. present(sub)) then
      ! The shapes differ but are compatible, we then give the count and map
      ! arguments.
      s = nf90_get_var(ncid, var_nc%ncid, values = var, &
                      & start = start(1:var_nc%ncshape) &
      ${addcomment}                & ,count = count(1:var_nc%ncshape) &
      ${addcomment}                & ,map = (/ 1, (product(var_nc%ncdims(:i)), &
      ${addcomment}                & i = 1, var_nc%ncshape - 1) /) &
                      &       )
    else
      s = nf90_get_var(ncid, var_nc%ncid, values = var)
    end if
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_GET, ERROR_TYPE_VAR, me, &
                     & tgtname = varname, tgtid = var_nc%ncid, errid = s, &
                     & errmess = nf90_strerror(s))
      end if
      return
    end if
    if (present(ncvarid)) then
      ncvarid = var_nc%ncid
    end if
    lstat = .true.
  end subroutine read_var_${type}_${dim}D
EOF
  done
done

echo "!==========================================" >> $TARGET_FILE
echo "! Interface routines for attribute reading." >> $TARGET_FILE
echo "!==========================================" >> $TARGET_FILE

for ((i=0;i<4;i++)) ; do
  type=${ATT_GENERATED_TYPES[i]}
  nctype=${ATT_NF90_TYPES[i]}
  if test $type = "character" ; then
    fortrantype=${ATT_GENERATED_TYPES[i]}'(len = attlen)'
    vardims=
    init='write(att, "(A)") repeat(" " , attlen)'
  else
    if test $type = "double" ; then
      fortrantype=${ATT_GENERATED_TYPES[i]}' precision'
    else
      fortrantype=${ATT_GENERATED_TYPES[i]}
    fi
    vardims="(1:attlen)"
    init=
  fi
  cat >> $TARGET_FILE << EOF
  subroutine read_att_${type}_1D(ncid, ncvarid, attname, attlen, att, &
                                        & lstat, error_data)
    integer, intent(in)                            :: ncid
    integer, intent(in)                            :: ncvarid
    character(len = *), intent(in)                 :: attname
    integer, intent(in)                            :: attlen
    ${fortrantype}, intent(out)                    :: att${vardims}
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_read_att_${type}"
    integer :: s

    lstat = .false.
    ${init}
    ! We first check the definition of the attribute (name, type and dims)
    if (present(error_data)) then
      call etsf_io_low_check_att(ncid, ncvarid, attname, ${nctype}, &
                               & attlen, lstat, error_data = error_data)
    else
      call etsf_io_low_check_att(ncid, ncvarid, attname, ${nctype}, &
                               & attlen, lstat)
    end if
    if (.not. lstat) then
      return
    end if
    ! Now that we are sure that the read attribute has the same type and dimension
    ! that the argument one, we can do the get action securely.
    s = nf90_get_att(ncid, ncvarid, attname, att)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_GET, ERROR_TYPE_ATT, me, &
                     & tgtname = attname, tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine read_att_${type}_1D
EOF
  if test $type != "character" ; then
    cat >> $TARGET_FILE << EOF
  subroutine read_att_${type}(ncid, ncvarid, attname, att, &
                                        & lstat, error_data)
    integer, intent(in)                            :: ncid
    integer, intent(in)                            :: ncvarid
    character(len = *), intent(in)                 :: attname
    ${fortrantype}, intent(out)                    :: att
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_read_att_${type}"
    integer :: s

    lstat = .false.
    ! We first check the definition of the attribute (name, type and dims)
    if (present(error_data)) then
      call etsf_io_low_check_att(ncid, ncvarid, attname, ${nctype}, &
                               & 1, lstat, error_data = error_data)
    else
      call etsf_io_low_check_att(ncid, ncvarid, attname, ${nctype}, &
                               & 1, lstat)
    end if
    if (.not. lstat) then
      return
    end if
    ! Now that we are sure that the read attribute has the same type and dimension
    ! that the argument one, we can do the get action securely.
    s = nf90_get_att(ncid, ncvarid, attname, att)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_GET, ERROR_TYPE_ATT, me, &
                     & tgtname = attname, tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine read_att_${type}
EOF
  fi
done

# Echo a warning banner.
echo "!====================================" >> $TARGET_FILE
echo "! WARNING! end of autogenerated file." >> $TARGET_FILE
echo "!====================================" >> $TARGET_FILE
