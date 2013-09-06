#!/bin/sh

MYSQLROOT=%{mysql_user}
MYSQLPASS=%{mysql_password}
S3BUCKET=%{s3_bucket}
FILENAME=%{file_name}
DATABASE=%{database}

MYSQLDUMPPATH=/usr/bin/
TMP_PATH=/tmp/
DATESTAMP=$(date +"-%%Y-%%m-%%d_%%H%%M%%S")
MONTH=$(date +"%%Y-%%m")
DAY=$(date +"%%d")

${MYSQLDUMPPATH}mysqldump --single-transaction --user=${MYSQLROOT} --password=${MYSQLPASS} ${DATABASE} > ${TMP_PATH}${FILENAME}.sql
tar -C ${TMP_PATH} -czf ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.gz ${FILENAME}.sql
s3cmd put -f ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.gz s3://${S3BUCKET}/${MONTH}/${DAY}/

rm ${TMP_PATH}${FILENAME}.sql
rm ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.g
