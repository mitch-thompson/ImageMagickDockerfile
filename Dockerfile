FROM registry.access.redhat.com/ubi8/ubi:8.1 as base
ARG JAVA_VERSION=17
ENV CORRETTO_URL=https://corretto.aws/downloads/
ENV LATEST=latest/
ENV LATEST_CHECKSUM=latest_checksum/
ENV FILENAME=amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.rpm
ENV SIG_FILE=amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.tar.gz.pub
ENV MD5_FILENAME=${FILENAME}.md5

RUN dnf -y update && \
    dnf -y install jq curl vim fontconfig fontconfig-devel freetype freetype-devel ghostscript libgomp libjpeg-turbo \
    libjpeg-turbo-devel libtiff libtiff-devel lcms2 libstdc++ libstdc++-devel

WORKDIR /tmp
RUN curl -L ${CORRETTO_URL}${LATEST}${FILENAME} --output ${FILENAME}
RUN curl -L ${CORRETTO_URL}${LATEST_CHECKSUM}${FILENAME} --output ${MD5_FILENAME}

RUN if [[ $(md5sum ${FILENAME} | awk '{print $1}') != $(cat ${MD5_FILENAME}) ]] ; \
    then \
		echo 'MD5 validation failed' && \
		exit 1; \
    fi

RUN rpm --import  ${CORRETTO_URL}${LATEST}${SIG_FILE} && \
    rpm --checksig ${FILENAME} || exit 1

RUN dnf -y install ${FILENAME}

RUN dnf clean all && \
    rm -rf /var/cache/dnf && \
    rm -rf /tmp/* && \
    > /var/log/dnf.log && \
    > /var/log/dnf.librepo.log && \
    > /var/log/dnf.rpm.log

FROM base as dep-builder

RUN dnf install -y autoconf automake binutils gcc gcc-c++ gdb glibc-devel libtool make pkgconf pkgconf-m4 pkgconf-pkg-config git cmake

#
# Git repos versioning
#
ARG LIBHEIF_VERSION=1.16.2
ARG LIBDE265_VERSION=1.0.12
ARG IMAGEMAGICK_VERSION=7.1.1-12
ARG IMAGEMAGICK_VERSION_FINAL=7.1.1

COPY libc64.conf /etc/ld.so.conf.d/libc64.conf

WORKDIR /work

RUN curl -L https://github.com/strukturag/libde265/releases/download/v$LIBDE265_VERSION/libde265-$LIBDE265_VERSION.tar.gz -O && \
    tar -xzvf libde265-$LIBDE265_VERSION.tar.gz

WORKDIR /work/libde265-$LIBDE265_VERSION
RUN mkdir "build"
WORKDIR /work/libde265-$LIBDE265_VERSION/build
RUN cmake .. && \
    make && \
    make install && \
    ldconfig


WORKDIR /work
RUN curl -L https://github.com/strukturag/libheif/releases/download/v$LIBHEIF_VERSION/libheif-$LIBHEIF_VERSION.tar.gz -O && \
	tar -xzvf libheif-$LIBHEIF_VERSION.tar.gz

WORKDIR /work/libheif-$LIBHEIF_VERSION
RUN mkdir "build"
WORKDIR /work/libheif-$LIBHEIF_VERSION/build
RUN cmake .. && \
    make && \
    make install && \
    ldconfig

WORKDIR /work

RUN curl -L https://github.com/ImageMagick/ImageMagick/archive/refs/tags/$IMAGEMAGICK_VERSION.tar.gz -O && \
    tar -xzvf $IMAGEMAGICK_VERSION.tar.gz

WORKDIR /work/ImageMagick-$IMAGEMAGICK_VERSION
RUN PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig ./configure \
        --with-heic=yes \
        --with-jpeg=yes \
        --with-png=yes \
        --with-tiff=yes \
    	--with-webp=yes \
    	--with-lcms=yes \
    	--with-openexr=yes \
        --without-x \
        --disable-cipher \
        --without-magick-plus-plus \
        --without-pango \
        --without-perl && \
	make -j8 install && \
    ldconfig

COPY sample1.heic sample1.heic