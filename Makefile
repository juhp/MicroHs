# installation prefix
PREFIX=/usr/local
# Unix-like system, 64 bit words
CONF=unix-64
#
CCWARNS= -Wall
CCOPTS= -O3
CCLIBS= -lm
CCEVAL= $(CC) $(CCWARNS) $(CCOPTS) -Isrc/runtime src/runtime/eval-$(CONF).c $(CCLIBS)
#
GHC= ghc
GHCINCS= -ighc -isrc -ipaths
GHCWARNS= -Wall -Wno-unrecognised-warning-flags -Wno-x-partial -Wno-deprecations
GHCOPTS= -O
GHCEXTS= -DNOTCABAL -XScopedTypeVariables -XPatternGuards -XTupleSections -XTypeSynonymInstances -XFlexibleInstances -XOverloadedRecordDot -XDisambiguateRecordFields -XOverloadedStrings
# -XOverloadedRecordUpdate
GHCPKGS= -package mtl -package pretty -package haskeline -package process -package time -package ghc-prim -package containers -package deepseq -package directory
GHCTOOL= # -F -pgmF Tools/convertX.sh
GHCOUTDIR= ghc-out
GHCOUT= -outputdir $(GHCOUTDIR)
GHCPROF= # -prof -fprof-late #-prof -fprof-auto
GHCFLAGS= $(GHCEXTS) $(GHCINCS) $(GHCWARNS) $(GHCOPTS) $(GHCTOOL) $(GHCPKGS) $(GHCOUT) $(GHCPROF)
#
MHSINCNP= -i -imhs -isrc -ilib -ilib/simple-readline
MHSINC=$(MHSINCNP) -ipaths 
#
.PHONY:	clean bootstrap install ghcgen newmhs cachelib timecompile exampletest cachetest runtest runtestmhs everytest everytestmhs nfibtest info

all:	bin/mhs bin/cpphs

targets.conf:
	echo [default]           > targets.conf
	echo cc = \"$(CC)\"     >> targets.conf
	echo conf = \"$(CONF)\" >> targets.conf

newmhs:	ghcgen targets.conf
	$(CCEVAL) generated/mhs.c -o bin/mhs
	$(CC) $(CCWARNS) -g -Isrc/runtime src/runtime/eval-$(CONF).c $(CCLIBS) generated/mhs.c -o bin/mhsgdb

sanitizemhs:	ghcgen targets.conf
	$(CCEVAL) -fsanitize=undefined -fsanitize=address -fsanitize=pointer-compare -fsanitize=pointer-subtract generated/mhs.c -o bin/mhssane

# Compile mhs from distribution, with C compiler
bin/mhs:	src/runtime/*.c src/runtime/*.h targets.conf #generated/mhs.c
	@mkdir -p bin
	$(CCEVAL) generated/mhs.c -o bin/mhs

# Compile cpphs from distribution, with C compiler
bin/cpphs:	src/runtime/*.c src/runtime/config*.h generated/cpphs.c
	@mkdir -p bin
	$(CCEVAL) generated/cpphs.c -o bin/cpphs

# Compile combinator evaluator
bin/mhseval:	src/runtime/*.c src/runtime/config*.h
	@mkdir -p bin
	$(CCEVAL) src/runtime/comb.c -o bin/mhseval
	size bin/mhseval

bin/mhsevalgdb:	src/runtime/*.c src/runtime/config*.h
	@mkdir -p bin
	$(CC) $(CCWARNS) -g src/runtime/eval-$(CONF).c $(CCLIBS) src/runtime/comb.c -o bin/mhsevalgdb

# Compile mhs with ghc
bin/gmhs:	src/*/*.hs ghc/*.hs ghc/*/*.hs ghc/*/*/*.hs
	@mkdir -p bin
	$(GHC) $(GHCFLAGS) src/MicroHs/Main.hs -main-is MicroHs.Main -o bin/gmhs

# Compile mhs with ghc, with code coverage
bin/cmhs:	src/*/*.hs ghc/*.hs ghc/*/*.hs
	@mkdir -p bin
	$(GHC) $(GHCFLAGS) -fhpc src/MicroHs/Main.hs -main-is MicroHs.Main -o bin/cmhs

# Generate distribution C file
generated/mhs.c:	bin/mhs src/*/*.hs
	@mkdir -p generated
	bin/mhs -z $(MHSINC) MicroHs.Main -ogenerated/mhs.c

ghcgen:	bin/gmhs src/*/*.hs lib/*.hs lib/*/*.hs lib/*/*/*.hs
	bin/gmhs $(MHSINC) MicroHs.Main -ogenerated/mhs.c

# Make sure boottrapping works
bootstrap:	bin/mhs-stage2
	@echo "*** copy stage2 to bin/mhs"
	cp bin/mhs-stage2 bin/mhs
	cp generated/mhs-stage2.c generated/mhs.c 

# Build stage1 compiler with existing compiler
bin/mhs-stage1:	bin/mhs src/*/*.hs
	@mkdir -p generated
	@echo "*** Build stage1 compiler, using bin/mhs"
	bin/mhs -z $(MHSINC) MicroHs.Main -ogenerated/mhs-stage1.c
	$(CCEVAL) generated/mhs-stage1.c -o bin/mhs-stage1

# Build stage2 compiler with stage1 compiler, and compare
bin/mhs-stage2:	bin/mhs-stage1 src/*/*.hs
	@mkdir -p generated
	@echo "*** Build stage2 compiler, with stage1 compiler"
	bin/mhs-stage1 -z $(MHSINC) MicroHs.Main -ogenerated/mhs-stage2.c
	cmp generated/mhs-stage1.c generated/mhs-stage2.c
	@echo "*** stage2 equal to stage1"
	$(CCEVAL) generated/mhs-stage2.c -o bin/mhs-stage2

cpphssrc/malcolm-wallace-universe:
	mkdir -p cpphssrc
	cd cpphssrc; git clone git@github.com:hackage-trustees/malcolm-wallace-universe.git

# Use this cpphs for bootstrapping
USECPPHS=bin/cpphs

bootstrapcpphs: bin/mhs cpphssrc/malcolm-wallace-universe #bin/cpphs
	MHSCPPHS=$(USECPPHS) bin/mhs -z -XCPP -icpphssrc/malcolm-wallace-universe/polyparse-1.12/src -icpphssrc/malcolm-wallace-universe/cpphs-1.20.9 cpphssrc/malcolm-wallace-universe/cpphs-1.20.9/cpphs.hs -ogenerated/cpphs.c

# Run test examples with ghc-compiled compiler
runtest:	bin/mhseval bin/gmhs tests/*.hs
	cd tests; make alltest

# Run test examples with mhs-compiled compiler
runtestmhs:
	cd tests; make MHS=../bin/mhs cache; make MHS="../bin/mhs +RTS -H4M -RTS -CR" info test errtest

# Compress the binary (broken on MacOS)
bin/umhs: bin/mhs
	rm -f bin/umhs
	upx -q -q -obin/umhs bin/mhs

#
timecompile: bin/mhs
	time bin/mhs +RTS -v -RTS $(MHSINC) MicroHs.Main

#
timecachecompile: bin/mhs
	@-rm -f .mhscache
	time bin/mhs +RTS -v -RTS -CW AllOfLib
	time bin/mhs +RTS -v -RTS -CR $(MHSINC) MicroHs.Main

#
cachelib:
	@-rm -f .mhscache
	bin/mhs -CW AllOfLib

#
clean:
	rm -rf src/*/*.hi src/*/*.o *.comb *.tmp *~ bin/* a.out $(GHCOUTDIR) tmp/* Tools/*.o Tools/*.hi dist-newstyle generated/*-stage* .mhscache targets.conf .mhscache dist-mcabal cpphssrc
	make clean -f Makefile.emscripten
	cd tests; make clean
	-cabal clean

install:
	mkdir -p $(PREFIX)/bin
	cp bin/mhs $(PREFIX)/bin
	-cp bin/cpphs $(PREFIX)/bin
	mkdir -p $(PREFIX)/lib/mhs/src/runtime
	cp -r lib $(PREFIX)/lib/mhs
	cp src/runtime/* $(PREFIX)/lib/mhs/src/runtime
	cp targets.conf $(PREFIX)/lib/mhs/targets.conf
	@echo "***"
	@echo "*** Installation complete"
	@echo "*** Set environment variable MHSDIR to $(PREFIX)/lib/mhs"
	@echo "***"

everytest:	newmhs runtest exampletest cachetest bootcombtest nfibtest info

everytestmhs:	bin/mhs bin/mhseval exampletest cachetest bootstrap runtestmhs nfibtest info

bootcombtest:	bin/gmhs bin/mhseval
	bin/gmhs $(MHSINC) -ogmhs.comb  MicroHs.Main
	bin/mhseval +RTS -v -rgmhs.comb -RTS $(MHSINC) -omhs.comb MicroHs.Main
	cmp gmhs.comb mhs.comb

exampletest:	bin/mhs bin/mhseval Example.hs
	bin/mhs -r Example
	bin/mhs Example && bin/mhseval
	bin/mhs Example -oEx && ./Ex && rm Ex

info:	bin/mhs
	bin/mhs -r -itests Info

cachetest:	bin/mhs bin/mhseval Example.hs
	rm -f .mhscache
	bin/mhs -CW AllOfLib
	bin/mhs -CR Example && bin/mhseval
	bin/mhs +RTS -v -RTS $(MHSINC) -CR MicroHs.Main
	rm -f .mhscache

nfibtest: bin/mhs bin/mhseval
	bin/mhs -itests Nfib && bin/mhseval

emscripten: bin/mhs targets.conf
	make test -f Makefile.emscripten

######

VERSION=0.9.15.0
MCABAL=$(HOME)/.mcabal
MCABALMHS=$(MCABAL)/mhs-$(VERSION)
MDATA=$(MCABALMHS)/data/mhs-$(VERSION)/data
MRUNTIME=$(MDATA)/src/runtime
MCABALBIN=$(MCABAL)/bin
MDIST=dist-mcabal
BASE=base-$(VERSION)
BASEMODULES=Control.Applicative Control.Arrow Control.DeepSeq Control.Error Control.Exception Control.Exception.Internal Control.Monad Control.Monad.Fail Control.Monad.ST Control.Monad.ST_Type Data.Array Data.Bits Data.Bool Data.Bool_Type Data.Bounded Data.Char Data.Char_Type Data.Complex Data.Constraint Data.Double Data.Dynamic Data.Either Data.Enum Data.Eq Data.Float Data.FloatW Data.Floating Data.Foldable Data.Fractional Data.Function Data.Functor Data.Functor.Const Data.Functor.Identity Data.IOArray Data.IORef Data.Int Data.Int.Instances Data.Int.IntN Data.Integer Data.Integer_Type Data.Integral Data.Ix Data.List Data.List.NonEmpty Data.List_Type Data.Maybe Data.Maybe_Type Data.Monoid Data.Num Data.Ord Data.Ordering_Type Data.Proxy Data.Ratio Data.Ratio_Type Data.Real Data.RealFloat Data.RealFrac Data.Records Data.STRef Data.Semigroup Data.String Data.Time.Clock Data.Time.Format Data.Traversable Data.Tuple Data.Type.Equality Data.TypeLits Data.Typeable Data.Version Data.Void Data.Word Data.ZipList Debug.Trace Foreign.C.String Foreign.C.Types Foreign.ForeignPtr Foreign.Marshal.Alloc Foreign.Marshal.Array Foreign.Marshal.Utils Foreign.Ptr Foreign.Storable GHC.Stack GHC.Types Numeric Numeric.FormatFloat Numeric.Natural Prelude Primitives System.Cmd System.Compress System.Directory System.Environment System.Exit System.IO System.IO.MD5 System.IO.PrintOrRun System.IO.Serialize System.IO.TimeMilli System.IO.Unsafe System.IO_Handle System.Info System.Process Text.Printf Text.Read Text.Read.Lex Text.Read.Numeric Text.Show TimeCompat Unsafe.Coerce

$(MCABALBIN)/mhs: bin/mhs
	@mkdir -p $(MCABALBIN)
	@mkdir -p $(MDIST)
	@echo 'module Paths_MicroHs where {import Data.Version; version :: Version; version = makeVersion [0,9,15,0]; getDataDir :: IO FilePath; getDataDir = return "$(MDATA)" }' > $(MDIST)/Paths_MicroHs.hs
	bin/mhs -z $(MHSINCNP) -i$(MDIST) MicroHs.Main -o$(MCABALBIN)/mhs

$(MCABALMHS)/packages/$(BASE).pkg: bin/mhs lib/*.hs
	@mkdir -p $(MRUNTIME)
	cp src/runtime/*.[ch] $(MRUNTIME)
	@echo $$PATH | tr ':' '\012' | grep -q $(MCABALBIN) || echo '***' Add $(MCABALBIN) to the PATH
	bin/mhs -P$(BASE) -o$(BASE).pkg -ilib $(BASEMODULES)
	bin/mhs -Q -a -a$(MCABALMHS) $(BASE).pkg
	@rm $(BASE).pkg

installmcabal: bin/mhs $(MCABAL)/bin/mhs $(MCABALMHS)/packages/$(BASE).pkg
