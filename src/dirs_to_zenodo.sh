#!/usr/bin/env bash
ZENODO_ENDPOINT="https://zenodo.org"
DEPOSITION_PREFIX="${ZENODO_ENDPOINT}/api/deposit/depositions"

get_deposition_endpoint() {
    # $1 is the ORIGINAL_ID, if there is an existing deposition
    ORIGINAL_ID="$1"
    if [ -z "${ORIGINAL_ID}" ]; then # Only get latest id when provided an original one
	#echo "Creating new deposition"
	DEPOSITION_ENDPOINT="${DEPOSITION_PREFIX}"
    else # Update existing dataset
	#echo "Creating new version"
	LATEST_ID=$(curl "${ZENODO_ENDPOINT}/records/${ORIGINAL_ID}/latest" |
			grep records | sed 's/.*href=".*\.org\/records\/\(.*\)".*/\1/')
	DEPOSITION_ENDPOINT="${DEPOSITION_PREFIX}/${LATEST_ID}/actions/newversion"
    fi
    echo ${DEPOSITION_ENDPOINT}
}

validate_token() {
    if [ -z "${ZENODO_TOKEN}" ]; then # Check Zenodo Token
	echo "Access token not available"
	exit 1
    else
	echo "Access token found."
    fi
}

create_new_deposition(){
    # Create new deposition
    DEPOSITION=$(curl -H "Content-Type: application/json" \
		      -X POST\
		      --data "{}" \
		      "${DEPOSITION_ENDPOINT}?access_token=${ZENODO_TOKEN}"\
		     | jq .id)
    echo "${DEPOSITION}"
}

get_bucket(){
    # Variables
    BUCKET_DATA=$(curl "${DEPOSITION_PREFIX}/${1}?access_token=${ZENODO_TOKEN}")
    BUCKET=$(echo "${BUCKET_DATA}" | jq --raw-output .links.bucket)

    if [ "${BUCKET}" = "null" ]; then
	echo "Could not find URL for upload. Response from server:"
	echo "${BUCKET_DATA}"
	exit 1
    fi

    echo ${BUCKET}
}

upload_file() {
    # Upload file, it only keeps the filename if a filepath is provided
    # $1 is $BUCKET, where to upload the file
    # $2 is the $FILEPATH, the full path of the file to upload
    FILENAME="${2##*/}"
    echo "Uploading $2 to bucket $1 as ${FILENAME}"
    curl --retry 5 \
	 --retry-delay 5 \
	 -o /dev/null \
	 --upload-file "${2}" \
	 "${1}/${FILENAME}?access_token=${ZENODO_TOKEN}"
}
upload_metadata() {
    # Upload Metadata
    # $1 is the DEPOSITION ID (Zenodo identifier, composed of only digits)
    # $2 is the experiment name, which will determine the title
    echo -e "{\"metadata\": {
		     \"title\": \"${2}\",
		     \"creators\": [{\"name\": \"Alán F. Muñoz\"},{\"name\": \"Peter S. Swain\"},{ \"name\": \"Swain Lab\"}],
	\"description\":\"High throughput time lapse experiment. Details can be found on the 'txt' files inside.\",
\"upload_type\": \"dataset\",
\"access_right\": \"open\",
\"keywords\": [\"S. cerevisiae\",\"yeast\",\"microfluidics\",\"microscopy\",\"raw\",\"swainlab\",\"timelapse\",\"aliby\"]
		 }}" > metadata.json

    NEW_DEPOSITION_ENDPOINT="${DEPOSITION_PREFIX}/${1}"
    echo "Uploading file to ${NEW_DEPOSITION_ENDPOINT}"
    curl -H "Content-Type: application/json" \
	 -X PUT\
	 --data @metadata.json \
	 "${NEW_DEPOSITION_ENDPOINT}?access_token=${ZENODO_TOKEN}"
}

publish_deposition(){
    # Publish deposition
    # $1 is the NEW_DEPOSITION_ENDPOINT
    echo "Publishing to ${1}"
    curl -H "Content-Type: application/json" \
	 -X POST\
	 --data "{}"\
	 "${DEPOSITION_PREFIX}/${1}/actions/publish?access_token=${ZENODO_TOKEN}"\
	| jq .id
}


i=1
prev_name=""

validate_token

pwd
MANIFEST_FILE="manifest.csv"
echo "experiment,part,deposition" > $MANIFEST_FILE
while read line; do
    array=($line)
    expt_name=$(basename $(dirname "${array[0]}"))
    if [[ "${expt_name}" == "${prev_expt}" ]]; then
	i=$(( $i + 1 ))
    else
	i=1
    fi

    DEPOSITION_ENDPOINT=$(get_deposition_endpoint "")
    echo "Deposition endpoint is ${DEPOSITION_ENDPOINT}"

    NEW_DEPOSITION=$(create_new_deposition "${DEPOSITION_ENDPOINT}")
    echo "New deposition is ${NEW_DEPOSITION}"
    echo "${expt_name},${i},${NEW_DEPOSITION}" >> manifest.csv

    upload_metadata ${NEW_DEPOSITION} "${expt_name} (part ${i})"
    BUCKET=$(get_bucket ${NEW_DEPOSITION})
    printf "Processing ${expt_name}, chunk ${i}\n"
    for FILE in "${array[@]}"; do
	echo "Uploading ${FILE}"
	if [[ -d "$FILE" ]] ; then
	    echo "UPLOADING ZIP"
	    ZIPFILE="${FILE%.zarr}.zip" # Replace suffix with zip
	    zip -0 -r "${ZIPFILE}" "${FILE}"
	    upload_file ${BUCKET} ${ZIPFILE}
	    rm "${ZIPFILE}"
	else
	    upload_file ${BUCKET} ${FILE}
	fi
    done
    echo "Publishing deposition ${NEW_DEPOSITION}"
    publish_deposition "${NEW_DEPOSITION}"
    prev_expt="${expt_name}"
done < "${1}"
