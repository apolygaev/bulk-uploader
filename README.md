# Description
Perform bulk upload using internal image-uploader service

# Endpoint used
http://image-uploader.bookmate.services/

# Manual upload with curl
curl -is -X POST -H 'Content-Type: multipart/form-data' -F "data=@image.jpg" http://image-uploader.bookmate.services/upload

# Script usage
bulk-uploader <images_dir>

# Output files
* upload.success - a list of uploaded images with remote url: 'image_path': 'remote_url'
* upload.failed  - a list of failed images with HTTP response code: 'image_path': 'HTTP response code'
