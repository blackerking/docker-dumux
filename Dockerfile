FROM phusion/baseimage:0.9.22

# set version label
ARG DUMUX_RELEASE=2.12
ARG DUNE_RELEASE=2.7
ARG OPM_RELEASE=2018.10/final
LABEL maintainer="blackerking"
ARG DEBIAN_FRONTEND=noninteractive

#DuMux version(s) 		compatible DUNE version(s)
#3.1, 3.2, 3.3-git 		2.6*, 2.7, 2.8-git**
#3.0 				2.6*, 2.7
#2.9, 2.10, 2.11, 2.12 		2.4, 2.5, 2.6*
#2.6, 2.7, 2.8 			2.3, 2.4
#2.5 				2.2, 2.3

# environment settings
ENV DUNE_PATH="/opt/dune"
ENV TZ=Europe/Berlin

# run Ubuntu update as advised on https://github.com/phusion/baseimage-docker
RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confold" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \
 echo "**** install needed packages ****" && \
 #add-apt-repository -y ppa:opm/ppa && \
 apt-get update && apt-get dist-upgrade --no-install-recommends --yes && \
    apt-get install --no-install-recommends --yes \
    ca-certificates \
    vim \
	nano \	
    python3-dev \
    python3-pip \
    git \
	git-core \
    pkg-config \
    build-essential \
    gfortran \
    cmake \
    mpi-default-bin \
    mpi-default-dev \
	mpich \
	mpich-doc \
	libmpich-dev \
    libsuitesparse-dev \
    libsuperlu-dev \
    libeigen3-dev \
	libblkid-dev \
	e2fslibs-dev \
	libboost-all-dev \
	libblas-dev \
	libtrilinos-zoltan-dev \
	libaudit-dev \
    doxygen \
    texlive \
	texlive-science \
	texlive-latex-recommended \
	texlive-latex-extra \
	texlive-bibtex-extra \
#FEHLER:	texlive-collection-mathextra \
	texlive-fonts-extra \
	latexmk \
	paraview \
	gmsh \
	zlib1g \
	zlib1g-dev \
	curl \
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
    && rm -rf /var/lib/apt/lists/*

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
