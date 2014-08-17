GEN=./dist/build/xcffibgen/xcffibgen
AUTOPEP8=autopep8 --in-place --aggressive --aggressive

XCBVER=$(shell pkg-config --modversion xcb-proto)
XCBDIR=$(shell pkg-config --variable=xcbincludedir xcb-proto)
NCPUS=$(shell grep -c processor /proc/cpuinfo)
PARALLEL=$(shell which parallel)

# you should have xcb-proto installed to run this
xcffib: $(GEN) module/*.py
	$(GEN) --input $(XCBDIR) --output ./xcffib
	cp ./module/*py ./xcffib/
	sed -i "s/__xcb_proto_version__ = .*/__xcb_proto_version__ = \"${XCBVER}\"/" xcffib/__init__.py
ifeq (${PARALLEL},)
	$(AUTOPEP8) ./xcffib/*.py
else
	find ./xcffib/*.py | parallel -j $(NCPUS) $(AUTOPEP8) '{}'
endif

dist:
	cabal configure --enable-tests

.PHONY: $(GEN)
$(GEN): dist
	cabal build

.PHONY: clean
clean:
	-cabal clean
	-rm -rf xcffib
	-rm -rf module/*pyc module/__pycache__
	-rm -rf tests/*pyc tests/__pycache__
	-rm -rf build *egg*

# A target for just running nosetests. Travis will run 'check', which does
# everything. (Additionally, travis uses separate environments where nosetests
# points to The Right Thing for each, so we don't need to do nosetests3.)
pycheck: xcffib
	nosetests -d
	nosetests3 -d

valgrind: xcffib
	valgrind --leak-check=full --show-leak-kinds=definite nosetests -d

newtests: $(GEN)
	$(GEN) --input ./tests/generator/ --output ./tests/generator/
	git diff tests

# These are all split out so make -j3 check goes as fast as possible.
.PHONY: lint
lint:
	flake8 --config=./tests/flake8.cfg ./module

.PHONY: htests
htests: $(GEN)
	cabal test

check: xcffib lint htests
	nosetests -d

# make release ver=v0.99.99
release: xcffib
ifeq (${ver},)
	@echo "no version (ver=) specified, not releasing."
else ifneq ($(wildcard ./xcffib.egg-info*),)
	@echo "xcffib.egg-info exists, not releasing."
else
	sed -i "s/version = .*/version = \"${ver}\"/" setup.py
	git commit -a -m "Release ${ver}"
	git tag ${ver}
	python setup.py sdist
	python setup.py sdist upload
endif
