#
#

COREPATH=../../src/
include $(COREPATH)/Makefile.defs
include $(COREPATH)/Makefile.targets

auto_gen=
RELEASE=1.5
UTIL_SRC_NAME=kamcmd
# Pass CUSTOM_NAME to overwrite the kamcmd/sercmd bin name
ifeq ($(CUSTOM_NAME),)
ifeq ($(FLAVOUR),ser)
	NAME=sercmd
else
	NAME=kamcmd
endif
else
	NAME=$(CUSTOM_NAME)
endif

readline_localpath=$(LOCALBASE)/include/readline/readline.h
readline_locations= /usr/include/readline/readline.h \
					$(readline_localpath)

ifeq ($(CROSS_COMPILE),)
	BUILDER = $(shell which pkg-config)
ifneq ($(BUILDER),)
	PKGREADLINE = $(shell $(BUILDER) --exists readline > /dev/null 2>&1 ; echo $$? )
ifneq ($(PKGREADLINE),0)
	BUILDER =
endif
endif
endif


use_readline ?=
ifneq (,$(MAKECMDGOALS))
ifeq (,$(filter-out $(nodep_targets),$(MAKECMDGOALS)))
#set it to empty, we don't need to detect/use it for clean, doc a.s.o
override use_readline:=
quiet=1
endif
endif #ifneq (,$(MAKECMDGOALS))


# erase common DEFS (not needed)
C_DEFS:=
DEFS:= -DNAME='"$(NAME)"' -DSRNAME='"$(MAIN_NAME)"' -DVERSION='"$(RELEASE)"' -D__OS_$(OS) \
		-DRUN_DIR='"$(run_target)"' \
		$(filter -D%HAVE -DARCH% -DOS% -D__CPU% -D__OS%, $(DEFS))

# use proper libs (we can't rely on LIBS value since we might be called
# from a module Makefile)
#LIBS:=$(filter-out -lfl  -ldl -lpthread -lssl -lcrypto, $(LIBS))

ifeq ($(OS), linux)
	LIBS:= -lresolv
endif
ifeq ($(OS), solaris)
	LIBS:= -lresolv -L$(LOCALBASE)/lib -lxnet -lnsl
endif
ifeq ($(OS), freebsd)
	LIBS:=
endif
ifeq  ($(OS), dragonfly)
	LIBS:= -L$(LOCALBASE)/lib
endif
ifeq ($(OS), openbsd)
	LIBS:=
endif
ifeq ($(OS), netbsd)
	LIBS:=
endif
ifeq ($(OS), darwin)
readline_locations= /opt/local/include/readline/readline.h \
					/usr/include/readline/readline.h \
					$(readline_localpath)
	LIBS:= -lresolv
endif
ifneq (,$(findstring cygwin, $(OS)))
	LIBS:= -lresolv
endif

# detect libreadline
ifneq ($(BUILDER),)
	DEFS += $(shell $(BUILDER) --cflags readline)
	DEFS+=-DUSE_READLINE
	LIBS += $(shell $(BUILDER) --libs readline)
	use_readline := 1
else
ifeq ($(use_readline),)
readline_path := $(shell  \
						for r in $(readline_locations) ""; do \
							if [ -r "$$r" ] ; then echo $$r; exit; fi;  \
						done;\
					)
ifneq ($(readline_path),)
use_readline := 1
endif
endif

ifeq ($(use_readline),1)

ifneq (,$(findstring opt, $(readline_path)))
	DEFS+=-DUSE_READLINE -I /opt/local/include
	LIBS+=-L/opt/local/lib -lreadline -lncurses
else

ifeq ($(readline_path),$(readline_localpath))
	DEFS+=-I$(LOCALBASE)/include
	LIBS+=-L$(LOCALBASE)/lib
endif

	DEFS+=-DUSE_READLINE
	LIBS+=-lreadline -lncurses
endif

endif  # ifeq ($(use_readline),1)

endif  # ifneq ($(BUILDER),)


include $(COREPATH)/Makefile.utils

ifeq (,$(quiet))
ifeq ($(use_readline),1)
ifneq ($(BUILDER),)
$(info readline detected via pkg-config)
else
$(info readline detected ($(readline_path)) )
endif
$(info command completion enabled)
else
$(info "no readline include files detected, disabling readline support")
$(info "command completion disabled" )
$(info "to force readline support try 'make use_readline=1'")
endif
endif # ifeq (,$(quiet))

$(NAME).o:

.PHONY: msg
msg:
	@if [ "$(use_readline)" = "1" ]; then \
		if [ "$(BUILDER)" = "" ]; then \
			echo; echo "readline detected ($(readline_path)):"; \
		else \
			echo; echo "readline detected via pkg-config"; \
		fi; \
		echo "command completion enabled"; echo ; \
	else \
		echo ; \
		echo "no readline include files detected, disabling readline support";\
		echo "command completion disabled"; \
		echo "(to force readline support try 'make use_readline=1')";\
		echo ; \
	fi

modules:
