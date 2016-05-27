FROM ubuntu:14.04.4

# Image for 'mapbox/mapnik-vector-tile' @ v1.2.0 (rev b5ec759, 2016.04.19).

# Do not install these protobuf-related packages because they may cause conflict
#	and disrupt the compilation.
#	- libprotoc-dev
#	- libprotobuf8
#	- libprotobuf-dev

# Required packages:
#	- ca-certificates and openssl: to get up-to-date certificates and make sure
#		we have the latest 'openssl'. I added this because once I got an error
#		saying: "ERROR: cannot verify github.com's certificate".
#	- curl: besides explicit calls in this file, it is used in 'bootstrap.sh'.
#	- git: besides explicit calls in this file, it is used in 'bootstrap.sh'.
#	- clang-3.5: provides 'clang++-3.5'.
#	- protobuf-compiler: compilation triggered by 'make' needs program 'protoc'.
#	- python: besides explicit calls in this file, it is used in 'bootstrap.sh',
#		and in the compilation triggered by 'make'.
#	- zlib1g-dev: to compile 'src/vector_tile_compression.cpp'.

RUN apt-get update -q && apt-get --no-install-recommends -y install \
	ca-certificates openssl \
	curl wget \
	git \
	make \
	build-essential \
	clang-3.5 \
	protobuf-compiler \
	python \
	zlib1g-dev

# warning: repo 'mapnik-vector-tile' must be cloned since downloading a revision
#	archive will not make 'mapnik-config' available, and compilation will fail.
# TODO: make sure warning above is correct.
RUN git clone --depth=10 --branch=v1.2.0 'https://github.com/mapbox/mapnik-vector-tile.git' mapnik-vector-tile \
	&& cd mapnik-vector-tile \
	&& git submodule update --init

# note: had to split in 3 'RUN's because 'source' is a bash function that is not
#	available in 'sh'.
RUN ["/bin/bash", "-c", "cd mapnik-vector-tile && source bootstrap.sh"]

# Mapnik binaries archive downloaded and used by Mason is 23M and is located at:
#	'mapnik-vector-tile/mason_packages/.binaries/linux-x86_64/mapnik/latest.tar.gz'

# note: 'mapnik-vector-tile/mason_packages/.link/bin/mapnik-*' are symlinks to
#	'mapnik-vector-tile/mason_packages/linux-x86_64/mapnik/latest/bin/mapnik-*'
# note: libs are in
#	- 'mapnik-vector-tile/mason_packages/.link/include/'
#	- 'mapnik-vector-tile/mason_packages/linux-x86_64/mapnik/latest/include/mapnik/'
#	- 'mapnik-vector-tile/mason_packages/.link/lib/mapnik/'

# It is important to add to PATH the 'bin' dir created in the 'mason_packages'
#	because at least one of the binaries in there ('mapnik-config' is required
#	by a compilation step below.
# With `RUN env` we know the non-modified PATH env var is:
#	'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
# TODO: figure out how to concatenate as if it was a normal bash session i.e.
#	`export PATH=$(pwd)/mason_packages/.link/bin:${PATH}`
ENV "PATH=/mapnik-vector-tile/mason_packages/.link/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# TODO: while the compilation seems successful and the image was generated,
#	figure out if more env vars are necessary for linking and that stuff. See:
#	https://github.com/mapbox/mapnik-vector-tile/blob/dd83c4c/bootstrap.sh#L48-L61

# note: set JOBS just in case; we have seen errors due to references an
#	undefined JOBS env var.
RUN cd mapnik-vector-tile/ \
	&& JOBS=1 CXX="clang++-3.5 -Qunused-arguments" make
