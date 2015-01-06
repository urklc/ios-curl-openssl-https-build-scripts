#!/bin/bash

VERSION="1.0.1j"
LIBNAME="libssl"
CRYPTONAME="libcrypto"
LIBDOWNLOAD="http://www.openssl.org/source/openssl-${VERSION}.tar.gz"
ARCHIVE="${LIBNAME}-${VERSION}.tar.gz"

SDK="8.1"
CONFIGURE_FLAGS=""

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
    tar zxf ${ARCHIVE} -C "${DIR}/src"
    rm -rf "${DIR}/src/${LIBNAME}-${VERSION}"
    cp -r "${DIR}/src/openssl-${VERSION}" "${DIR}/src/${LIBNAME}-${VERSION}"
    
    if [ "${PLATFORM}" == "iPhoneOS" ];
    then
        sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" \
                "${DIR}/src/${LIBNAME}-${VERSION}/crypto/ui/ui_openssl.c"
    fi

    mkdir -p "${DIR}/bin/${LIBNAME}-${VERSION}/${PLATFORM}${SDK}-${ARCH}"
    LOG="${DIR}/log/${LIBNAME}-${VERSION}-${PLATFORM}${SDK}-${ARCH}.log"

    cd "${DIR}/src/${LIBNAME}-${VERSION}"

    export DEVROOT="/Applications/Xcode.app/Contents/Developer/Platforms/${PLATFORM}.platform/Developer"
    export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDK}.sdk"
    export CC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch ${ARCH} ${VER_PARAM} -isysroot ${SDKROOT}"
    export LD="${DEVROOT}/usr/bin/ld -arch ${ARCH} -isysroot ${SDKROOT}"
    export AR="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar"
    export AS="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/as"
    export NM="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm"
    export RANLIB="ranlib"

    ./configure BSD-generic32 no-shared ${CONFIGURE_FLAGS} \
                --openssldir="${DIR}/bin/${LIBNAME}-${VERSION}/${PLATFORM}${SDK}-${ARCH}" >> "${LOG}" 2>&1

    make >> "${LOG}" 2>&1
    make install >> "${LOG}" 2>&1
    cd ${DIR}
    #rm -rf "${DIR}/src/${LIBNAME}-${VERSION}"
done


# Create a single .a file for all architectures
echo "Creating binaries for ${LIBNAME}..."
lipo -create "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneSimulator${SDK}-i386/lib/${LIBNAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-armv7/lib/${LIBNAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-arm64/lib/${LIBNAME}.a" \
     -output "${DIR}/lib/${LIBNAME}.a"
     
echo "Creating binaries for ${CRYPTONAME}..."
lipo -create "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneSimulator${SDK}-i386/lib/${CRYPTONAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-armv7/lib/${CRYPTONAME}.a" \
             "${DIR}/bin/${LIBNAME}-${VERSION}/iPhoneOS${SDK}-arm64/lib/${CRYPTONAME}.a" \
     -output "${DIR}/lib/${CRYPTONAME}.a"

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
