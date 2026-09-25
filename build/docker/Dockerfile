FROM debian:11

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -o APT::Update::Error-Mode=any -o Acquire::Retries=3 update \
    && apt-get install -y --no-install-recommends \
       bc bison build-essential bzip2 ca-certificates ccache clang curl \
       debianutils device-tree-compiler diffutils file flex g++-multilib gawk gcc-multilib \
       gettext git libelf-dev libncurses-dev libssl-dev lld llvm patch perl \
       pkgconf python3 python3-dev python3-pyelftools python3-setuptools \
       qemu-utils quilt rsync subversion swig time unzip util-linux wget \
       xz-utils zlib1g-dev zstd \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8
WORKDIR /wrt
CMD ["sleep", "infinity"]
