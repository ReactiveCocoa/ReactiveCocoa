#!/bin/bash

# Bash script to lint the content of playgrounds
# Heavily based on RxSwift's 
# https://github.com/ReactiveX/RxSwift/blob/master/scripts/validate-playgrounds.sh

BUILD_DIRECTORY="/Users/anders/Library/Developer/Xcode/DerivedData/ReactiveCocoa-guvxkadnajtlwednxbliaozqvdor"
XCODE_PLAYGROUND_TARGET=x86_64-macosx10.10
CONFIGURATION="Debug"

if [ -z "$BUILD_DIRECTORY" ]; then
	echo "\$BUILD_DIRECTORY is not set. Are you trying to run \`validate-playgrounds.sh\` without building RAC first?\n"
	echo "To validate the playground, run \`script/build\`."
	exit 1
fi

if [ -z "$XCODE_PLAYGROUND_TARGET" ]; then
	echo "\$XCODE_PLAYGROUND_TARGET is not set."
	exit 1
fi

PAGES_PATH=${BUILD_DIRECTORY}/Build/Products/${CONFIGURATION}/all-playground-pages.swift

cat ReactiveCocoa.playground/Sources/*.swift ReactiveCocoa.playground/Pages/**/*.swift > ${PAGES_PATH}

swift -v -target "${XCODE_PLAYGROUND_TARGET}" -D NOT_IN_PLAYGROUND -F ${BUILD_DIRECTORY}/Build/Products/${CONFIGURATION} ${PAGES_PATH} > /dev/null
result=$?

# Cleanup

exit $result
