#!/bin/bash - 

# Generate and install docset for a framework

set -o nounset                              # Treat unset variables as an error
pushd $(dirname $0) 2>&1 >/dev/null
SCRIPT_PATH=$(pwd -P .)
popd 2>&1 >/dev/null
DOXYGEN=/usr/local/bin/doxygen
APPLEDOC=/usr/local/bin/appledoc

function usage ()
{
	cat <<- EOT

  Usage :  ${0##/*/} -s <dir> -x <path> -f <name> -c <name> -d <name>

  Options: 
  -s <dir>      The directory containing the source header files
  -x <path>     The path to the index page
  -f <name>     The name of the framework (appears on doc pages)
  -c <name>     The company/organisation name
  -d <name>     The company id in the format 'com.dervishsoftware'
  -t appledoc|doxygen  The output type (default = appledoc)
  -h            Display this message
	EOT
}    # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------
FRAMEWORK_SOURCE=
INDEX_PATH=
FRAMEWORK=
COMPANY=
COMPANY_ID=
OUTPUT_TYPE=appledoc

while getopts ":hvs:x:f:c:d:t:" opt
do
    case $opt in

        s ) 
            FRAMEWORK_SOURCE=$OPTARG 
            ;;
        x ) 
            INDEX_PATH=$OPTARG 
            ;;
        f ) 
            FRAMEWORK=$OPTARG 
            ;;
        c ) 
            COMPANY=$OPTARG 
            ;;
        d ) 
            COMPANY_ID=$OPTARG
            ;;
        t ) 
            OUTPUT_TYPE=$OPTARG
            ;;
        h ) 
            usage
            exit 0   
            ;;
        \? ) 
            echo -e "\n  Option does not exist : $OPTARG\n"
            usage
            exit 1
            ;;

esac    # --- end of case ---
done
shift $(($OPTIND-1))

if [[ -z "${FRAMEWORK_SOURCE}" || -z "${FRAMEWORK}" || -z "${COMPANY}" || -z "${COMPANY_ID}" ]]; then
    echo "Missing parameters."
    usage
    exit 1
fi
pushd "${FRAMEWORK_SOURCE}" 2>&1 >/dev/null
FRAMEWORK_SOURCE=$(pwd -P .)
popd 2>&1 >/dev/null

if [[ "${OUTPUT_TYPE}" != "appledoc" && "${OUTPUT_TYPE}" != "doxygen" ]]; then
    echo "Output type must be 'appledoc' or 'doxygen'"
    usage
    exit 1
fi

VERBOSITY=0 # 0 (silent) to 6 (most verbose) -- verbosity of appledoc

#PUBLISH_OPTION=--publish-docset
PUBLISH_OPTION=

DOCSET_NAME=${COMPANY_ID}.${FRAMEWORK}.docset
DOCSET_FEED_URL=http://www.dervishsoftware/docsets
if [[ -d "${HOME}/Library/Caches" ]]; then
    BASE_TEMP_DIR="${HOME}/Library/Caches"
else
    BASE_TEMP_DIR=/tmp
fi
TEMP_DIR=`mktemp -d ${BASE_TEMP_DIR}/GenerateDocs.XXXXXX` || exit 1
GENERATION_DIR="${TEMP_DIR}/headers"
OUTPUT_DIR="${TEMP_DIR}/${OUTPUT_TYPE}"

if ! cp ${INDEX_PATH} ${TEMP_DIR}; then
    echo "Could not find index file '${INDEX_PATH}'" >&2
    exit 2
fi
INDEX_FILE=$(basename "${INDEX_PATH}")

mkdir -p "${GENERATION_DIR}"

# cd to generation dir
if ! cd "${GENERATION_DIR}"; then
    echo "Could not create directory '${GENERATION_DIR}'" >&2
    exit 2
fi

echo "Converting TomDoc headers in ${FRAMEWORK_SOURCE}..."
"${SCRIPT_PATH}/tomdoc_converter_objc.py" "--${OUTPUT_TYPE}" -o "${GENERATION_DIR}" "${FRAMEWORK_SOURCE}"

if [[ "${OUTPUT_TYPE}" = "appledoc" ]]; then
    # As of 31 August, 2013, these extra flags to appledoc are only supported in the version of
    # appledoc available here: https://github.com/antmd/appledoc:
    # --ignore-symbol <glob>
    # --require-leader-for-local-crossrefs
    # A pull request to the parent repository has been made

    APPLEDOC_EXTRA_FLAGS=
    if appledoc --help | grep 'ignore-symbol' >/dev/null; then
        APPLEDOC_EXTRA_FLAGS="${APPLEDOC_EXTRA_FLAGS} --ignore-symbol """*Deprecated*""
    fi
    if appledoc --help | grep 'require-leader-for-local-crossrefs' >/dev/null; then
        APPLEDOC_EXTRA_FLAGS=${APPLEDOC_EXTRA_FLAGS}" --require-leader-for-local-crossrefs"
    fi

    echo "Generating DocSet using appledoc..."
    # Call appledoc to generate and install the docset
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
        ${APPLEDOC_EXTRA_FLAGS} \
        --index-desc "../${INDEX_FILE}" \
        --verbose $VERBOSITY \
        "${GENERATION_DIR}"
else # Doxygen
    export DOCSET_PUBLISHER_ID="${COMPANY_ID}"
    export DOCSET_BUNDLE_ID="${COMPANY_ID}.${FRAMEWORK}"
    export FRAMEWORK
    export OUTPUT_DIRECTORY=~/Downloads

    # Generate the index page
cat > mainpage.h <<EOF
/*! \\mainpage ${FRAMEWORK} Main Page
 *
EOF
    cat < "../${INDEX_FILE}" >> mainpage.h
cat >> mainpage.h <<EOF
*/
EOF
    ${DOXYGEN} "${SCRIPT_PATH}/HTML.Doxyfile"
fi

echo "Cleaning up..."
cd ${SCRIPT_PATH}
rm -rf ${TEMP_DIR}

echo "Installed docset for ${FRAMEWORK} to ~/Library/Developer/Shared/Documentation/DocSets/${DOCSET_NAME}"
