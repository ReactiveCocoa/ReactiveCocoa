#!/bin/bash - 

# Generate and install docset for a framework

set -o nounset                              # Treat unset variables as an error
cd $(dirname $0)
SCRIPT_PATH=$(pwd -P .)

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

while getopts ":hvs:x:f:c:d:" opt
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
TEMP_DIR="${BASE_TEMP_DIR}/${FRAMEWORK}.$$"
GENERATION_DIR="${TEMP_DIR}/headers"
OUTPUT_DIR="${TEMP_DIR}/appledoc"
APPLEDOC=/usr/local/bin/appledoc

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

if [[ -d "${GENERATION_DIR}" ]]; then
    rm -rf "${GENERATION_DIR}"
fi
mkdir "${GENERATION_DIR}"

cd "${GENERATION_DIR}"
echo "Converting TomDoc headers in ${FRAMEWORK_SOURCE}..."
"${SCRIPT_PATH}/tomdoc_converter_objc.py" --appledoc -o "${GENERATION_DIR}" "${FRAMEWORK_SOURCE}"

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
    --index-desc "${INDEX_PATH}" \
    --verbose $VERBOSITY \
    "${GENERATION_DIR}"

echo "Cleaning up..."
cd ${SCRIPT_PATH}
rm -rf ${GENERATION_DIR}

echo "Installed docset for ${FRAMEWORK} to ~/Library/Developer/Shared/Documentation/DocSets/${DOCSET_NAME}"
