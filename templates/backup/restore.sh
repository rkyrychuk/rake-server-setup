#!/bin/sh

MYSQLROOT=%{mysql_user}
MYSQLPASS=%{mysql_password}
S3BUCKET=%{s3_bucket}
FILENAME=%{file_name}
DATABASE=%{database}

LAST_MONTH_FOLDER=`s3cmd ls s3://${S3BUCKET}/ | ruby -e "puts STDIN.read.lines.map{|l| l.match(/s3:\/\/(.+?)\d{4}-\d{2}\//).to_s}.compact.sort.last;"`
LAST_DAY_FOLDER=`s3cmd ls ${LAST_MONTH_FOLDER} | ruby -e "puts STDIN.read.lines.map{|l| l.match(/s3(.+?)\d{4}-\d{2}\/\d{2}\//).to_s }.compact.sort.last;"`
LAST_BACKUP_FILE=`s3cmd ls ${LAST_DAY_FOLDER} | grep ${FILENAME} | ruby -e "puts STDIN.read.lines.map{|l| l.match(/s3:\/\/(.+).tar.gz/).to_s}.sort.last.match(/\/([^\/]+?)$/)[1]$
s3cmd get ${LAST_DAY_FOLDER}${LAST_BACKUP_FILE} --force
tar -xf ${LAST_BACKUP_FILE}
mysql --user ${MYSQLROOT} --password=${MYSQLPASS} ${DATABASE} < ${FILENAME}.sql

