#!/bin/bash

# Bash script to lint the content of playgrounds
# Heavily based on RxSwift's 
# https://github.com/ReactiveX/RxSwift/blob/master/scripts/validate-playgrounds.sh

if [ -z "$BUILD_DIRECTORY" ]; then
	echo "\$BUILD_DIRECTORY is not set. Are you trying to run \`validate-playgrounds.sh\` without building RAC first?\n"
	echo "To validate the playground, run \`script/build\`."
	exit 1
fi

if [ -z "$PLAYGROUND" ]; then
	echo "\$PLAYGROUND is not set."
	exit 1
fi

if [ -z "$XCODE_PLAYGROUND_TARGET" ]; then
	echo "\$XCODE_PLAYGROUND_TARGET is not set."
	exit 1
fi

BUILD_DIR_PATH=

if [ "$XCODE_SDK" == "macosx" ]; then
	BUILD_DIR_PATH=Products/${CONFIGURATION}
else
	BUILD_DIR_PATH=Intermediates/CodeCoverage/Products/${CONFIGURATION}-${XCODE_SDK}
fi

SDK_ROOT=$(xcrun --sdk ${XCODE_SDK} --show-sdk-path)
PAGES_PATH=${BUILD_DIRECTORY}/Build/${BUILD_DIR_PATH}/all-playground-pages.swift

cat ${PLAYGROUND}/Sources/*.swift ${PLAYGROUND}/Pages/**/*.swift > ${PAGES_PATH}

swift -v -target ${XCODE_PLAYGROUND_TARGET} -sdk ${SDK_ROOT} -D NOT_IN_PLAYGROUND -F ${BUILD_DIRECTORY}/Build/${BUILD_DIR_PATH} ${PAGES_PATH} > /dev/null
result=$?

# Cleanup
rm -Rf $BUILD_DIRECTORY

exit $result
