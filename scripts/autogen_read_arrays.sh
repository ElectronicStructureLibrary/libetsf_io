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
  echo "WARNING! target file already exists and will be overwritten."
  echo "         Old version ($TARGET_FILE) is renamed with a '.old' extension."
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
    fortrantype=${GENERATED_TYPES[i]}'(len = vardims(1))'
    # When character are concerned, one dimension is reserved for the length.
    start=2
  else
    if test $type = "double" ; then
      fortrantype=${GENERATED_TYPES[i]}' precision'
    else
      fortrantype=${GENERATED_TYPES[i]}
    fi
    start=1
  fi
  for ((dim=1;dim<8;dim++)) ; do
    # We create the dimension declaration for the var array.
    if test $start -le $dim ; then
      vardims="("
      for ((j=$start;j<$dim;j++)) ; do
        vardims=${vardims}"1:vardims(${j}),"
      done
      vardims=${vardims}"1:vardims(${dim}))"
    else
      vardims=
    fi
    cat >> $TARGET_FILE << EOF
  subroutine etsf_io_low_read_var_${type}_${dim}D(ncid, varname, vardims, var, &
                                          & lstat, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    integer, intent(in)                            :: vardims(1:${dim})
    ${fortrantype}, intent(out) :: var${vardims}
    logical, intent(out)                           :: lstat
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_read_var_${type}_${dim}D"
    integer :: s, varid, i

    lstat = .false.
    ! We first check the definition of the variable (name, type and dims)
    if (present(error_data)) then
      call etsf_io_low_check_var(ncid, varid, varname, ${nctype}, &
                               & vardims, ${dim}, lstat, error_data = error_data)
    else
      call etsf_io_low_check_var(ncid, varid, varname, ${nctype}, &
                               & vardims, ${dim}, lstat)
    end if
    if (.not. lstat) then
      return
    end if
    lstat = .false.
    ! Now that we are sure that the read var has the same type and dimension
    ! that the argument one, we can do the get action securely.
    s = nf90_get_var(ncid, varid, values = var)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_GET, ERROR_TYPE_VAR, me, &
                     & tgtname = varname, tgtid = varid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    if (present(ncvarid)) then
      ncvarid = varid
    end if
    lstat = .true.
  end subroutine etsf_io_low_read_var_${type}_${dim}D
EOF
  done
  if test $type != "character" ; then
    # Scalar case
    cat >> $TARGET_FILE << EOF
  subroutine etsf_io_low_read_var_${type}_0D(ncid, varname, var, &
                                          & lstat, ncvarid, error_data)
    integer, intent(in)                            :: ncid
    character(len = *), intent(in)                 :: varname
    ${fortrantype}, intent(out)                    :: var
    logical, intent(out)                           :: lstat
    integer, intent(out), optional                 :: ncvarid
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_read_var_${type}_0D"
    integer :: s, varid, i

    lstat = .false.
    ! We first check the definition of the variable (name, type and dims)
    if (present(error_data)) then
      call etsf_io_low_check_var(ncid, varid, varname, ${nctype}, &
                               & (/ 1 /), 0, lstat, error_data = error_data)
    else
      call etsf_io_low_check_var(ncid, varid, varname, ${nctype}, &
                               & (/ 1 /), 0, lstat)
    end if
    if (.not. lstat) then
      return
    end if
    lstat = .false.
    ! Now that we are sure that the read var has the same type and dimension
    ! that the argument one, we can do the get action securely.
    s = nf90_get_var(ncid, varid, values = var)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call set_error(error_data, ERROR_MODE_GET, ERROR_TYPE_VAR, me, &
                     & tgtname = varname, tgtid = varid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    if (present(ncvarid)) then
      ncvarid = varid
    end if
    lstat = .true.
  end subroutine etsf_io_low_read_var_${type}_0D
EOF
  fi
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
  subroutine etsf_io_low_read_att_${type}_1D(ncid, ncvarid, attname, attlen, att, &
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
        call set_error(error_data, ERROR_MODE_GET, ERROR_TYPE_ATT, me, &
                     & tgtname = attname, tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_read_att_${type}_1D
EOF
  if test $type != "character" ; then
    cat >> $TARGET_FILE << EOF
  subroutine etsf_io_low_read_att_${type}(ncid, ncvarid, attname, att, &
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
        call set_error(error_data, ERROR_MODE_GET, ERROR_TYPE_ATT, me, &
                     & tgtname = attname, tgtid = ncvarid, errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_read_att_${type}
EOF
  fi
done

# Echo a warning banner.
echo "!====================================" >> $TARGET_FILE
echo "! WARNING! end of autogenerated file." >> $TARGET_FILE
echo "!====================================" >> $TARGET_FILE
