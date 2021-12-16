#!/bin/bash

# Script to upload multiple images to a.bmstatic.com using image-uploader.bookmate.services
#
# Usage:
# script <images_root_directory>
#
# Required packages:
#   GNU/Linux: curl, sed, coreutils, findutils

# Default settings
endpoint="http://image-uploader.bookmate.services/upload"

app_curl="/usr/bin/curl"
app_sed="/usr/bin/sed"
app_tail="/usr/bin/tail"
app_find="/usr/bin/find"
app_stat="/usr/bin/stat"

extensions="jpg|jpeg|png|gif|svg|webp"

output_failed="upload.failed"
output_success="upload.success"

# Check for required applications
check_app()
{
    if [ $# -ne 1 ]; then
        echo "Usage: check_app <app_path>"
        exit 1
    fi

    local app="${1}"

    if [ ! -x "${app}" ]; then
        echo "Application '${app}' is not found"
        exit 1
    fi
}

check_apps()
{
    if [ $# -ne 1 ]; then
        echo "Usage: check_apps <apps_list>"
        exit 1
    fi

    for app in ${1}; do
        check_app "${app}"
    done
}

check_apps "${app_curl} ${app_sed} ${app_tail} ${app_find} ${app_stat}"

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
    if [ $# -ne 2 ]; then
        echo "Usage: curl_upload_file <image> <endpoint>"
        exit 1
    fi

    local image="${1}"
    local endpoint="${2}"

    "${app_curl}" -is -X POST -H 'Content-Type: multipart/form-data' -F "data=@${image}" "${endpoint}"
}

size_print()
{
    if [ $# -ne 1 ]; then
        echo "Usage: size_print <bytes>"
        exit 1
    fi

    local bytes=${1}

    local div=$((1024 * 1024 * 1024))
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
    if [ $# -ne 1 ]; then
        echo "Usage: fsize_bytes <file>"
        exit 1
    fi

    local bytes
    bytes=$("${app_stat}" -c '%s' "${1}")

    echo "${bytes}"
}

fsize_print()
{
    if [ $# -ne 1 ]; then
        echo "Usage: fsize_print <file>"
        exit 1
    fi

    local bytes
    bytes=$(fsize_bytes "${1}")

    size_print ${bytes}
}

image_url()
{
    if [ $# -ne 1 ]; then
        echo "Usage: image_url <curl_output>"
        exit 1
    fi

    # 1. Get last line in curl output
    # 2. Get image url from ["<url here>"]
    "${app_tail}" -n 1 <<< "${1}" | "${app_sed}" -nr 's/\[\"(.*)\"\]/\1/p'
}

http_codes_list()
{
    if [ $# -ne 1 ]; then
        echo "Usage: http_codes_list <curl_output>"
        exit 1
    fi

    # 1. Remove CR from curl output
    # 2. Print HTTP ret codes after 'HTTP/1.1' pattern
    "${app_sed}" 's/\r//g'  <<< "${1}" | "${app_sed}" -nr "s/HTTP\/[0-9]\.[0-9] (.*)/\1/p"
}

http_code()
{
    if [ $# -ne 1 ]; then
        echo "Usage: http_code <curl_output>"
        exit 1
    fi

    # Print HTTP code from '200 OK' pattern
    "${app_sed}" -nr 's/([0-9]{3}).*/\1/p' <<< "${1}"
}

find_images()
{
    if [ $# -ne 2 ]; then
        echo "Usage: find_images <images_root_dir> <extensions>"
        exit 1
    fi

    local images_root_dir="${1}"
    local extensions="${2}"

    "${app_find}" "${images_root_dir}/" -type f -regextype posix-egrep -iregex ".*\.(${extensions})$"
}

print_num_elements()
{
    if [ $# -ne 2 ]; then
        echo "Usage: print_num_elements <array> <num>"
        exit 1
    fi

    local array="${1}"
    local num=${2}
    local curr=0

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
    if [ $# -ne 1 ]; then
        echo "Usage:files_size <array>"
        exit 1
    fi

    local files="${1}"
    local bytes=0

    for f in ${files}; do
        fsize=$(fsize_bytes "${f}")
        bytes=$((bytes + fsize))
    done

    echo ${bytes}
}

# Parse command line parameters
if [ -z "${1}" ]; then
    print_help
    exit 1
fi

images_root_dir="${1}"

# Check command line parameters
if [ ! -d "${images_root_dir}" ]; then
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
    read -rp "Please enter 'y' or 'n' [Ctrl+C to exit]: " yn
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
    http_ret=$(http_codes_list "${curl_output}" | "${app_tail}" -n 1)
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
