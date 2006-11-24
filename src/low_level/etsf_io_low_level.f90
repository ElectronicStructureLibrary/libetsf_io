!!****h* low_level/etsf_io_low_level
!! NAME
!!  etsf_io_low_level -- ESTF I/O low level wrapper around NetCDF routines
!!
!! FUNCTION
!!  This module is used to wrap commonly used NetCDF calls. It gives an API
!!  which should be safe with automatic dimensions checks, and easy to use
!!  with methods only needed by a parser/writer library focused on the
!!  ETSF specifications. Nevertheless, this module can be used for other
!!  purpose than only reading/writing files conforming to ETSF specifications.
!!
!!  It also support an optional error handling structure. This structure
!!  can be used on any methods to get fine informations about any failure.
!!
!!  All methods have a logical argument that is set to .true. if everything
!!  went fine. In that case, all output arguments have relevant values. If @lstat
!!  is .false., no output values should be used since their values are not
!!  guaranteed.
!!
!! COPYRIGHT
!!  Copyright (C) 2006
!!  This file is distributed under the terms of the
!!  GNU General Public License, see ~abinit/COPYING
!!  or http://www.gnu.org/copyleft/gpl.txt .
!!
!!***
module etsf_io_low_level

  use netcdf

  implicit none

  ! Basic variables  
  character(len = *), parameter, private :: &
    & etsf_io_low_file_format = "ETSF Nanoquanta"
  character(len = *), parameter, private :: &
    & etsf_io_low_conventions = "http://www.etsf.eu/fileformats/"

  ! Error handling
  integer, parameter, private :: nb_access_mode = 6
  character(len = 15), dimension(nb_access_mode), parameter, private :: &
    & etsf_io_low_error_mode = (/ "define         ", &
                                & "get            ", &
                                & "input/output   ", &
                                & "inquire        ", &
                                & "put            ", &
                                & "specifications " /)

  integer, parameter, private :: nb_target_type = 12
  character(len = 22), dimension(nb_target_type), parameter, private :: &
    & etsf_io_low_error_type = (/ "attribute             ", "dimension ID          ", &
                                & "dimension             ", "end definitions       ", &
                                & "define mode           ", "create file           ", &
                                & "open file for reading ", "open file for writing ", &
                                & "variable              ", "variable ID           ", &
                                & "close file            ", "routine argument      " /)

  
  include "public_variables.f90"
    
  !!****m* etsf_io_low_read_group/etsf_io_low_read_var
  !! NAME
  !!  etsf_io_low_read_var
  !!
  !! SYNOPSIS
  !!  * call etsf_io_low_read_var(ncid, varname, var, lstat, ncvarid, sub, error_data)
  !!  * call etsf_io_low_read_var(ncid, varname, var, charlen, lstat, ncvarid, sub, error_data)
  !!
  !! FUNCTION
  !!  This is a generic interface to read values of a variables (either integer
  !!  or double or character). Before puting values in the @var argument, the
  !!  dimensions of the read data are compared with the assumed dimensions of @var.
  !!  The type is also checked, based on the type of the @var argument. Using
  !!  this routine is then a safe way to read data from a NetCDF file. The size and
  !!  shape of @var can be either a scalar, a one dimensional array or a multi
  !!  dimensional array. Strings should be given with their length. See
  !!  the example below on how to read a string. @var can also be a #etsf_io_low_var_double,
  !!  or a #etsf_io_low_var_integer. In this case, the associated pointer is used
  !!  as the storage area for the read values.
  !!
  !!  If the shape of the given storage variable (@var) and the definition of the
  !!  corresponding NetCDF variable differ ; the read is done only if the number of
  !!  elements are identical. Number of elements is the product over all dimensions
  !!  of the size (see example below).
  !!
  !!  It is also possible to read some particular dimensions of one variable using
  !!  the optional @sub argument. This is only possible for multi-dimensional variables
  !!  and is compatible with a shape modification. See the following examples. The @sub
  !!  argument is an array specifying for each dimension of the NetCDF variable, if
  !!  all values of that dimension are read or if only one index is accessed. The order
  !!  of dimensions are given in the Fortran order (inverse of the specification
  !!  order).
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with read access.
  !!  * varname = a string identifying a variable.
  !!
  !! OUTPUT
  !!  * var = an allocated array to store the read values (or a simple scalar).
  !!  * lstat = .true. if operation succeed.
  !!  * sub = (optional) an array, with the same size than the shape of the NetCDF
  !!          variable to be read. When sub(i) == 0, then the data for that dimension
  !!          are totally read, else for sub(i) > 0, only the data at this index are read.
  !!  * ncvarid = (optional) the id used by NetCDF to identify the read variable.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! EXAMPLE
  !!  Read a string stored in "exchange_functional" variable of length 80:
  !!   character(len = 80) :: var
  !!   call etsf_io_low_read_var(ncid, "exchange_functional", var, 80, lstat)
  !!
  !!  Get one single integer stored in "space_group":
  !!   integer :: sp
  !!   call etsf_io_low_read_var(ncid, "space_group", sp, lstat)
  !!
  !!  Get a 2 dimensional array storing reduced atom coordinates:
  !!   double precision :: coord(3, 5)
  !!   call etsf_io_low_read_var(ncid, "reduced_atom_positions", coord, lstat)
  !!
  !!  Get a 2 dimensional array stored as a four dimensional array:
  !!   NetCDF def: density(2, 3, 3, 3) # dimensions in NetCDF are reverted
  !!                                   # compared to Fortran style
  !!   double precision :: density(27, 2)
  !!   call etsf_io_low_read_var(ncid, "density", density, lstat)
  !!
  !!  Get the last 3 dimensions of a 4D array:
  !!   NetCDF def: density(2, 3, 4, 5) # dimensions in NetCDF are reverted
  !!                                   # compared to Fortran style
  !!   double precision :: density_down(5, 4, 3)
  !!   call etsf_io_low_read_var(ncid, "density", density_down, lstat, sub = (/ 0, 0, 0, 2 /))
  !!
  !!  Get the last 3 dimensions of a 4D array and store them into a 1D array:
  !!   NetCDF def: density(2, 3, 3, 3) # dimensions in NetCDF are reverted
  !!                                   # compared to Fortran style
  !!   double precision :: density_up(27)
  !!   call etsf_io_low_read_var(ncid, "density", density_up, lstat, sub = (/ 0, 0, 0, 1 /))
  !!
  !!  Read data to a dimension stored in the main program, without duplication
  !!  of data in memory:
  !!   integer, target :: atom_species(number_of_atoms)
  !!   ...
  !!   type(etsf_io_low_var_integer) :: var
  !!   var%data1D => atom_species
  !!   call etsf_io_low_read_var(ncid, "atom_species", var, lstat)
  !!***
  !Generic interface of the routines etsf_io_low_read_var
  interface etsf_io_low_read_var
    module procedure read_var_integer_var
    module procedure read_var_integer_0D
    module procedure read_var_integer_1D
    module procedure read_var_integer_2D
    module procedure read_var_integer_3D
    module procedure read_var_integer_4D
    module procedure read_var_integer_5D
    module procedure read_var_integer_6D
    module procedure read_var_integer_7D
    module procedure read_var_double_var
    module procedure read_var_double_0D
    module procedure read_var_double_1D
    module procedure read_var_double_2D
    module procedure read_var_double_3D
    module procedure read_var_double_4D
    module procedure read_var_double_5D
    module procedure read_var_double_6D
    module procedure read_var_double_7D
    module procedure read_var_character_1D
    module procedure read_var_character_2D
    module procedure read_var_character_3D
    module procedure read_var_character_4D
    module procedure read_var_character_5D
    module procedure read_var_character_6D
    module procedure read_var_character_7D
  end interface etsf_io_low_read_var
  !End of the generic interface of etsf_io_low_read_var
  
  !!****m* etsf_io_low_read_group/etsf_io_low_read_att
  !! NAME
  !!  etsf_io_low_read_att
  !!
  !! SYNOPSIS
  !!  * call etsf_io_low_read_att(ncid, ncvarid, attname, attlen, att, lstat, error_data)
  !!  * call etsf_io_low_read_att(ncid, ncvarid, attname, att, lstat, error_data)
  !!
  !! FUNCTION
  !!  This is a generic interface to read values of an attribute (either integer,
  !!  real, double or character). Before puting values in the @att argument, the
  !!  dimensions of the read data are compared with the given dimensions (@attlen).
  !!  The type is also checked, based on the type of the @att argument. Using
  !!  this routine is then a safe way to read attribute data from a NetCDF file.
  !!  The size and shape of @att can be either a scalar or a one dimensional array.
  !!  In the former case, the argument @attlen must be omitted. Strings are considered
  !!  to be one dimensional arrays. See the example below on how to read a string.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with read access.
  !!  * ncvarid = the id of the variable the attribute is attached to.
  !!              in the case of global attributes, use the constance
  !!              NF90_GLOBAL (when linking against NetCDF) or #etsf_io_low_global_att
  !!              which is a wrapper exported by this module (see #ETSF_IO_LOW_CONSTANTS).
  !!  * attname = a string identifying an attribute.
  !!  * attlen = the size of the array @att (when required).
  !!
  !! OUTPUT
  !!  * att = an allocated array to store the read values. When @attlen is
  !!          omitted, this argument @att must be a scalar, not an array.
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! EXAMPLE
  !!  Read a string stored in "symmorphic" attribute of length 80:
  !!   character(len = 80) :: att
  !!   call etsf_io_low_read_att(ncid, ncvarid, "symmorphic", 80, att, lstat)
  !!
  !!  Get one single real stored in "file_format_version" which is a global attribute:
  !!   real :: version
  !!   call etsf_io_low_read_att(ncid, "file_format_version", version, lstat)
  !!
  !!***
  !Generic interface of the routines etsf_io_low_read_att
  interface etsf_io_low_read_att
    module procedure read_att_integer
    module procedure read_att_real
    module procedure read_att_double
    module procedure read_att_integer_1D
    module procedure read_att_real_1D
    module procedure read_att_double_1D
    module procedure read_att_character_1D
  end interface etsf_io_low_read_att
  !End of the generic interface of etsf_io_low_read_att

  !!****m* etsf_io_low_write_group/etsf_io_low_def_var
  !! NAME
  !!  etsf_io_low_def_var
  !!
  !! SYNOPSIS
  !!  * call etsf_io_low_def_var(ncid, varname, vartype, vardims, lstat, ncvarid, error_data)
  !!  * call etsf_io_low_def_var(ncid, varname, vartype, lstat, ncvarid, error_data)
  !!
  !! FUNCTION
  !!  In the contrary of dimensions or attributes, before using a write method on variables
  !!  they must be defined using such methods. This allow to choose the type, the shape
  !!  and the size of a new variable. Once defined, a variable can't be changed or removed.
  !!
  !!  One can add scalars, one dimensional arrays or multi-dimensional arrays (restricted
  !!  to a maximum of 7 dimensions). See the examples below to know how to use such methods.
  !!
  !!  As in pure NetCDF, it is impossible to overwrite the definition of a variable.
  !!  Nevertheless, the method returns .true. in @lstat, if the definition is done a second
  !!  time with the same type, shape and dimensions.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access (define mode).
  !!  * varname = the name for the new variable.
  !!  * vartype = the type of the new variable (see #ETSF_IO_LOW_CONSTANTS).
  !!  * vardims = an array with the size for each dimension of the variable.
  !!              Each size is given by the name of its dimension. Thus dimensions
  !!              must already exist (see etsf_io_low_write_dim()).
  !!              When omitted, the variable is considered as a scalar.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * ncvarid = (optional) the id used by NetCDF to identify the written variable.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! EXAMPLE
  !!  Define a string stored as "basis_set" of length "character_string_length":
  !!   call etsf_io_low_def_var(ncid, "basis_set", etsf_io_low_character, &
  !!                          & (/ "character_string_length" /), lstat)
  !!
  !!  Define one integer stored as "space_group":
  !!   call etsf_io_low_def_var(ncid, "space_group", etsf_io_low_integer, lstat)
  !!
  !!  Define a two dimensional array of double stored as "reduced_symetry_translations":
  !!   call etsf_io_low_def_var(ncid, "reduced_symetry_translations", etsf_io_low_double, &
  !!                          & (/ "number_of_reduced_dimensions", &
  !!                          &    "number_of_symetry_operations" /), lstat)
  !!***
  !Generic interface of the routines etsf_io_low_def_var
  interface etsf_io_low_def_var
    module procedure etsf_io_low_def_var_0D
    module procedure etsf_io_low_def_var_nD
  end interface etsf_io_low_def_var
  !End of the generic interface of etsf_io_low_def_var

  !!****m* etsf_io_low_write_group/etsf_io_low_write_att
  !! NAME
  !!  etsf_io_low_write_att
  !!
  !! SYNOPSIS
  !!  call etsf_io_low_write_att(ncid, ncvarid, attname, att, lstat, error_data)
  !!
  !! FUNCTION
  !!  When in defined mode, one can add attributes and set then a value in one call
  !!  using such a method. Attributes can be strings, scalar or one dimensional arrays
  !!  of integer, real or double precision.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access (define mode).
  !!  * ncvarid = the id of the variable the attribute is attached to.
  !!              in the case of global attributes, use the constance
  !!              NF90_GLOBAL (when linking against NetCDF) or #etsf_io_low_global_att
  !!              which is a wrapper exported by this module (see #ETSF_IO_LOW_CONSTANTS).
  !!  * attname = the name for the new attribute.
  !!  * att = the value, can be a string a scalar or a one-dimension array.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! EXAMPLE
  !!  Write a string stored as "symmorphic", attribute of varaible ncvarid:
  !!   call etsf_io_low_def_var(ncid, ncvarid, "symmorphic", "Yes", lstat)
  !!
  !!  Write one real stored as "file_format_version", global attribute:
  !!   call etsf_io_low_def_var(ncid, etsf_io_low_global_att, "file_format_version", &
  !!                          & 1.3, lstat)
  !!***
  !Generic interface of the routines etsf_io_low_write_att
  interface etsf_io_low_write_att
    module procedure write_att_integer
    module procedure write_att_real
    module procedure write_att_double
    module procedure write_att_integer_1D
    module procedure write_att_real_1D
    module procedure write_att_double_1D
    module procedure write_att_character_1D
  end interface etsf_io_low_write_att
  !End of the generic interface of etsf_io_low_write_att

  !!****m* etsf_io_low_write_group/etsf_io_low_write_var
  !! NAME
  !!  etsf_io_low_write_var
  !!
  !! SYNOPSIS
  !!  * call etsf_io_low_write_var(ncid, varname, var, lstat, ncvarid, sub, error_data)
  !!  * call etsf_io_low_write_var(ncid, varname, var, charlen, lstat, ncvarid, sub, error_data)
  !!
  !! FUNCTION
  !!  This is a generic interface to write values of a variables (either integer
  !!  or double or strings). Before using such methods, variables must have been
  !!  defined using etsf_io_low_def_var(). Before writting values from the @var argument, the
  !!  dimensions of the given data are compared with the defined dimensions.
  !!  The type is also checked, based on the type of the @var argument. Using
  !!  this routine is then a safe way to write data from a NetCDF file. The size and
  !!  shape of @var can be either a scalar, a one dimensional array or a multi
  !!  dimensional array. Strings should be given with their length. See
  !!  the example below on how to write a string. @var can also be a #etsf_io_low_var_double,
  !!  or a #etsf_io_low_var_integer. In this case, the associated pointer is used
  !!  as the storage area for the written values.
  !!
  !!  If the shape of the input data variable (@var) and the definition of the
  !!  corresponding NetCDF variable differ ; the write action is performed only if the number of
  !!  elements are identical. Number of elements is the product over all dimensions
  !!  of the size (see example below).
  !!
  !!  It is also possible to write some particular dimensions of one variable using
  !!  the optional @sub argument. This is only possible for multi-dimensional variables
  !!  and is compatible with a shape modification. See the following examples. The @sub
  !!  argument is an array specifying for each dimension of the NetCDF variable, if
  !!  all values of that dimension are written or if only one index is accessed. The order
  !!  of dimensions are given in the Fortran order (inverse of the specification
  !!  order).
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with read access.
  !!  * varname = a string identifying a variable.
  !!  * var = the values to be written, either a scalar or an array.
  !!  * charlen = when @var is a string or an array of strings, their size
  !!              must be given.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * sub = (optional) an array, with the same size than the shape of the NetCDF
  !!          variable to be read. When sub(i) == 0, then the data for that dimension
  !!          are totally read, else for sub(i) > 0, only the data at this index are read.
  !!  * ncvarid = (optional) the id used by NetCDF to identify the written variable.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! EXAMPLE
  !!  Write a string stored in "exchange_functional" variable of length 80:
  !!   call etsf_io_low_read_var(ncid, "exchange_functional", "My functional", 80, lstat)
  !!
  !!  Write one single integer stored in "space_group":
  !!   call etsf_io_low_read_var(ncid, "space_group", 156, lstat)
  !!
  !!  Write a 2 dimensional array storing reduced atom coordinates:
  !!   double precision :: coord2d(3, 4)
  !!   coord2d = reshape((/ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 /), (/ 3, 4 /))
  !!   call etsf_io_low_read_var(ncid, "reduced_atom_positions", coord2d, lstat)
  !!  or,
  !!   double precision :: coord(12)
  !!   coord = (/ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 /)
  !!   call etsf_io_low_read_var(ncid, "reduced_atom_positions", coord, lstat)
  !!
  !!  Write the last 3 dimensions of a 4D array:
  !!   NetCDF def: density(2, 3, 4, 5) # dimensions in NetCDF are reverted
  !!                                   # compared to Fortran style
  !!   double precision :: density_down(5, 4, 3)
  !!   call etsf_io_low_write_var(ncid, "density", density_down, lstat, sub = (/ 0, 0, 0, 2 /))
  !!
  !!  Write the last 3 dimensions of a 4D array and read them from a 1D array:
  !!   NetCDF def: density(2, 3, 3, 3) # dimensions in NetCDF are reverted
  !!                                   # compared to Fortran style
  !!   double precision :: density_up(27)
  !!   call etsf_io_low_write_var(ncid, "density", density_up, lstat, sub = (/ 0, 0, 0, 1 /))
  !!
  !!  Write data from a dimension stored in the main program, without duplication
  !!  of data in memory:
  !!   integer, target :: atom_species(number_of_atoms)
  !!   ...
  !!   type(etsf_io_low_var_integer) :: var
  !!   var%data1D => atom_species
  !!   call etsf_io_low_write_var(ncid, "atom_species", var, lstat)
  !!***
  !Generic interface of the routines etsf_io_low_write_var
  interface etsf_io_low_write_var
    module procedure write_var_integer_var
    module procedure write_var_integer_0D
    module procedure write_var_integer_1D
    module procedure write_var_integer_2D
    module procedure write_var_integer_3D
    module procedure write_var_integer_4D
    module procedure write_var_integer_5D
    module procedure write_var_integer_6D
    module procedure write_var_integer_7D
    module procedure write_var_double_var
    module procedure write_var_double_0D
    module procedure write_var_double_1D
    module procedure write_var_double_2D
    module procedure write_var_double_3D
    module procedure write_var_double_4D
    module procedure write_var_double_5D
    module procedure write_var_double_6D
    module procedure write_var_double_7D
    module procedure write_var_character_1D
    module procedure write_var_character_2D
    module procedure write_var_character_3D
    module procedure write_var_character_4D
    module procedure write_var_character_5D
    module procedure write_var_character_6D
    module procedure write_var_character_7D
  end interface etsf_io_low_write_var
  !End of the generic interface of etsf_io_low_write_var
  
  !!****f* etsf_io_low_level/etsf_io_low_var_associated
  !! NAME
  !!  etsf_io_low_var_associated
  !!
  !! FUNCTION
  !!  This function works as the associated() intrinsic function but with
  !!  pointers of undefined shapes (see #etsf_io_low_var_integer and #etsf_io_low_var_double).
  !!
  !! SYNOPSIS
  !!  call etsf_io_low_var_associated(array)
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * array <type(etsf_io_low_var_*)> = an undefined shape array.
  !!
  !! OUTPUT
  !!  * returns .true. if one of the array datanD is associated.
  !!***
  interface etsf_io_low_var_associated
    module procedure var_integer_associated
    module procedure var_double_associated
  end interface etsf_io_low_var_associated
  
  !!****g* etsf_io_low_level/etsf_io_low_error_group
  !! FUNCTION
  !!  These methods are used to handle errors generated by ETSF access.
  !!  For this a Fortran type is used and called #etsf_io_low_error. It
  !!  stores several informations such as the name of the method where the
  !!  error occured or a message describing the error. One can create an
  !!  error using etsf_io_low_error_set() and then put it into a nice
  !!  string for future use with etsf_io_low_error_to_str().
  !!
  !! SOURCE
  public :: etsf_io_low_error
  public :: etsf_io_low_error_handle
  public :: etsf_io_low_error_set
  public :: etsf_io_low_error_to_str
  !!***

  !!****g* etsf_io_low_level/etsf_io_low_file_group
  !! FUNCTION
  !!  When accessing a ETSF file, there is three routines to do that. One can:
  !!   * create a new file with etsf_io_low_open_create() ;
  !!   * read an already existing file with etsf_io_low_open_read() ;
  !!   * write data to a an already existing file with etsf_io_low_open_modify().
  !!
  !! SOURCE
  public :: etsf_io_low_close
  public :: etsf_io_low_open_create
  public :: etsf_io_low_open_modify
  public :: etsf_io_low_open_read
  !!***

  !!****g* etsf_io_low_level/etsf_io_low_check_group
  !! FUNCTION
  !!  These routines are used to check informations defined in an openend ETSF file.
  !!
  !! SOURCE
  public :: etsf_io_low_check_att
  public :: etsf_io_low_check_header
  public :: etsf_io_low_check_var
  !!***

  !!****g* etsf_io_low_level/etsf_io_low_read_group
  !! FUNCTION
  !!  These routines are used read data from an ETSF file. These data can be:
  !!  * dimensions ;
  !!  * attributes (global or not) ;
  !!  * variables.
  !!
  !! SOURCE
  public :: etsf_io_low_var_infos
  public :: etsf_io_low_read_att
  public :: etsf_io_low_read_dim
  public :: etsf_io_low_read_var
  public :: etsf_io_low_read_var_infos
  !!***

  !!****g* etsf_io_low_level/etsf_io_low_write_group
  !! FUNCTION
  !!  These routines are used write (or define) data from an ETSF file. These data can be:
  !!  * dimensions ;
  !!  * attributes (global or not) ;
  !!  * variables.
  !!
  !! SOURCE
  public :: etsf_io_low_def_var
  public :: etsf_io_low_write_att
  public :: etsf_io_low_write_dim
  public :: etsf_io_low_write_var
  !!***
  
  ! Private variables & methods.
  private :: var_integer_associated
  private :: var_double_associated
contains

  !!****m* etsf_io_low_error_group/etsf_io_low_error_set
  !! NAME
  !!  etsf_io_low_error_set
  !!
  !! FUNCTION
  !!  This routine is used to initialise a #etsf_io_low_error object with values.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * mode = a value from #ERROR_MODE, specifying the action when the error occurs.
  !!  * type = a value from #ERROR_TYPE, specifying the kind of target.
  !!  * parent = the name of the routine in which the error occurs.
  !!  * tgtid = (optional) an id representing the target (or -1).
  !!  * tgtname = (optional) a name representing the target (or "").
  !!  * errmess = (optional) a string with an explanation.
  !!
  !! OUTPUT
  !!  * error_data <type(etsf_io_low_error)> = the error with sensible values in its fields.
  !!
  !! SOURCE
  subroutine etsf_io_low_error_set(error_data, mode, type, parent, tgtid, tgtname, errid, errmess)
    type(etsf_io_low_error), intent(out)     :: error_data
    integer, intent(in)                      :: mode, type
    character(len = *), intent(in)           :: parent
    integer, intent(in), optional            :: tgtid, errid
    character(len = *), intent(in), optional :: tgtname, errmess

    ! Consistency checkings    
    if (mode < 1 .or. mode > nb_access_mode) then
      write(0, *) "   *** ETSF I/O Internal error ***"
      write(0, *) "   mode argument out of range: ", mode
      return
    end if
    if (type < 1 .or. type > nb_target_type) then
      write(0, *) "   *** ETSF I/O Internal error ***"
      write(0, *) "   type argument out of range: ", type
      return
    end if
    
    ! Storing informations
    error_data%parent = parent(1:min(80, len(parent)))
    error_data%access_mode_id = mode
    error_data%access_mode_str = etsf_io_low_error_mode(mode)
    error_data%target_type_id = type
    error_data%target_type_str = etsf_io_low_error_type(type)
    if (present(tgtid)) then
      error_data%target_id = tgtid
    else
      error_data%target_id = -1
    end if
    if (present(tgtname)) then
      error_data%target_name = tgtname(1:min(80, len(tgtname)))
    else
      error_data%target_name = ""
    end if
    if (present(errid)) then
      error_data%error_id = errid
    else
      error_data%error_id = -1
    end if
    if (present(errmess)) then
      error_data%error_message = errmess(1:min(256, len(errmess)))
    else
      error_data%error_message = ""
    end if
  end subroutine etsf_io_low_error_set
  !!***

  !!****m* etsf_io_low_error_group/etsf_io_low_error_to_str
  !! NAME
  !!  etsf_io_low_error_to_str
  !!
  !! FUNCTION
  !!  This method can be used to get a string from the given error.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * error_data <type(etsf_io_low_error)>=informations about an error.
  !!
  !! OUTPUT
  !!  * str = a string to write the error message to.
  !!
  !! SOURCE
  subroutine etsf_io_low_error_to_str(str, error_data)
    character(len = 1024), intent(out)   :: str
    type(etsf_io_low_error), intent(in) :: error_data
    
    character(len = 80) :: line_tgtname, line_tgtid, line_messid
    character(len = 256) :: line_mess
    
    if (trim(error_data%target_name) /= "") then
      write(line_tgtname, "(A,A,A)") "  Target (name)      : ", trim(error_data%target_name), char(10)
    else
      write(line_tgtname, "(A)") ""
    end if
    if (error_data%target_id >= 0) then
      write(line_tgtid, "(A,I0,A)") "  Target (id)        : ", error_data%target_id, char(10)
    else
      write(line_tgtid, "(A)") ""
    end if
    if (trim(error_data%error_message) /= "") then
      write(line_mess, "(A,A,A)") "  Error message      : ", trim(error_data%error_message), char(10)
    else
      write(line_mess, "(A)") ""
    end if
    if (error_data%error_id /= 0) then
      write(line_messid, "(A,I0,A)") "  Error id           : ", error_data%error_id, char(10)
    else
      write(line_messid, "(A)") ""
    end if

    ! Error handling
    write(str,*) " Calling subprogram : ", trim(error_data%parent), char(10), &
               & "  Action performed   : ", trim(error_data%access_mode_str), &
               & " ", trim(error_data%target_type_str), char(10), &
               & trim(line_tgtname), &
               & trim(line_tgtid), &
               & trim(line_mess), &
               & trim(line_messid)
  end subroutine etsf_io_low_error_to_str
  !!***

  !!****m* etsf_io_low_error_group/etsf_io_low_error_handle
  !! NAME
  !!  etsf_io_low_error_handle
  !!
  !! FUNCTION
  !!  This method can be used to output the informations contained in an error
  !!  structure. The output is done on standard output. Write your own method
  !!  if custom error handling is required.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * error_data <type(etsf_io_low_error)>=informations about an error.
  !!
  !! SOURCE
  subroutine etsf_io_low_error_handle(error_data)
    type(etsf_io_low_error), intent(in) :: error_data
      
    ! Error handling
    write(*,*) 
    write(*,*) "    ***"
    write(*,*) "    *** ETSF I/O ERROR"
    write(*,*) "    ***"
    write(*,*) "    *** Calling subprogram : ", trim(error_data%parent)
    write(*,*) "    *** Action performed   : ", trim(error_data%access_mode_str), &
             & " ", trim(error_data%target_type_str)
    if (trim(error_data%target_name) /= "") then
      write(*,*) "    *** Target (name)      : ", trim(error_data%target_name)
    end if
    if (error_data%target_id /= 0) then
      write(*,*) "    *** Target (id)        : ", error_data%target_id
    end if
    if (trim(error_data%error_message) /= "") then
      write(*,*) "    *** Error message      : ", trim(error_data%error_message)
    end if
    if (error_data%error_id /= 0) then
      write(*,*) "    *** Error id           : ", error_data%error_id
    end if
    write(*,*) "    ***"
    write(*,*) 
  end subroutine etsf_io_low_error_handle
  !!***

  !!****m* etsf_io_low_file_group/etsf_io_low_close
  !! NAME
  !!  etsf_io_low_close
  !!
  !! FUNCTION
  !!  This method is used to close an openend NetCDF file.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! SOURCE
  subroutine etsf_io_low_close(ncid, lstat, error_data)
    integer, intent(in)                            :: ncid
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_close"
    integer :: s
    
    lstat = .false.
    ! Close file
    s = nf90_close(ncid)
    if (s /= nf90_noerr) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_CLO, me, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_close
  !!***

  !!****m* etsf_io_low_file_group/etsf_io_low_set_write_mode
  !! NAME
  !!  etsf_io_low_set_write_mode
  !!
  !! FUNCTION
  !!  This method put the given NetCDF file handler in a data mode, by closing
  !!  a define mode. When a file is opened (see etsf_io_low_open_create() or
  !!  etsf_io_low_open_modify()), the NetCDF file handler is in a define mode.
  !!  This is convienient for all write accesses (create new dimensions, modifying
  !!  attribute values...) ; but when puting values into variables, the handler must
  !!  be in the data mode.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! SOURCE
  subroutine etsf_io_low_set_write_mode(ncid, lstat, error_data)
    integer, intent(in)                            :: ncid
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_set_write_mode"
    integer :: s
    
    lstat = .false.
    ! Change the mode.
    s = nf90_enddef(ncid)
    if (s /= nf90_noerr .and. s /= -38) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_END, me, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_set_write_mode
  !!***

  !!****m* etsf_io_low_file_group/etsf_io_low_set_define_mode
  !! NAME
  !!  etsf_io_low_set_define_mode
  !!
  !! FUNCTION
  !!  This method put the given NetCDF file handler in a define mode, by closing
  !!  a data mode. When opening a file (create or modify), this is the default mode.
  !!  Use etsf_io_low_set_write_mode() to switch then to data mode to write
  !!  variable values. But to set attributes, the file must be in define mode
  !!  again. This method is then usefull.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * ncid = a NetCDF handler, opened with write access.
  !!
  !! OUTPUT
  !!  * lstat = .true. if operation succeed.
  !!  * error_data <type(etsf_io_low_error)> = (optional) location to store error data.
  !!
  !! SOURCE
  subroutine etsf_io_low_set_define_mode(ncid, lstat, error_data)
    integer, intent(in)                            :: ncid
    logical, intent(out)                           :: lstat
    type(etsf_io_low_error), intent(out), optional :: error_data

    !Local
    character(len = *), parameter :: me = "etsf_io_low_set_define_mode"
    integer :: s
    
    lstat = .false.
    ! Change the mode.
    s = nf90_redef(ncid)
    if (s /= nf90_noerr .and. s /= -39) then
      if (present(error_data)) then
        call etsf_io_low_error_set(error_data, ERROR_MODE_IO, ERROR_TYPE_DEF, me, &
                     & errid = s, errmess = nf90_strerror(s))
      end if
      return
    end if
    lstat = .true.
  end subroutine etsf_io_low_set_define_mode
  !!***

  !!****f* etsf_io_low_level/pad
  !! NAME
  !!  pad
  !!
  !! FUNCTION
  !!  Little tool to format chains to constant length (256). This is usefull
  !!  when calling the etsf_io_low_def_var() routine which takes an array of
  !!  strings as argument. Since not all compilers like to construct static
  !!  arrays from strings of different lengths, this function can wrap all
  !!  strings.
  !!
  !! COPYRIGHT
  !!  Copyright (C) 2006
  !!  This file is distributed under the terms of the
  !!  GNU General Public License, see ~abinit/COPYING
  !!  or http://www.gnu.org/copyleft/gpl.txt .
  !!
  !! INPUTS
  !!  * string = the string to convert to character(len = 256).
  !!
  !! OUTPUT
  !!
  !! SOURCE
  function pad(string)
    character(len = *), intent(in) :: string
    character(len = 256)           :: pad
    
    write(pad, "(A)") string(1:min(256, len(string)))
  end function pad
  !!***

  include "read_routines.f90"
  include "read_routines_auto.f90"

  include "write_routines.f90"
  include "write_routines_auto.f90"

  function var_integer_associated(array)
    type(etsf_io_low_var_integer), intent(in) :: array
    logical                                   :: var_integer_associated
    
    var_integer_associated = (associated(array%data1D) .or. &
                            & associated(array%data2D) .or. &
                            & associated(array%data3D) .or. &
                            & associated(array%data4D) .or. &
                            & associated(array%data5D) .or. &
                            & associated(array%data6D) .or. &
                            & associated(array%data7D))
  end function var_integer_associated

  function var_double_associated(array)
    type(etsf_io_low_var_double), intent(in) :: array
    logical                                  :: var_double_associated
    
    var_double_associated = (associated(array%data1D) .or. &
                           & associated(array%data2D) .or. &
                           & associated(array%data3D) .or. &
                           & associated(array%data4D) .or. &
                           & associated(array%data5D) .or. &
                           & associated(array%data6D) .or. &
                           & associated(array%data7D))
  end function var_double_associated

end module etsf_io_low_level
