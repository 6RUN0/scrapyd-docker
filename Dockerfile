FROM python:3.10-slim
# Install scrapyd
ENV SCRAPYD_HOME_DIR ${SCRAPYD_HOME_DIR:-/home/scrapyd}
ENV SCRAPYD_GROUP ${SCRAPYD_GROUP:-scrapyd}
ENV SCRAPYD_GID ${SCRAPYD_GID:-10000}
ENV SCRAPYD_USER ${SCRAPYD_USER:-scrapyd}
ENV SCRAPYD_UID ${SCRAPYD_UID:-10000}
ENV SCRAPYD_PORT ${SCRAPYD_PORT:-6800}
WORKDIR $SCRAPYD_HOME_DIR
RUN \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends tini gosu; \
    pip install scrapyd; \
    mkdir -p $SCRAPYD_HOME_DIR; \
    addgroup --gid $SCRAPYD_GID $SCRAPYD_GROUP; \
    adduser --uid $SCRAPYD_UID --home $SCRAPYD_HOME_DIR --ingroup $SCRAPYD_GROUP $SCRAPYD_USER; \
    chown $SCRAPYD_USER:$SCRAPYD_GROUP $SCRAPYD_HOME_DIR;
# Configure scrapyd
RUN \
    set -eux; \
    conf_dir=/etc/scrapyd/conf.d; \
    mkdir -p $conf_dir; \
    echo "[scrapyd]" > $conf_dir/000_bind.conf; \
    echo "bind_address = 0.0.0.0" >> $conf_dir/000_bind.conf; \
    echo "http_port = $SCRAPYD_PORT" >> $conf_dir/000_bind.conf; \
    echo "[scrapyd]" > $conf_dir/000_jobstorage.conf; \
    echo "jobstorage = scrapyd.jobstorage.SqliteJobStorage" >> $conf_dir/000_jobstorage.conf;
# Build run script
RUN \
    set -eux; \
    runner=/usr/local/bin/scrapyd-runner; \
    echo "#!/bin/sh -eux" > $runner; \
    echo "find \"$SCRAPYD_HOME_DIR\" \! -user \"$SCRAPYD_USER\" -exec chown $SCRAPYD_USER:$SCRAPYD_GROUP '{}' +" >> $runner; \
    echo "gosu $SCRAPYD_USER:$SCRAPYD_GROUP scrapyd" >> $runner; \
    chmod +x $runner;
# Install addition plugins
RUN \
    set -eux; \
    pip install \
       playwright \
       pymongo; \
    playwright install;
# Clean
RUN \
    set -eux; \
    rm -rf /var/lib/apt/lists/*;
VOLUME $SCRAPYD_HOME_DIR
EXPOSE $SCRAPYD_PORT
ENTRYPOINT ["tini", "--"]
CMD ["scrapyd-runner"]
