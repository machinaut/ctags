#*****************************************************************************
#	$Id$
#
#	Copyright (c) 1996-2001, Darren Hiebert
#
#   Development makefile for Exuberant Ctags, used to build releases.
#
#   Requires GNU make.
#*****************************************************************************

OBJEXT = o

include source.mak

DSOURCES	=	$(SOURCES) debug.c

DOS_VER_FILES=	ctags.h ctags.1 ctags.lsm NEWS

VERSION_FILES=	$(DOS_VER_FILES) configure.in ctags.spec

LIB_FILES	=	readtags.c readtags.h

COMMON_FILES =	COPYING EXTENDING.html FAQ INSTALL.oth NEWS QUOTES README \
				mk_bc3.mak mk_bc5.mak mk_djg.mak mk_manx.mak mk_ming.mak \
				mk_mpw.mak mk_mvc.mak mk_os2.mak mk_qdos.mak mk_sas.mak \
				source.mak $(DSOURCES) $(HEADERS) $(LIB_FILES)

UNIX_FILES	=	$(COMMON_FILES) \
				INSTALL acconfig.h configure.in Makefile.in maintainer.mak \
				descrip.mms mkinstalldirs magic.diff \
				argproc.c mac.c mac.h qdos.c ctags.1 ctags.lsm

DOS_FILES	=	$(COMMON_FILES)

CVS_FILES	=	$(UNIX_FILES)

WARNINGS	=	-Wall -W -Wpointer-arith -Wcast-align -Wwrite-strings \
				-Wmissing-prototypes -Wmissing-declarations \
				-Wnested-externs -Wcast-qual -Wshadow -pedantic \
				-Wstrict-prototypes \
				# -Wtraditional -Wconversion -Werror

ERRFILE	= errors
REDIR	= 2>&1 | tee $(ERRFILE)

RPM_ROOT= $(HOME)/Develop
CTAGS_DOSDIR = win32
WEB_ARCHIVE_DIR = $(HOME)/public_html/archives
WEB_CTAGS_DIR = $(HOME)/public_html/ctags
DEP_DIR	= .deps

CC		= gcc
INCLUDE	= -I.
DEFS	= -DHAVE_CONFIG_H
COMP_FLAGS = $(INCLUDE) $(DEFS) $(CFLAGS)
OPT		= -O3
DCFLAGS	= $(COMP_FLAGS) -DDEBUG -DINTERNAL_SORT -DREADTAGS_MAIN
LD		= gcc
LDFLAGS	= 

AUTO_GEN	= configure config.h.in
CONFIG_GEN	= config.cache config.log config.status config.run config.h Makefile
PROF_GEN	= gmon.out
COV_GEN		= *.da *.gcov

#
# Targets
#
ifeq ($(findstring clean,$(MAKECMDGOALS)),)
ifneq ($(MAKECMDGOALS),setup)
ifeq ($(wildcard config.h),)
ctags dctags ctags.prof ctags.cov:
	$(MAKE) config.h
	$(MAKE) $(MAKECMDGOALS)
else
all: dctags tags syntax.vim

-include $(DSOURCES:%.c=$(DEP_DIR)/%.d)

#
# Executable targets
#
ctags: $(SOURCES:.c=.o)
	@ echo "-- Linking $@"
	@ $(LD) -o $@ $(LDFLAGS) $^

dctags: $(SOURCES:.c=.od) debug.od
	@ echo "-- Building $@"
	$(LD) -o $@ $(LDFLAGS) $^ -lefence

mctags: $(SOURCES:.c=.om) debug.om safe_malloc.om
	@ echo "-- Building $@"
	$(LD) -o $@ $(LDFLAGS) $^

ctags.prof: $(SOURCES) $(HEADERS) Makefile
	$(CC) -pg $(COMP_FLAGS) $(WARNINGS) $(SOURCES) -o $@

ctags.cov: $(SOURCES) $(HEADERS) Makefile
	$(CC) -fprofile-arcs -ftest-coverage $(COMP_FLAGS) $(WARNINGS) $(SOURCES) -o $@

gcov: $(SOURCES:.c=.c.gcov)

readtags: readtags.[ch]
	$(CC) -g $(COMP_FLAGS) -DREADTAGS_MAIN -o $@ readtags.c

readtags.o: readtags.[ch]
	$(CC) $(COMP_FLAGS) -c readtags.c

endif
endif
endif

ctags32.exe: $(SOURCES) $(HEADERS)
	gcc-dos -DMSDOS -O2 -Wall -s -o $@ $(SOURCES)

#
# Support targets
#
FORCE:

config.h.in: acconfig.h configure.in
	autoheader
	@ touch $@

configure: configure.in
	autoconf

config.status: configure
	./config.status --recheck

config.h: config.h.in config.status
	./config.status
	touch $@

depclean:
	rm -f $(DEP_DIR)/*.d

profclean:
	rm -f $(PROF_GEN)

gcovclean:
	rm -f $(COV_GEN)

clean: depclean profclean gcovclean
	rm -f *.[ois] *.o[dm] ctags dctags mctags ctags*.exe readtags \
		ctags.html ctags.prof ctags.cov *.bb *.bbg tags TAGS syntax.vim \
		$(ERRFILE) $(TEST_ARTIFACTS)

distclean: clean
	rm -f $(CONFIG_GEN)

maintainer-clean maintclean: distclean
	rm -f $(AUTO_GEN)

ctags.man: ctags.1
	groff -Tascii -mandoc $< | sed 's/.//g' > $@

ctags.html: ctags.1
	man2html $< > $@

tags: $(DSOURCES) $(HEADERS) $(LIB_FILES) Makefile *.mak
	@ echo "-- Building tag file"
	@ ctags *

#
# Create a Vim syntax file for all typedefs
#
syntax: syntax.vim
syntax.vim: $(DSOURCES) $(HEADERS) $(LIB_FILES)
	@ echo "-- Generating syntax file"
	@ ctags --c-types=cgstu --file-scope -o- $^ |\
		awk '{print $$1}' | sort -u | fmt |\
		awk '{printf("syntax keyword Typedef\t%s\n", $$0)}' > $@

#
# Testing
#
CTAGS_TEST = ctags
CTAGS_REF = ctags.ref
TEST_OPTIONS = -nu --c-types=+px

DIFF_OPTIONS = -I '^!_TAG'
DIFF = if diff $(DIFF_OPTIONS) tags.ref tags.test > $(DIFF_FILE); then \
		rm -f tags.ref tags.test $(DIFF_FILE) ; \
		echo "Passed" ; \
	  else \
		echo "FAILED: differences left in $(DIFF_FILE)" ; \
	  fi

.PHONY: test test.include test.fields test.eiffel test.linux

test: test.include test.fields test.linedir test.eiffel #test.linux

test.%: DIFF_FILE = $@.diff

REF_INCLUDE_OPTIONS = $(TEST_OPTIONS) --format=1
TEST_INCLUDE_OPTIONS = $(REF_INCLUDE_OPTIONS) --format=1
test.include: $(CTAGS_TEST) $(CTAGS_REF)
	@ echo -n "Testing tag inclusion..."
	@ $(CTAGS_REF) -R $(REF_INCLUDE_OPTIONS) -o tags.ref Test
	@ $(CTAGS_TEST) -R $(TEST_INCLUDE_OPTIONS) -o tags.test Test
	@- $(DIFF)

REF_FIELD_OPTIONS = $(TEST_OPTIONS)
TEST_FIELD_OPTIONS = $(TEST_OPTIONS)
test.fields: $(CTAGS_TEST) $(CTAGS_REF)
	@ echo -n "Testing extension fields..."
	@ $(CTAGS_REF) -R $(REF_FIELD_OPTIONS) -o tags.ref Test
	@ $(CTAGS_TEST) -R $(TEST_FIELD_OPTIONS) -o tags.test Test
	@- $(DIFF)

REF_LINEDIR_OPTIONS = $(TEST_OPTIONS) --line-directives
TEST_LINEDIR_OPTIONS = $(TEST_OPTIONS) --line-directives
test.linedir: $(CTAGS_TEST) $(CTAGS_REF)
	@ echo -n "Testing line directives..."
	@ $(CTAGS_REF) $(REF_LINEDIR_OPTIONS) -o tags.ref Test/line_directives.c
	@ $(CTAGS_TEST) $(TEST_LINEDIR_OPTIONS) -o tags.test Test/line_directives.c
	@- $(DIFF)

REF_EIFFEL_OPTIONS = $(TEST_OPTIONS) --format=1
TEST_EIFFEL_OPTIONS = $(TEST_OPTIONS) --format=1
EIFFEL_DIRECTORY = /usr/local/Eiffel4
test.eiffel: $(CTAGS_TEST) $(CTAGS_REF)
	@ echo -n "Testing Eiffel tag inclusion..."
	@ $(CTAGS_REF) -R $(REF_EIFFEL_OPTIONS) -o tags.ref $(EIFFEL_DIRECTORY)
	@ $(CTAGS_TEST) -R $(TEST_EIFFEL_OPTIONS) -o tags.test $(EIFFEL_DIRECTORY)
	@- $(DIFF)

REF_LINUX_OPTIONS = $(TEST_OPTIONS) --fields=k
TEST_LINUX_OPTIONS = $(TEST_OPTIONS) --fields=k
LINUX_DIRECTORY = /usr/src/linux-2.4
test.linux: $(CTAGS_TEST) $(CTAGS_REF)
	@ echo -n "Testing Linux tag inclusion..."
	@ $(CTAGS_REF) -R $(REF_LINUX_OPTIONS) -o tags.ref $(LINUX_DIRECTORY)
	@ $(CTAGS_TEST) -R $(TEST_LINUX_OPTIONS) -o tags.test $(LINUX_DIRECTORY)
	@- $(DIFF)

TEST_ARTIFACTS = test.*.diff tags.ref tags.test

#
# CVS management
#
status:
	@ cvs -n -q update

cvs-tag-%:
	@ echo "---------- Tagging release `echo $* | sed 's/\./_/g'`"
	@ cvs tag -c $(CVS_TAG_OPTIONS) Ctags-`echo $* | sed 's/\./_/g'`

cvs-files:
	@ls -1 $(CVS_FILES)

#
# Release management
#
ctags-%.tar.gz: $(UNIX_FILES) $(VERSION_FILES)
	@ echo "---------- Building tar ball"
	if [ -d ctags-$* ] ;then rm -fr ctags-$** ;fi
	mkdir ctags-$*
	cp -p $(UNIX_FILES) ctags-$*/
	for file in $(VERSION_FILES) ;do \
		rm -f ctags-$*/$${file} ;\
		sed -e "s/@@VERSION@@/$*/" \
		    -e "s/@@LSMDATE@@/`date +'%d%b%y' | tr 'a-z' 'A-Z'`/" \
			$${file} > ctags-$*/$${file} ;\
	done
	chmod 644 ctags-$*/*
	chmod 755 ctags-$*/mkinstalldirs
	(cd ctags-$*; autoheader; chmod 644 config.h.in)
	(cd ctags-$*; autoconf; chmod 755 configure)
	tar -zcf $@ ctags-$*

ctags-%.tar.Z: ctags-%.tar.gz
	tar -Zcf $@ ctags-$*

$(CTAGS_DOSDIR)/ctags%: FORCE
	if [ -d $(CTAGS_DOSDIR)/ctags$* ] ;\
		then rm -fr $(CTAGS_DOSDIR)/ctags$*/* ;\
		else mkdir -p $(CTAGS_DOSDIR)/ctags$* ;\
	fi

dos1-%: $(DOS_FILES)
	for file in $^ ;do \
		unix2dos $${file} $(CTAGS_DOSDIR)/ctags$*/$${file} ;\
	done
	cd $(CTAGS_DOSDIR); mv makefile makefile.bak; \
		sed -e 's/^\(VERSION = \).*$$/\1$*
/' makefile.bak > makefile

dos2-%: $(DOS_VER_FILES) ctags.html
	for file in $^ ;do \
		rm -f $(CTAGS_DOSDIR)/ctags`echo $*|sed 's/\.//g'`/$${file} ;\
		sed -e "s/@@VERSION@@/$*/" \
		    -e "s/@@LSMDATE@@/`date +'%d%b%y' | tr 'a-z' 'A-Z'`/" $${file} |\
			unix2dos > $(CTAGS_DOSDIR)/ctags`echo $*|sed 's/\.//g'`/$${file} ;\
	done

dos-%:
	@ echo "---------- Building MSDOS release directory"
	$(MAKE) $(CTAGS_DOSDIR)/ctags`echo $*|sed 's/\.//g'` \
			dos1-`echo $*|sed 's/\.//g'` dos2-$*

rpm-%: ctags-%.tar.gz ctags.spec
	@ echo "---------- Building RPM"
	cp -p ctags-$*.tar.gz $(RPM_ROOT)/SOURCES/
	sed -e "s/@@VERSION@@/$*/" ctags.spec > $(RPM_ROOT)/SPECS/ctags-$*.spec
	(cd $(RPM_ROOT)/SPECS; rpm --sign -ba ctags-$*.spec)
	rm -fr $(RPM_ROOT)/BUILD/ctags-$*

ctags32-%: ctags-%.tar.gz
	@ echo "---------- Building DPMS binary for MSDOS"
	(cd ctags-$*; $(MAKE) -f ../Makefile ctags32.exe; mv ctags32.exe ..)
	rm -f $(CTAGS_DOSDIR)/ctags32.exe
	mcopy ctags32.exe $(CTAGS_DOSDIR)

#
# Prevent make from deleting these automatically
#
.PRECIOUS: ctags-%.tar.gz ctags-%.tar.Z

cleanrelease-%:
	rm -f ctags-$*.tar.gz
	rm -fr ctags-$*
	rm -fr $(CTAGS_DOSDIR)/ctags`echo $*|sed 's/\.//g'`
	rm -f $(RPM_ROOT)/SOURCES/ctags-$*.tar.gz
	rm -f $(RPM_ROOT)/RPMS/i386/ctags-$*-1.i386.rpm
	rm -f $(RPM_ROOT)/SRPMS/ctags-$*-1.src.rpm
	rm -f $(RPM_ROOT)/SPECS/ctags-$*.spec

release-%: cvs-tag-% ctags-%.tar.gz ctags-%.tar.Z dos-% rpm-% ctags.html
	@ echo "---------- Copying files to web archive"
	cp -p ctags-$*.tar.* $(WEB_ARCHIVE_DIR)
	cp -p EXTENDING.html $(WEB_CTAGS_DIR)
	mv -f ctags.html $(WEB_CTAGS_DIR)
	cp -p $(RPM_ROOT)/RPMS/i386/ctags-$*-1.i386.rpm $(WEB_ARCHIVE_DIR)
	cp -p $(RPM_ROOT)/SRPMS/ctags-$*-1.src.rpm $(WEB_ARCHIVE_DIR)
	cp -p ctags-$*/ctags.lsm $(WEB_ARCHIVE_DIR)/ctags-$*.lsm
	chmod o+r $(WEB_ARCHIVE_DIR)/*
	@ echo "---------- Release $* completed"

rerelease-%: CVS_TAG_OPTIONS := -F

rerelease-%: release-%

#
# Dependency file generation
#
$(DEP_DIR)/%.d: %.c maintainer.mak
	@ if [ ! -d $(DEP_DIR) ] ;then mkdir -p $(DEP_DIR) ;fi
	@ $(CC) -M $(DCFLAGS) $< | sed 's/\($*\.o\)\([ :]\)/\1 $*.od $*.om $(@F)\2/g' > $@


%.inc: %.c Makefile
	-@ $(CC) -MM $(DCFLAGS) $<

#
# Compilation rules
#
%.o: %.c
	@ echo "-- Compiling $<"
	@ $(CC) $(COMP_FLAGS) -DEXTERNAL_SORT $(OPT) $(WARNINGS) -Wuninitialized -c $<  $(REDIR)

%.od: %.c
	@ echo "-- Compiling (debug) $<"
	@ $(CC) -g $(DCFLAGS) $(WARNINGS) -o $*.od -c $<  $(REDIR)

%.om: %.c
	@ echo "-- Compiling (safe alloc) $<"
	@ $(CC) -g -DTRAP_MEMORY_CALLS $(DCFLAGS) $(WARNINGS) -o $*.om -c $<  $(REDIR)

%.i: %.c FORCE
	$(CC) $(DCFLAGS) $(WARNINGS) -Wuninitialized -O -E $< > $@ $(REDIR)

%.ic: %.c FORCE
	$(CC) $(DCFLAGS) $(WARNINGS) -Wuninitialized -O -E $< | noblanks > $@ $(REDIR)

%.s: %.c FORCE
	$(CC) $(DCFLAGS) $(WARNINGS) -S $< > $@ $(REDIR)

%.err: %.c
	@ $(CC) $(DCFLAGS) $(WARNINGS) -Wuninitialized -O -c $<
	@ rm $*.o

%.c.gcov: %.da
	@ gcov $*.c

%.sproto: %.c
	@ genproto -s -m __ARGS $<

%.proto: %.c
	@ genproto -e -m __ARGS $<

# vi:ts=4 sw=4
