#!/bin/bash

# Script to upload multiple images to a.bmstatic.com using image-uploader.bookmate.services
#
# Usage:
# script <images_root_directory>
#
# Required packages:
# curl, sed, coreutils, findutils

# Default settings
endpoint="image-uploader.bookmate.services/upload"
app_curl=$(type -p curl)

output_failed="upload.failed"
output_success="upload.success"

# Check defaults
if [ -z "${app_curl}" ]; then
    echo "Please install 'curl' package"
    exit 1
fi

# Help function
function print_help()
{
    echo "A script to upload images to a.bmstatic.com using image-uploader.bookmate.services"
    echo "Usage:"
    echo "${0} <images_root_directory>"
}

# Other functions
function curl_upload_file()
{
    curl -is -X POST -H 'Content-Type: multipart/form-data' -F "data=@${image}" "${endpoint}"
}

fsize_bytes()
{
    stat -c '%s' "${1}"
}

fsize_print()
{
    bytes=$(fsize_bytes "${1}")

    div=$((1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)) KB"
        return 0
    fi

    div=$((1024 * 1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)) MB"
        return 0
    fi

    div=$((1024 * 1024 * 1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)) GB"
        return 0
    fi

    echo "${bytes}"
}

image_url()
{
    # 1. Get last line in curl output
    # 2. Get image url from ["<url here>"]
    tail -n 1 <<< "${1}" | sed -nr 's/\[\"(.*)\"\]/\1/p'
}

http_codes_list()
{
    # 1. Remove CR from curl output
    # 2. Print HTTP ret codes after 'HTTP/1.1' pattern
    sed 's/\r//g'  <<< "${1}" | sed -nr "s/HTTP\/[0-9]\.[0-9] (.*)/\1/p"
}

http_code()
{
    # Print HTTP code from '200 OK' pattern
    sed -nr 's/([0-9]{3}).*/\1/p' <<< "${1}"
}

# Parse command line parameters
if [ -z "${1}" ]; then
    print_help
    exit 1
fi

images_root_dir="${1}"

# Check command line parameters
if [ ! -d "${1}" ]; then
    echo "Directory not exists: '${images_root_dir}'"
    exit 1
fi

# Print input parameters
echo "Upload endpoint: ${endpoint}"
echo "Images root directory: ${images_root_dir}"

# Find images to upload
echo "Searching for images to upload..."
images=$(find "${images_root_dir}" -type f -name *.png)
images_num=$(wc -l <<< "${images}")

echo "Images found: ${images_num}"

# Cleanup output files
echo "Cleaning up output files: ${output_success}, ${output_failed}"
echo -n "" > "${output_success}"
echo -n "" > "${output_failed}"

# Upload images one by one
num=1

for image in $images; do
    echo -n "Uploading image (${num}/${images_num}): [$(fsize_print "${image}")]: ${image} ..."

    # Upload image using curl
    curl_output=$(curl_upload_file "${image}" "${endpoint}")
    curl_ret=$?

    # Parse curl response headers
    http_ret=$(http_codes_list "${curl_output}" | tail -n 1)
    http_ret_code=$(http_code "${http_ret}")

    # Check result
    if [ ${curl_ret} -eq 0 ] && [ ${http_ret_code} -eq 200 ]; then
        url=$(image_url "${curl_output}")

        echo "Success: HTTP: ${http_ret} Image URL: ${url}"
        echo "${image}: ${url}" >> "${output_success}"
    else
        echo "Failed: HTTP: ${http_ret} Image: ${image}"
        echo "${image}: HTTP ${http_ret}" >> "${output_failed}"
    fi

    num=$((num + 1))
done
