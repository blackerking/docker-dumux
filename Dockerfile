FROM ubuntu:latest

# set version label
ARG DUMUX_RELEASE=2.12
ARG DUNE_RELEASE=2.7
LABEL maintainer="blackerking"

# environment settings
ENV DUNE_PATH="/opt/dune"

# run Ubuntu update as advised on https://github.com/phusion/baseimage-docker
RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confold" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \
 echo "**** install needed packages ****" && \
 add-apt-repository -y ppa:opm/ppa
 apt-get update && apt-get dist-upgrade --no-install-recommends --yes && \
    apt-get install --no-install-recommends --yes \
    ca-certificates \
    vim \
	nano \	
    python-dev \
    python-pip \
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
    paraview \
    doxygen \
    texlive \
	texlive-science \
	texlive-latex-recommended \
	texlive-latex-extra \
	texlive-bibtex-extra \
	texlive-math-extra \
	texlive-fonts-extra \
	paraview \
	gmsh \
	zlib1g \
	zlib1g-dev \
	curl \
	sudo \
	tar \
	pgf \
	gnuplot \
	ghostscript  \
	unzip && \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# create a dumux user
RUN useradd -m --home-dir /opt/dune dumux
# add user to video group for graphics
RUN usermod -a -G video dumux

USER dumux
WORKDIR DUNE_PATH

# clone dune dependencies
RUN git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/core/dune-common.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/core/dune-geometry.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/core/dune-grid.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/core/dune-istl.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/core/dune-localfunctions.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/staging/dune-uggrid.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/extensions/dune-alugrid.git && \
    git clone -b releases/DUNE_RELEASE https://gitlab.dune-project.org/extensions/dune-foamgrid.git

# clone dumux repository
RUN git clone -b releases/DUMUX_RELEASE https://git.iws.uni-stuttgart.de/dumux-repositories/dumux.git

# configure module
RUN DUNE_PATH/dune-common/bin/dunecontrol --opts=DUNE_PATH/dumux/optim.opts all

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
