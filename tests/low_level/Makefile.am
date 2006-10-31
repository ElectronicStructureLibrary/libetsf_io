vpath %.o $(top_builddir)/src/low_level

test_dependencies = \
	check_att_t01.nc \
	check_var_t01.nc \
	open_read_t01.nc \
	open_read_t02.nc \
	open_read_t03.nc \
	open_read_t04.nc \
	read_dim_t01.nc \
	read_var_t01.nc

EXTRA_DIST = \
	check_att_t01.cdl \
	open_read_t01.cdl \
	open_read_t02.cdl \
	open_read_t03.cdl \
	open_read_t04.cdl \
	read_var_t01.cdl \
	$(test_dependencies)

AM_FCFLAGS = -I$(top_builddir)/src/low_level

noinst_PROGRAMS = tests_read \
	tests_write

tests_read_SOURCES = tests_read.f90

tests_read_LDFLAGS = -L$(top_builddir)/src/low_level

tests_read_LDADD = -letsf_io_low_level


tests_write_SOURCES = tests_write.f90

tests_write_LDFLAGS = -L$(top_builddir)/src/low_level

tests_write_LDADD = -letsf_io_low_level

#dependencies
tests_read.o: tests_read.f90 \
	etsf_io_low_level.o

tests_write.o: tests_write.f90 \
	etsf_io_low_level.o

#additional rules
run-tests: run-tests-read run-tests-write

run-tests-read: $(test_dependencies) tests_read
	./tests_read $(srcdir)

run-tests-write: $(test_dependencies) tests_write
	\rm -f *_t*.nc
	./tests_write $(srcdir)