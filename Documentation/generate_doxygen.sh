#!/bin/bash - 

set -o nounset                              # Treat unset variables as an error

DOCSET_NAME=com.github.ReactiveCocoa.docset
TEMP_DIR="${HOME}/Library/Caches/ReactiveCocoa"
REACTIVE_COCOA_DOCSET="${TEMP_DIR}/${DOCSET_NAME}"
GENERATION_DIR="${TEMP_DIR}"
DOXYGEN=/usr/local/bin/doxygen

cd $(dirname $0)
SCRIPT_PATH=$(pwd -P .)
REACTIVE_COCOA_SOURCE="${SCRIPT_PATH}/../ReactiveCocoaFramework/ReactiveCocoa"

if [[ -d "${GENERATION_DIR}" ]]; then
    rm -rf "${GENERATION_DIR}"
fi
mkdir "${GENERATION_DIR}"

set -x
cd "${GENERATION_DIR}"
"${SCRIPT_PATH}/tomdoc_to_doxygen.sh" --doxygen -o "${GENERATION_DIR}" "${REACTIVE_COCOA_SOURCE}"
pwd
${DOXYGEN} "${SCRIPT_PATH}/ReactiveCocoaDocset.Doxyfile"

cd "${REACTIVE_COCOA_DOCSET}"
if [[ $? -ne 0 ]]; then
    echo "Failed to generate the docset ${DOCSET_NAME}" >&2
    exit 1
fi

make install
if [[ $? -ne 0 ]]; then
    echo "Failed to install the docset ${DOCSET_NAME}" >&2
    exit 2
fi
echo "Generated and installed docset ${DOCSET_NAME}" >&2
