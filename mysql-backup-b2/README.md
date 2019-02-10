# mysql-backup-b2

Backup compressed MySQL database to [B2 Cloud Storage](https://www.backblaze.com/b2/cloud-storage.html) (supports periodic backups & mutli files)

## Basic usage

```sh
$ docker run -e B2_ID=key-id -e B2_APP_KEY=app-key -e B2_BUCKET=my-bucket -e B2_PREFIX=backup -e B2_FILENAME=appdb -e MYSQL_USER=user -e MYSQL_PASSWORD=password -e MYSQL_HOST=localhost danstreeter/mysql-backup-b2
```


## Environment variables

- `MYSQLDUMP_OPTIONS` mysqldump options (default: --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384)
- `MYSQLDUMP_DATABASE` list of databases you want to backup (default: --all-databases)
- `MYSQL_HOST` the mysql host *required*
- `MYSQL_PORT` the mysql port (default: 3306)
- `MYSQL_USER` the mysql user *required*
- `MYSQL_PASSWORD` the mysql password *required*
- `B2_ID` your B2 Cloud Key ID access key *required*
- `B2_APP_KEY` your B2 Cloud Application key *required*
- `B2_BUCKET` your B2 Cloud bucket name *required*
- `B2_PREFIX` path prefix in your bucket (default: 'backup')
- `B2_FILENAME` a consistent filename to overwrite with your backup.  If not set will use a timestamp.
- `MULTI_FILES` Allow to have one file per database if set `yes` default: no)
- `SCHEDULE` backup schedule time, see explainatons below

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).


### B2 Cloud API Keys
The API keys used require the write privileges to your target bucket. A `unauthorized` error will be returned at the get_upload_url stage if your key does not have this privilege. See https://www.backblaze.com/b2/docs/b2_get_upload_url.html for more information.