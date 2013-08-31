#!/bin/bash - 

set -o nounset                              # Treat unset variables as an error
cd $(dirname $0)
SCRIPT_PATH=$(pwd -P .)
FRAMEWORK_SOURCE="${SCRIPT_PATH}/../ReactiveCocoaFramework/ReactiveCocoa"
INDEX_PATH="${SCRIPT_PATH}/README.md"

FRAMEWORK=ReactiveCocoa
COMPANY=GitHub
COMPANY_ID=com.github
#PUBLISH_OPTION=--publish-docset
PUBLISH_OPTION=

DOCSET_NAME=${COMPANY_ID}.${FRAMEWORK}.docset
DOCSET_FEED_URL=http://www.dervishsoftware/docsets
TEMP_DIR="${HOME}/Library/Caches/${FRAMEWORK}"
REACTIVE_COCOA_DOCSET="${TEMP_DIR}/${DOCSET_NAME}"
GENERATION_DIR="${TEMP_DIR}/headers"
OUTPUT_DIR="${TEMP_DIR}/appledoc"
APPLEDOC=/usr/local/bin/appledoc


if [[ -d "${GENERATION_DIR}" ]]; then
    rm -rf "${GENERATION_DIR}"
fi
mkdir "${GENERATION_DIR}"

set -x
cd "${GENERATION_DIR}"
"${SCRIPT_PATH}/tomdoc_to_doxygen.sh" --appledoc -o "${GENERATION_DIR}" "${FRAMEWORK_SOURCE}"
pwd
"${APPLEDOC}" \
    --project-name "${FRAMEWORK}" \
    --project-company "${COMPANY}" \
    --company-id "${COMPANY_ID}" \
    --docset-atom-filename "${FRAMEWORK}.atom" \
    --docset-feed-url "${DOCSET_FEED_URL}/%DOCSETATOMFILENAME" \
    --docset-package-url "${DOCSET_FEED_URL}/%DOCSETPACKAGEFILENAME" \
    --docset-fallback-url "${DOCSET_FEED_URL}" \
    --docset-bundle-filename "${DOCSET_NAME}" \
    --output "${OUTPUT_DIR}" \
    ${PUBLISH_OPTION} \
    --logformat xcode \
    --keep-undocumented-objects \
    --keep-undocumented-members \
    --keep-intermediate-files \
    --no-repeat-first-par \
    --no-warn-invalid-crossref \
    --ignore "*.m" \
    --ignore "*Deprecated*" \
    --ignore-symbol "*Deprecated*" \
    --index-desc "${INDEX_PATH}" \
    --verbose 4 \
    "${GENERATION_DIR}"

#cd "${REACTIVE_COCOA_DOCSET}"
#if [[ $? -ne 0 ]]; then
#    echo "Failed to generate the docset ${DOCSET_NAME}" >&2
#    exit 1
#fi
#
#make install
#if [[ $? -ne 0 ]]; then
#    echo "Failed to install the docset ${DOCSET_NAME}" >&2
#    exit 2
#fi
#echo "Generated and installed docset ${DOCSET_NAME}" >&2
