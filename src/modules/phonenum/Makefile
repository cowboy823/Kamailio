#
# WARNING: do not run this directly, it should be run by the main Makefile

include ../../Makefile.defs
auto_gen=
NAME=phonenum.so

CXX?=g++
LD?=g++
CSTDVER?="c++17"

LIBS+=-L$(LOCALBASE)/lib cphonenumber.o -lphonenumber -lgeocoding
DEFS+=-I$(LOCALBASE)/include

CXXFLAGS=$(CFLAGS:-Wno-deprecated option=)
CXXFLAGS+=-Wno-write-strings -Wno-deprecated -Wno-unused-function -Wno-sign-compare -Wno-strict-aliasing

include ../../Makefile.modules

cphonenumber.o: cphonenumber.cpp cphonenumber.h
	@echo "Compiling $<"
	$(CXX) -std=$(CSTDVER) $(CXXFLAGS) $(CFLAGS) $(C_DEFS) $(DEFS) -c $< -o $@

phonenum.so: cphonenumber.o

modclean:
	-@rm -f cphonenumber.o

clean clean-modules: modclean

proper realclean distclean maintainer-clean: modclean
