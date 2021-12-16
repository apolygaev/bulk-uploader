#!/bin/bash

# Script to upload multiple images to a.bmstatic.com using image-uploader.bookmate.services
#
# Usage:
# script <images_root_directory>
#
# Required packages:
# curl, sed, coreutils, findutils

# Default settings
endpoint="http://image-uploader.bookmate.services/upload"
app_curl="/usr/bin/curl"

extensions="jpg|jpeg|png|gif|svg|webp"

output_failed="upload.failed"
output_success="upload.success"

# Check defaults
if [ ! -x "${app_curl}" ]; then
    echo "Please install 'curl' package"
    exit 1
fi

# Help function
print_help()
{
    echo "A script to upload images to a.bmstatic.com using endpoint: '${endpoint}'"
    echo "Usage:"
    echo "${0} <images_root_directory>"
}

# Other functions
curl_upload_file()
{
    "${app_curl}" -is -X POST -H 'Content-Type: multipart/form-data' -F "data=@${image}" "${endpoint}"
}

size_print()
{
    bytes=${1}

    div=$((1024 * 1024 * 1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)).$(( bytes % div)) GB"
        return 0
    fi

    div=$((1024 * 1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)).$(( bytes % div)) MB"
        return 0
    fi

    div=$((1024))
    if [ ${bytes} -ge ${div} ]; then
        echo "$((bytes / div)) KB"
        return 0
    fi

    echo "${bytes}"
}

fsize_bytes()
{
    stat -c '%s' "${1}"
}

fsize_print()
{
    bytes=$(fsize_bytes "${1}")
    size_print ${bytes}
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

find_images()
{
    images_root_dir="${1}"
    extensions="${2}"

    find "${images_root_dir}/" -type f -regextype posix-egrep -iregex ".*\.(${extensions})$"
}

print_num_elements()
{
    array="${1}"
    num=${2}
    curr=0

    for n in ${array}; do
        if [ ${curr} -lt ${num} ]; then
            echo "${n}"
        else
            return 0
        fi

        curr=$((curr + 1))
    done
}

files_size()
{
    files="${1}"
    bytes=0

    for f in ${files}; do
        fsize=$(fsize_bytes "${f}")
        bytes=$((bytes + fsize))
    done

    echo ${bytes}
    return ${bytes}
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
echo "Upload endpoint:       ${endpoint}"
echo "Images root directory: ${images_root_dir}"
echo "Images extensions:     ${extensions}"

# Find images to upload
echo "Searching for images to upload ..."
images=$(find_images "${images_root_dir}" "${extensions}")

images_num=$(wc -l <<< "${images}")
images_size=$(files_size "${images}")

echo "Images found: ${images_num} Size: $(size_print ${images_size})"

# Show up to 5 images samples
[ ${images_num} -lt 5 ] && num_to_show=${images_num} || num_to_show=5

echo "First ${num_to_show} samples:"
print_num_elements "${images}" ${num_to_show}

# Get user confirmation
yn="nope"

while [ "${yn}" != "n" ] && [ "${yn}" != "y" ]
do
    echo "Please confirm images upload:"
    echo -e "\tEndpoint: ${endpoint}"
    echo -e "\tImages:   ${images_num}"
    echo -e "\tSize:     $(size_print "${images_size}")"
    read -p "Please enter 'y' or 'n' [Ctrl+C to exit]: " yn
done

if [ "${yn}" == "n" ]; then
    echo "Upload rejected by user"
    exit 1
fi

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
