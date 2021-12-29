#!/usr/bin/env bash

# ===============> How to:
# Put this script 'update_script.sh' in the directory where the cert.pem & privkey.pem is written by LetsEncrypt
# Ensure it has execute permissions by the LetsEncrypt process
# Whenever LetsEncrypt updates the certificate the script will be executed by LetsEncrypt
# Update the configuration variables below

# Configuration

IPMI_HOSTNAME='<HOSTNAME>'
USERNAME='<USERNAME>'
PASSWORD='<PASSWORD>'

# Validation

curl "https://${IPMI_HOSTNAME}/" -vvvvv -skSL -X GET 1>/dev/null 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Could not connecto to https://${IPMI_HOSTNAME} using cURL."
  echo 'Is cURL installed and the hostname correct?'
  exit 1
fi

printf 'hi' | grep 'hi' 1>/dev/null 2>/dev/null

if [ $? -ne 0 ]; then
  echo 'Could not grep, is grep installed?'
  exit 1
fi

COOKIES_FILE=`mktemp`

if [ $? -ne 0 ]; then
  echo 'Could not create temporary directory for cookie jar, is mktemp installed?'
  exit 1
fi

CONTENT_FILE=`mktemp`

# Ensure cleanup after script execution regardless of outcome
function post_script_cleanup {
  rm -rf "${COOKIES_FILE}" 1>/dev/null 2>/dev/null
  rm -rf "${CONTENT_FILE}" 1>/dev/null 2>/dev/null
}

trap post_script_cleanup INT TERM EXIT

touch "${COOKIES_FILE}" && touch "${CONTENT_FILE}"


# Runtime variables

LETS_ENCRYPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CERT_FILE="/${LETS_ENCRYPT_PATH}/cert.pem"

ls "$CERT_FILE" 1>/dev/null 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Could not find the LetsEncrypt cert file @ '$CERT_FILE'"
  exit 1
fi

KEY_FILE="/${LETS_ENCRYPT_PATH}/privkey.pem"

echo '' && echo '==========> Login to BMC:'

curl "https://${IPMI_HOSTNAME}/cgi/login.cgi" -vvvvv -skSL -X POST -H 'Content-Type: application/x-www-form-urlencoded' -d "name=$USERNAME" -d "pwd=$PASSWORD" -b "${COOKIES_FILE}" -c "${COOKIES_FILE}" -o "${CONTENT_FILE}"
cat "${CONTENT_FILE}"

sleep 1

echo '' && echo '' && echo '==========> Load top menu:'

curl "https://${IPMI_HOSTNAME}/cgi/url_redirect.cgi?url_name=topmenu" -vvvvv -skSL -X GET -b "${COOKIES_FILE}" -c "${COOKIES_FILE}" -o "${CONTENT_FILE}"
cat "${CONTENT_FILE}"

sleep 1

echo '' && echo '' && echo '==========> Upload SSL certificate and private key:'

curl "https://${IPMI_HOSTNAME}/cgi/upload_ssl.cgi" -vvvvv -skSL -X POST -H 'Expect:' -H 'Content-Type: multipart/form-data' -F 'cert_file'=@"${CERT_FILE}" -F 'key_file'=@"${KEY_FILE}" -b "${COOKIES_FILE}" -c "${COOKIES_FILE}" -o "${CONTENT_FILE}"
cat "${CONTENT_FILE}"

sleep 1

echo '' && echo '' && echo '==========> Approve the uploaded SSL certificate and private key:'

curl "https://${IPMI_HOSTNAME}/cgi/ipmi.cgi" -vvvvv -skSL -X POST -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -d 'SSL_VALIDATE.XML=(0,0)' -d 'time_stamp=sometime' -d '_=' -b "${COOKIES_FILE}" -c "${COOKIES_FILE}" -o "${CONTENT_FILE}"
cat "${CONTENT_FILE}"

sleep 1

echo '' && echo '' && echo '==========> Reboot the BMC:'

curl "https://${IPMI_HOSTNAME}/cgi/BMCReset.cgi" -vvvvv -skSL -X POST -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -d 'time_stamp=sometime' -d '_=' -b "${COOKIES_FILE}" -c "${COOKIES_FILE}" -o "${CONTENT_FILE}"
cat "${CONTENT_FILE}"

echo ''
