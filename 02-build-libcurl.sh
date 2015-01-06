#!/bin/bash

VERSION="7.39.0"
PRECEDENT_VERSION="1.0.1j"
PRECEDENT_LIBNAME="libssl"
LIBNAME="libcurl"
LIBDOWNLOAD="http://curl.haxx.se/download/curl-${VERSION}.tar.gz"
ARCHIVE="${LIBNAME}-${VERSION}.tar.gz"

SDK="8.1"

# Enabled/disabled protocols (the fewer, the smaller the final binary size)
export PROTOCOLS="--enable-http --disable-rtsp --disable-ftp --disable-file --disable-ldap --disable-ldaps"
PROTOCOLS="${PROTOCOLS} --disable-rtsp --disable-dict --disable-telnet --disable-tftp"
PROTOCOLS="${PROTOCOLS} --disable-pop3 --disable-imap --disable-smtp --disable-gopher"

CONFIGURE_FLAGS="--without-libssh2 --without-ca-bundle --enable-static --disable-shared ${PROTOCOLS}"

DIR=`pwd`
ARCHS="i386 armv7 arm64"

# Download or use existing tar.gz
set -e
if [ ! -e ${ARCHIVE} ]; then
    echo "Downloading ${ARCHIVE}"
    curl -o ${ARCHIVE} ${LIBDOWNLOAD}
    echo ""
else
    echo "Using ${ARCHIVE}"
fi


# Create out dirs
mkdir -p "${DIR}/bin"
mkdir -p "${DIR}/lib"
mkdir -p "${DIR}/lib-i386"
mkdir -p "${DIR}/lib-no-i386"
mkdir -p "${DIR}/src"
mkdir -p "${DIR}/log"


# Build for all archs
for ARCH in ${ARCHS}
do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
    then
        PLATFORM="iPhoneSimulator"
		VER_PARAM="-mios-simulator-version-min=6.0"
    else
		VER_PARAM="-miphoneos-version-min=6.0"
        PLATFORM="iPhoneOS"
    fi

    echo "Building ${LIBNAME} ${VERSION} for ${PLATFORM} ${SDK} ${ARCH}..."

    # Ensure precedent lib is available for this architecture
    if [ -f "${DIR}/bin/${PRECEDENT_LIBNAME}-${PRECEDENT_VERSION}/${PLATFORM}${SDK}-${ARCH}/lib/${PRECEDENT_LIBNAME}.a" ];
    then
        echo "Using ${PRECEDENT_LIBNAME} ${PRECEDENT_VERSION} (${ARCH})..."
    else
        echo "Please build ${PRECEDENT_LIBNAME} ${PRECEDENT_VERSION} for ${ARCH} first"
        exit 1
    fi

    # Expand source code, prepare output directory and set log
    tar zxf ${ARCHIVE} -C "${DIR}/src"
    rm -rf "${DIR}/src/${LIBNAME}-${VERSION}"
    mv -f "${DIR}/src/curl-${VERSION}" "${DIR}/src/${LIBNAME}-${VERSION}"

    mkdir -p "${DIR}/bin/${LIBNAME}-${VERSION}/${PLATFORM}${SDK}-${ARCH}"
    LOG="${DIR}/log/${LIBNAME}-${VERSION}-${PLATFORM}${SDK}-${ARCH}.log"

    cd "${DIR}/src/${LIBNAME}-${VERSION}"

	DEVROOT="/Applications/Xcode.app/Contents/Developer/Platforms/${PLATFORM}.platform/Developer"
	SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDK}.sdk"

	export IPHONEOS_DEPLOYMENT_TARGET="6.0"
    export CC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang ${VER_PARAM}"

	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKROOT}"
	export CPPFLAGS="-D__IPHONE_OS_VERSION_MIN_REQUIRED=${IPHONEOS_DEPLOYMENT_TARGET%%.*}0000"
	export LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT}"

    if [ "${ARCH}" == "arm64" ];
    then
        HOST="aarch64-apple-darwin"
    else
		HOST="${ARCH}-apple-darwin"
    fi


    ./configure --host=${HOST} --disable-shared --enable-static ${CONFIGURE_FLAGS} \
                --with-ssl="${DIR}/bin/${PRECEDENT_LIBNAME}-${PRECEDENT_VERSION}/${PLATFORM}${SDK}-${ARCH}" \
                --prefix="${DIR}/bin/${LIBNAME}-${VERSION}/${PLATFORM}${SDK}-${ARCH}" >> "${LOG}" 2>&1

    make >> "${LOG}" 2>&1
    make install >> "${LOG}" 2>&1
    cd ${DIR}
    rm -rf "${DIR}/src/${LIBNAME}-${VERSION}"
done


# Create a single .a file for all architectures
echo "Creating binaries for ${LIBNAME}..."
lipo -create "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneSimulator${SDK}-i386/lib/${LIBNAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-armv7/lib/${LIBNAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-arm64/lib/${LIBNAME}.a" \
     -output "${DIR}/lib/${LIBNAME}.a"


# Copy the header files to include
mkdir -p "${DIR}/include/${LIBNAME}"
FIRST_ARCH="${ARCHS%% *}"
if [ "${FIRST_ARCH}" == "i386" ];
then
    PLATFORM="iPhoneSimulator"
else
    PLATFORM="iPhoneOS"
fi
cp -R "${DIR}/bin/${LIBNAME}-${VERSION}/${PLATFORM}${SDK}-${FIRST_ARCH}/include/" \
      "${DIR}/include/${LIBNAME}/"

echo "Finished; ${LIBNAME} binary created for archs: ${ARCHS}"
