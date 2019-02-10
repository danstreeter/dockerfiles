#! /bin/sh
# Sets the script to fail at any point of the pipe. See https://unix.stackexchange.com/a/385100/332956
set -e -o pipefail -o errexit

if [ "${B2_ID}" == "**None**" ]; then
  echo "Warning: You did not set the B2_ID environment variable."
fi

if [ "${B2_APP_KEY}" == "**None**" ]; then
  echo "Warning: You did not set the B2_APP_KEY environment variable."
fi

if [ "${B2_BUCKET}" == "**None**" ]; then
  echo "You need to set the B2_BUCKET environment variable."
  exit 1
fi

if [ "${MYSQL_HOST}" == "**None**" ]; then
  echo "You need to set the MYSQL_HOST environment variable."
  exit 1
fi

if [ "${MYSQL_USER}" == "**None**" ]; then
  echo "You need to set the MYSQL_USER environment variable."
  exit 1
fi

if [ "${MYSQL_PASSWORD}" == "**None**" ]; then
  echo "You need to set the MYSQL_PASSWORD environment variable or link to a container named MYSQL."
  exit 1
fi

MYSQL_HOST_OPTS="-h $MYSQL_HOST -P $MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD"
DUMP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")


b2_authenticate() {
  AUTH_RESPONSE=`curl --silent https://api.backblazeb2.com/b2api/v2/b2_authorize_account -u "${B2_ID}:${B2_APP_KEY}"`
  AUTH_TOKEN=`echo $AUTH_RESPONSE | jq -re ".authorizationToken"` || (echo "Failed to extract auth token (authorize_account):" $(echo $AUTH_RESPONSE | jq -re ".code") && exit 1)
  API_URL=`echo $AUTH_RESPONSE | jq -re ".apiUrl"` || (echo "Failed to extract B2 API URL:" $(echo $AUTH_RESPONSE | jq -re ".code") && exit 1)
  BUCKET_ID=`echo $AUTH_RESPONSE | jq -re ".allowed.bucketId"` || (echo "Failed to extract bucket ID:" $(echo $AUTH_RESPONSE | jq -re ".code") && exit 1)
}

b2_get_upload_url() {
  echo "Getting upload url and upload token"
  UPLOAD_URL_RESPONSE=`curl --silent -H "Authorization: $AUTH_TOKEN" -d "{\"bucketId\": \"${BUCKET_ID}\"}" $API_URL/b2api/v2/b2_get_upload_url`
  UPLOAD_URL=`echo $UPLOAD_URL_RESPONSE | jq -re ".uploadUrl"` || (echo "Failed to extract Upload URL:" $(echo $UPLOAD_URL_RESPONSE | jq -re ".code") && exit 1)
  UPLOAD_AUTH_TOKEN=`echo $UPLOAD_URL_RESPONSE | jq -re ".authorizationToken"` || (echo "Failed to extract auth token (get_upload_url):" $(echo $UPLOAD_URL_RESPONSE | jq -re ".code") && exit 1)
}

copy_b2 () {
  SRC_FILE=$1
  DEST_FILE=$2

  if [ -z "$API_URL" ]; then
    echo "Authenticating and setting up B2 connection"
    b2_authenticate
  fi
  if [ -z "$UPLOAD_AUTH_TOKEN" ]; then
    b2_get_upload_url
  fi

  FILESHA=`sha1sum $SRC_FILE | awk '{print $1;}'`
  FILESIZE=`stat -c %s $SRC_FILE`

  echo "Uploading ${SRC_FILE} to ${B2_BUCKET}/${B2_PREFIX}/${DEST_FILE} on B2"
  UPLOAD_RESULT=`curl \
    --silent \
    -w "%{http_code}" \
    -H "Authorization: $UPLOAD_AUTH_TOKEN" \
    -H "X-Bz-File-Name: $B2_PREFIX/$DEST_FILE" \
    -H "Content-Type: application/gzip" \
    -H "Content-Length: $FILESIZE" \
    -H "X-Bz-Content-Sha1: $FILESHA" \
    -H "X-Bz-Info-Author: unknown" \
    --data-binary "@$SRC_FILE" \
    $UPLOAD_URL`

  UPLOAD_RESULT_HTTP_STATUSCODE=`echo $UPLOAD_RESULT | rev | cut -c -3 | rev`
  UPLOAD_RESULT_JSON=`echo $UPLOAD_RESULT | rev | cut -c 4-99999 | rev`

  if [ "${UPLOAD_RESULT_HTTP_STATUSCODE}" != 200 ]; then
    UPLOAD_SHA=`echo $UPLOAD_RESULT_JSON | jq -re ".contentSha1"` || (echo "Error uploading $DEST_FILE on B2: "$(echo $UPLOAD_RESULT_JSON | jq -re ".code") && exit 1)
  fi

  echo "Upload of ${SRC_FILE} to ${B2_BUCKET}/${B2_PREFIX}/${DEST_FILE} on B2 Complete"

  rm $SRC_FILE
}
# Multi file: yes
if [ ! -z "$(echo $MULTI_FILES | grep -i -E "(yes|true|1)")" ]; then
  if [ "${MYSQLDUMP_DATABASE}" == "--all-databases" ]; then
    DATABASES=`mysql $MYSQL_HOST_OPTS -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys|innodb)"`
  else
    DATABASES=$MYSQLDUMP_DATABASE
  fi

  for DB in $DATABASES; do
    echo "Creating individual dump of ${DB} from ${MYSQL_HOST}..."

    DUMP_FILE="/tmp/${DB}.sql.gz"

    mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS --databases $DB | gzip > $DUMP_FILE

    if [ $? == 0 ]; then
      if [ "${B2_FILENAME}" == "**None**" ]; then
        B2_FILE="${DUMP_START_TIME}.${DB}.sql.gz"
      else
        B2_FILE="${B2_FILENAME}.${DB}.sql.gz"
      fi

      copy_b2 $DUMP_FILE $B2_FILE
    else
      >&2 echo "Error creating dump of ${DB}"
    fi
  done
# Multi file: no
else
  echo "Creating dump for ${MYSQLDUMP_DATABASE} from ${MYSQL_HOST}..."

  DUMP_FILE="/tmp/dump.sql.gz"

  mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS $MYSQLDUMP_DATABASE | gzip > $DUMP_FILE

  if [ $? -eq 0 ]; then

    if [ "${B2_FILENAME}" == "**None**" ]; then
      B2_FILE="${DUMP_START_TIME}.dump.sql.gz"
    else
      B2_FILE="${B2_FILENAME}.sql.gz"
    fi
    copy_b2 $DUMP_FILE $B2_FILE

  else
    >&2 echo "Error creating dump of all databases"
  fi
fi

echo "SQL backup process complete"