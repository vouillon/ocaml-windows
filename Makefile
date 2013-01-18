
include Makefile.config

SRC = ocaml-src

CORE_OTHER_LIBS = unix str num dynlink
OTHERLIBRARIES=win32unix str num win32graph dynlink bigarray systhreads

all: stamp-install

stamp-install: stamp-build
# Install the compiler
	cd $(SRC) && make install EXE= OTHERLIBRARIES= #-f Makefile.nt install EXE=
	set -e; cd $(SRC) && for i in $(OTHERLIBRARIES); do \
	  make -C otherlibs/$$i -f Makefile.nt install installopt; \
	done
# Put links to binaries in $W32_BINDIR
	for i in $(W32_BINDIR)/i686-w64-mingw32/*; do \
	  ln -sf $$i $(W32_BINDIR)/i686-w64-mingw32-`basename $$i`; \
	done
# Install the Windows ocamlrun binary
	mkdir -p $(W32_PREFIX)/bin
	cd $(SRC) && \
	cp byterun/ocamlrun.target $(W32_PREFIX)/bin/ocamlrun
# Add a link to camlp4 libraries
	rm -rf $(W32_PREFIX)/lib/ocaml/camlp4
	ln -sf $(shell $(W32_BINDIR)/ocamlfind query stdlib)/camlp4 \
	  $(W32_PREFIX)/lib/ocaml/camlp4
	touch stamp-install

stamp-build: stamp-runtime
# Restore the ocamlrun binary for the local machine
	cd $(SRC) && cp byterun/ocamlrun.local byterun/ocamlrun
# Compile the libraries for Windows
	cd $(SRC) && make -f Makefile.nt ocamlc ocamltools library opt-core otherlibraries otherlibrariesopt
	cd $(SRC) && make -C tools opt
# One need to use the standard makefile for ocamlmktop...
	rm $(SRC)/tools/ocamlmktop
	cd $(SRC) && make -C tools ocamlmktop
	touch stamp-build

stamp-runtime: stamp-prepare
# Recompile the runtime for Windows
	cd $(SRC) && make -C byterun -f Makefile.nt all
# Save the Windows ocamlrun binary
	cd $(SRC) && cp byterun/ocamlrun.exe byterun/ocamlrun.target
	touch stamp-runtime

stamp-prepare: stamp-core
	cd $(SRC)/config && cp s-nt.h s.h 
	cd $(SRC)/config && cp m-nt.h m.h 
	cd $(SRC)/config && cp Makefile.mingw Makefile
# Apply patches
	set -e; for p in patches/*.txt; do \
	(cd $(SRC) && \
	 sed -e 's%W32_BINDIR%$(W32_BINDIR)%g' \
	     -e 's%W32_PREFIX%$(W32_PREFIX)%g' ../$$p | \
	 patch -p 0); \
	done
# Save the ocamlrun binary for the local machine
	cd $(SRC) && cp byterun/ocamlrun byterun/ocamlrun.local
# Clean-up runtime and libraries
	cd $(SRC) && make -C byterun clean
	cd $(SRC) && make -C stdlib clean
	set -e; cd $(SRC) && \
	for i in $(CORE_OTHER_LIBS); do \
	  make -C otherlibs/$$i clean; \
	done
	touch stamp-prepare

stamp-core: stamp-configure
# Build the bytecode compiler and other core tools
	cd $(SRC) && make OTHERLIBRARIES="$(CORE_OTHER_LIBS)" world
	touch stamp-core

stamp-configure: stamp-copy
# Configuration...
	cd $(SRC) && \
	./configure -prefix $(W32_PREFIX) \
		-bindir $(W32_BINDIR)/i686-w64-mingw32 \
	        -mandir $(shell pwd)/no-man \
	        -host i686-w64-mingw32 \
		-cc "gcc -m32" -as "as --32" -aspp "gcc -m32 -c" \
	 	-no-pthread -no-camlp4
	touch stamp-configure

stamp-copy:
# Copy the source code
	@if ! [ -d $(OCAML_SRC)/byterun ]; then \
	  echo Error: OCaml sources not found. Check OCAML_SRC variable.; \
	  exit 1; \
	fi
	cp -a $(OCAML_SRC) $(SRC)
	touch stamp-copy

clean:
	rm -rf $(SRC) stamp-* no-man
