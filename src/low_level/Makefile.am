lib_LTLIBRARIES = libetsf_io_low_level.la

EXTRA_DIST = public_variables.f90 \
	read_routines_auto.f90 \
	read_routines.f90 \
	write_routines.f90 \
	write_routines_auto.f90

if CAPITALIZE
module_DATA = ETSF_IO_LOW_LEVEL.@MODULE_EXT@
else
module_DATA = etsf_io_low_level.@MODULE_EXT@
endif

AM_FCFLAGS = @NETCDF_INCLUDES@ -I$(srcdir)

if HAVE_PARALLEL_IO
NETCDF_WRAPPERS = netcdf4_wrappers.f90
else
NETCDF_WRAPPERS = netcdf3_wrappers.f90
endif

libetsf_io_low_level_la_SOURCES = etsf_io_low_level.f90 \
	$(NETCDF_WRAPPERS)

CLEANFILES = $(module_DATA)

#dependencies
$(libetsf_io_low_level_la_OBJECTS): \
	public_variables.f90 \
	read_routines.f90 \
	read_routines_auto.f90 \
	write_routines.f90 \
	write_routines_auto.f90

etsf_io_low_level.@MODULE_EXT@ ETSF_IO_LOW_LEVEL.@MODULE_EXT@: libetsf_io_low_level.la
