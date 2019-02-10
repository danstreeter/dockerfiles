FROM alpine:latest
LABEL maintainer="Dan Streeter <dan@danstreeter.co.uk>"
LABEL version=1.0.0

ADD install.sh install.sh
RUN sh install.sh && rm install.sh

ENV MYSQLDUMP_OPTIONS --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384
ENV MYSQLDUMP_DATABASE --all-databases
ENV MYSQL_HOST **None**
ENV MYSQL_PORT 3306
ENV MYSQL_USER **None**
ENV MYSQL_PASSWORD **None**

ENV B2_ID **None**
ENV B2_APP_KEY **None**
ENV B2_BUCKET **None**
ENV B2_FILENAME **None**
ENV B2_PREFIX 'backup'

ENV MULTI_FILES no
ENV SCHEDULE **None**

ADD run.sh run.sh
ADD backup.sh backup.sh

CMD ["sh", "run.sh"]
