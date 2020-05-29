FROM phusion/baseimage:0.9.22

# set version label
ARG DUMUX_RELEASE=2.12
ARG DUNE_RELEASE=2.7
ARG OPM_RELEASE=2020.04/final
LABEL maintainer="blackerking"
ARG DEBIAN_FRONTEND=noninteractive

# Last Modified: 2020-05-07
ENV GCC_VERSION 10.1.0
# Docker EOL: 2021-11-07


#DuMux version(s) 	compatible DUNE version(s)
#3.1, 3.2, 3.3-git 		2.6*, 2.7, 2.8-git**
#3.0 					2.6*, 2.7
#2.9, 2.10, 2.11, 2.12 	2.4, 2.5, 2.6*
#2.6, 2.7, 2.8 			2.3, 2.4
#2.5 					2.2, 2.3

# environment settings
ENV DUNE_PATH="/opt/dune"
ENV TZ=Europe/Berlin

# run Ubuntu update as advised on https://github.com/phusion/baseimage-docker
RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confold" 

# new Compiler GNU 
RUN \
	echo "**** get newer compiler ****" && \
	apt-get update && apt-get install -y \
	gnupg \
	dirmngr \
	; 

ENV GPG_KEYS \
# 1024D/745C015A 1999-11-09 Gerald Pfeifer <gerald@pfeifer.com>
	B215C1633BCA0477615F1B35A5B3A004745C015A \
# 1024D/B75C61B8 2003-04-10 Mark Mitchell <mark@codesourcery.com>
	B3C42148A44E6983B3E4CC0793FA9B1AB75C61B8 \
# 1024D/902C9419 2004-12-06 Gabriel Dos Reis <gdr@acm.org>
	90AA470469D3965A87A5DCB494D03953902C9419 \
# 1024D/F71EDF1C 2000-02-13 Joseph Samuel Myers <jsm@polyomino.org.uk>
	80F98B2E0DAB6C8281BDF541A7C8C3B2F71EDF1C \
# 2048R/FC26A641 2005-09-13 Richard Guenther <richard.guenther@gmail.com>
	7F74F97C103468EE5D750B583AB00996FC26A641 \
# 1024D/C3C45C06 2004-04-21 Jakub Jelinek <jakub@redhat.com>
	33C235A34C46AA3FFB293709A328C3A2C3C45C06
RUN set -ex; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done
	
# https://gcc.gnu.org/mirrors.html
ENV GCC_MIRRORS \
		https://ftpmirror.gnu.org/gcc \
		https://mirrors.kernel.org/gnu/gcc \
		https://bigsearcher.com/mirrors/gcc/releases \
		http://www.netgull.com/gcc/releases \
		https://ftpmirror.gnu.org/gcc \
# only attempt the origin FTP as a mirror of last resort
		ftp://ftp.gnu.org/gnu/gcc

RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	#apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		flex \
		wget \
		gcc \
		make \
		g++ \
		git \
		autoconf \
		automake \
		gawk \
	; \
	rm -r /var/lib/apt/lists/*; \
	\
	_fetch() { \
		local fetch="$1"; shift; \
		local file="$1"; shift; \
		for mirror in $GCC_MIRRORS; do \
			if curl -fL "$mirror/$fetch" -o "$file"; then \
				return 0; \
			fi; \
		done; \
		echo >&2 "error: failed to download '$fetch' from several mirrors"; \
		return 1; \
	}; \
	\
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz.sig" 'gcc.tar.xz.sig'; \
	_fetch "gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" 'gcc.tar.xz'; \
	gpg --batch --verify gcc.tar.xz.sig gcc.tar.xz; \
	mkdir -p /usr/src/gcc; \
	tar -xf gcc.tar.xz -C /usr/src/gcc --strip-components=1; \
	rm gcc.tar.xz*; \
	\
	cd /usr/src/gcc; \
	\
# "download_prerequisites" pulls down a bunch of tarballs and extracts them,
# but then leaves the tarballs themselves lying around
	./contrib/download_prerequisites; \
	{ rm *.tar.* || true; }; \
	\
# explicitly update autoconf config.guess and config.sub so they support more arches/libcs
#	for f in config.guess config.sub; do \
#		wget -O "$f" "https://git.savannah.gnu.org/cgit/config.git/plain/config.guess"; \
# find any more (shallow) copies of the file we grabbed and update them too
#		find -mindepth 2 -name "$f" -exec cp -v "$f" '{}' ';'; \
#	done; \
	\
	dir="$(mktemp -d)"; \
	cd "$dir"; \
	\
	extraConfigureArgs=''; \
	dpkgArch="$(dpkg --print-architecture)"; \
	case "$dpkgArch" in \
# with-arch: https://anonscm.debian.org/viewvc/gcccvs/branches/sid/gcc-6/debian/rules2?revision=9450&view=markup#l491
# with-float: https://anonscm.debian.org/viewvc/gcccvs/branches/sid/gcc-6/debian/rules.defs?revision=9487&view=markup#l416
# with-mode: https://anonscm.debian.org/viewvc/gcccvs/branches/sid/gcc-6/debian/rules.defs?revision=9487&view=markup#l376
		armel) \
			extraConfigureArgs="$extraConfigureArgs --with-arch=armv4t --with-float=soft" \
			;; \
		armhf) \
			extraConfigureArgs="$extraConfigureArgs --with-arch=armv7-a --with-float=hard --with-fpu=vfpv3-d16 --with-mode=thumb" \
			;; \
		\
# with-arch-32: https://anonscm.debian.org/viewvc/gcccvs/branches/sid/gcc-6/debian/rules2?revision=9450&view=markup#l590
		i386) \
			osVersionID="$(set -e; . /etc/os-release; echo "$VERSION_ID")"; \
			case "$osVersionID" in \
				8) extraConfigureArgs="$extraConfigureArgs --with-arch-32=i586" ;; \
				*) extraConfigureArgs="$extraConfigureArgs --with-arch-32=i686" ;; \
			esac; \
# TODO for some reason, libgo + i386 fails on https://github.com/gcc-mirror/gcc/blob/gcc-7_1_0-release/libgo/runtime/proc.c#L154
# "error unknown case for SETCONTEXT_CLOBBERS_TLS"
			;; \
	esac; \
	\
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	/usr/src/gcc/configure \
		--build="$gnuArch" \
		--disable-multilib \
		--enable-languages=c,c++,fortran \
		$extraConfigureArgs \
	; \
	make -j "$(nproc)"; \
	make install-strip; \
	\
	cd ..; \
	\
	rm -rf "$dir" /usr/src/gcc; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# gcc installs .so files in /usr/local/lib64...
RUN set -ex; \
	echo '/usr/local/lib64' > /etc/ld.so.conf.d/local-lib64.conf; \
	ldconfig -v

# ensure that alternatives are pointing to the new compiler and that old one is no longer used
RUN set -ex; \
	dpkg-divert --divert /usr/bin/gcc.orig --rename /usr/bin/gcc; \
	dpkg-divert --divert /usr/bin/g++.orig --rename /usr/bin/g++; \
	dpkg-divert --divert /usr/bin/gfortran.orig --rename /usr/bin/gfortran; \
	update-alternatives --install /usr/bin/cc cc /usr/local/bin/gcc 999





RUN \
	echo "**** install needed packages for DUMUX ****" && \
	#add-apt-repository -y ppa:opm/ppa && \
    apt-get update && apt-get install -y --no-install-recommends \
#    ca-certificates \
#    vim \
	nano \	
    python3-dev \
    python3-pip \
    git \
#	git-core \
    pkg-config 
#    gfortran 

RUN \
	echo "**** install needed packages for DUMUX 2****" && \
	#add-apt-repository -y ppa:opm/ppa && \
    apt-get install -y \
    cmake \
#ERROR		libecl \
#ERROR    mpi-default-bin \
#ERROR    mpi-default-dev \
#ERROR	mpich \
#ERROR	mpich-doc \
#ERROR	libmpich-dev \
#ERROR    libsuitesparse-dev \
#ERROR    libsuperlu-dev \
    libeigen3-dev \
	libblkid-dev \
	e2fslibs-dev \
	libboost-all-dev \
#ERROR	libblas-dev \
	libtrilinos-zoltan-dev \
	libaudit-dev \
    doxygen \
    texlive \
	texlive-science \
	texlive-latex-recommended \
	texlive-latex-extra \
	texlive-bibtex-extra \
#ERROR	texlive-collection-mathextra \
#LONG WAITING TIME	texlive-fonts-extra \
	latexmk \
	paraview \
	gmsh \
	zlib1g \
	zlib1g-dev \
	sudo \
	tar \
	vc-dev \
#	dune-python \
#	gmp \
#	TBB \
	libalberta-dev \
#FEHLER:	pgf \
	gnuplot \
	ghostscript  \
	unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# create a dumux user
RUN useradd -m --home-dir /opt/dune dumux
# add user to video group for graphics
RUN usermod -a -G video dumux

USER dumux
WORKDIR $DUNE_PATH

# clone dune dependencies
RUN git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/core/dune-common.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/core/dune-geometry.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/core/dune-grid.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/core/dune-istl.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/core/dune-localfunctions.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/staging/dune-uggrid.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/extensions/dune-alugrid.git && \
    git clone -b releases/$DUNE_RELEASE https://gitlab.dune-project.org/extensions/dune-foamgrid.git && \
# clone dumux repository
	git clone -b releases/$DUMUX_RELEASE https://git.iws.uni-stuttgart.de/dumux-repositories/dumux.git && \
# clone opm repository
	git clone -b release/$OPM_RELEASE https://github.com/OPM/opm-common.git && \
	git clone -b release/$OPM_RELEASE https://github.com/OPM/opm-grid.git


# configure module
RUN $DUNE_PATH/dune-common/bin/dunecontrol --opts=$DUNE_PATH/dumux/optim.opts all

# build doxygen documentation
RUN cd dumux/build-cmake && make doc

# switch back to root
USER root

# make graphical output with paraview work
ENV QT_X11_NO_MITSHM 1

# set entry point like advised https://github.com/phusion/baseimage-docker
# this sets the permissions right, see above
ENTRYPOINT ["/sbin/my_init","--quiet","--","/sbin/setuser","dumux","/bin/bash","-l","-c"]

# start interactive shell
CMD ["/bin/bash","-i"]

# volumes
VOLUME DUNE_PATH
