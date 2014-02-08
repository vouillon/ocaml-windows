SRC = ocaml-src

CORE_OTHER_LIBS = unix str num dynlink
OTHERLIBRARIES = win32unix str num win32graph dynlink bigarray systhreads
STDLIB = $(shell $(WIN_BINDIR)/ocamlc -config | \
               sed -n 's/standard_library: \(.*\)/\1/p')

INSTALLED_BINS = ocaml ocamlbuild ocamlbuild.byte ocamlc ocamlcp	\
ocamldebug ocamldep ocamldoc ocamllex ocamlmklib ocamlmktop		\
ocamlobjinfo ocamlopt ocamloptp ocamlprof ocamlrun ocamlyacc

INSTALLED_MODULES = Arg Array ArrayLabels Bigarray Bigarray.Array1	\
Bigarray.Array2 Bigarray.Array3 Bigarray.Genarray Buffer Callback	\
CamlinternalLazy CamlinternalMod CamlinternalOO Complex Digest		\
Filename Format Gc Genlex Hashtbl Hashtbl.HashedType Hashtbl.Make	\
Hashtbl.MakeSeeded Hashtbl.S Hashtbl.SeededHashedType Hashtbl.SeededS	\
Int32 Int64 Lexing List ListLabels Map Map.Make Map.OrderedType Map.S	\
Marshal MoreLabels MoreLabels.Hashtbl MoreLabels.Hashtbl.HashedType	\
MoreLabels.Hashtbl.Make MoreLabels.Hashtbl.MakeSeeded			\
MoreLabels.Hashtbl.S MoreLabels.Hashtbl.SeededHashedType		\
MoreLabels.Hashtbl.SeededS MoreLabels.Map MoreLabels.Map.Make		\
MoreLabels.Map.OrderedType MoreLabels.Map.S MoreLabels.Set		\
MoreLabels.Set.Make MoreLabels.Set.OrderedType MoreLabels.Set.S		\
Nativeint Num Obj Oo Parsing Pervasives Pervasives.LargeFile Printexc	\
Printf Queue Random Random.State Scanf Scanf.Scanning Set.Make		\
Set.OrderedType Set.S Sort Stack StdLabels StdLabels.Array		\
StdLabels.List StdLabels.String Str Stream StringLabels Sys Unix	\
Unix.LargeFile Weak Weak.Make Weak.S

all: stamp-install

stamp-install: stamp-build
# Install the compiler
	cd $(SRC) && make install EXE= OTHERLIBRARIES= #-f Makefile.nt install EXE=
	set -e; cd $(SRC) && for i in $(OTHERLIBRARIES); do \
	  make -C otherlibs/$$i -f Makefile.nt install installopt; \
	done
# Put links to binaries in $WIN_BINDIR
	for i in $(INSTALLED_BINS); do \
	  ln -sf $(WIN_PREFIX)/bin/$$i $(WIN_BINDIR)/$(MINGW_PREF)-$$i; \
	done
# Install the Windows ocamlrun binary
	mkdir -p $(WIN_PREFIX)/bin
	cd $(SRC) && \
	cp byterun/ocamlrun.target $(WIN_PREFIX)/bin/ocamlrun.exe
# Add a link to camlp4 libraries
	rm -rf $(WIN_PREFIX)/lib/ocaml/camlp4
	ln -sf $(STDLIB)/camlp4 $(WIN_PREFIX)/lib/ocaml/camlp4
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
# Apply patches
	set -e; for p in patches/*.txt; do \
	(cd $(SRC) && \
	 sed -e 's%WIN_PREFIX%$(WIN_PREFIX)%g' ../$$p | \
	 patch -p 0); \
	done
# Replace files
	cd $(SRC)/config && cp s-nt.h s.h
	cd $(SRC)/config && cp m-nt.h m.h
	cd $(SRC)/config && cp Makefile.mingw Makefile.mingw32
	cd $(SRC)/config && cp Makefile.mingw$(WORD_SIZE) Makefile
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
	cd $(SRC) && \
	make OTHERLIBRARIES="$(CORE_OTHER_LIBS)" BNG_ASM_LEVEL=0 world
	touch stamp-core

stamp-configure: stamp-copy
# Configuration...
	cd $(SRC) && \
	./configure -prefix $(WIN_PREFIX) \
		-bindir $(WIN_PREFIX)/bin \
	        -mandir $(shell pwd)/no-man \
		-cc "gcc -m$(WORD_SIZE)" -as "gcc -m$(WORD_SIZE)" \
		-aspp "gcc -m$(WORD_SIZE) -c" -no-pthread -no-camlp4
	touch stamp-configure

stamp-copy:
# Copy the source code
	@if ! [ -d $(OCAML_SRC)/byterun ]; then \
	  echo Error: OCaml sources not found. Check OCAML_SRC variable.; \
	  exit 1; \
	fi
	@if ! [ -f $(WIN_BINDIR)/ocamlc ]; then \
	  echo Error: $(WIN_BINDIR)/ocamlc not found. \
	    Check WIN_BINDIR variable.; \
	  exit 1; \
	fi
	cp -a $(OCAML_SRC) $(SRC)
	touch stamp-copy

uninstall:
	for b in $(INSTALLED_BINS); do					\
	  rm -f "$(PREFIX)/bin/$(MINGW_PREF)-$$b";			\
	  rm -f "$(PREFIX)/$(MINGW_PREF)/bin/$$b";			\
	  rm -f "$(PREFIX)/$(MINGW_PREF)/man/man1/$$b.1";		\
	done;								\
	for m in $(INSTALLED_MODULES); do				\
	  rm -f "$(PREFIX)/$(MINGW_PREF)/man/man3/$$m.3o";		\
	done;								\
	rm -f "$(PREFIX)/$(MINGW_PREF)/man/man1/ocamlc.opt.1";		\
	rm -f "$(PREFIX)/$(MINGW_PREF)/man/man1/ocamlopt.opt.1";	\
	rm -rf "$(PREFIX)/$(MINGW_PREF)/lib/ocaml";			\
	rm -f "$(PREFIX)/$(MINGW_PREF)/bin/ocamlrun.exe";		\
	rm -f "$(PREFIX)/$(MINGW_PREF)/bin/ocamlrun";

clean:
	rm -rf $(SRC) stamp-* no-man
