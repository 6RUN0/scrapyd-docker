FROM python:3.10-slim-bullseye
# Install scrapyd
# See https://scrapyd.readthedocs.io
ENV SCRAPYD_HOME_DIR ${SCRAPYD_HOME_DIR:-/home/scrapyd}
ENV SCRAPYD_WORK_DIR $SCRAPYD_HOME_DIR/data
ENV SCRAPYD_GROUP ${SCRAPYD_GROUP:-scrapyd}
ENV SCRAPYD_GID ${SCRAPYD_GID:-10000}
ENV SCRAPYD_USER ${SCRAPYD_USER:-scrapyd}
ENV SCRAPYD_UID ${SCRAPYD_UID:-10000}
ENV SCRAPYD_PORT ${SCRAPYD_PORT:-6800}
ENV PLAYWRIGHT_BROWSERS_PATH $SCRAPYD_HOME_DIR/playwright-browsers
WORKDIR $SCRAPYD_WORK_DIR
RUN \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends tini gosu lsb-release; \
    pip install scrapyd; \
    mkdir -p $SCRAPYD_HOME_DIR; \
    mkdir -p $SCRAPYD_WORK_DIR; \
    mkdir -p $PLAYWRIGHT_BROWSERS_PATH; \
    addgroup --gid $SCRAPYD_GID $SCRAPYD_GROUP; \
    adduser --uid $SCRAPYD_UID --home $SCRAPYD_HOME_DIR --ingroup $SCRAPYD_GROUP $SCRAPYD_USER; \
    chown -R $SCRAPYD_USER:$SCRAPYD_GROUP $SCRAPYD_HOME_DIR; \
    chown -R $SCRAPYD_USER:$SCRAPYD_GROUP $SCRAPYD_WORK_DIR;
# Install addition plugins
# + https://github.com/scrapy-plugins/scrapy-playwright
# + https://github.com/Gerapy/GerapyItemPipeline
RUN \
    set -eux; \
    pip install \
       scrapy-playwright \
       gerapy-item-pipeline; \
    playwright install chromium --with-deps; \
    chown -R $SCRAPYD_USER:$SCRAPYD_GROUP $PLAYWRIGHT_BROWSERS_PATH;
# Clean
RUN \
    set -eux; \
    pip cache purge; \
    apt autoclean; \
    rm -rf /root/.cache; \
    rm -rf /root/.wget*; \
    rm -rf /var/lib/apt/lists/*;
# Configure scrapyd
RUN \
    set -eux; \
    conf_dir=/etc/scrapyd/conf.d; \
    mkdir -p $conf_dir; \
    echo "[scrapyd]" > $conf_dir/000_bind.conf; \
    echo "bind_address = 0.0.0.0" >> $conf_dir/000_bind.conf; \
    echo "http_port = $SCRAPYD_PORT" >> $conf_dir/000_bind.conf; \
    echo "[scrapyd]" > $conf_dir/000_dirs.conf; \
    echo "dbs_dir = dbs" >> $conf_dir/000_dirs.conf; \
    echo "eggs_dir = eggs" >> $conf_dir/000_dirs.conf; \
    echo "logs_dir = logs" >> $conf_dir/000_dirs.conf; \
    echo "items_dir = items" >> $conf_dir/000_dirs.conf; \
    echo "[scrapyd]" > $conf_dir/000_jobstorage.conf; \
    echo "jobstorage = scrapyd.jobstorage.SqliteJobStorage" >> $conf_dir/000_jobstorage.conf; \
    runner=/usr/local/bin/scrapyd-runner; \
    echo "#!/bin/sh -ex" > $runner; \
    echo "if [ -z \"\$SCRAPYD_USERNAME\" -a -z "\$SCRAPYD_PASSWORD" ]; then" >> $runner; \
    echo "rm -f $conf_dir/999_auth.conf" >> $runner; \
    echo "else" >> $runner; \
    echo "echo \"[scrapyd]\" > $conf_dir/999_auth.conf" >> $runner; \
    echo "echo \"username = \$SCRAPYD_USERNAME\" >> $conf_dir/999_auth.conf" >> $runner; \
    echo "echo \"password = \$SCRAPYD_PASSWORD\" >> $conf_dir/999_auth.conf" >> $runner; \
    echo "fi" >> $runner; \
    echo "find \"\$SCRAPYD_WORK_DIR\" \! -user \"\$SCRAPYD_USER\" -exec chown \$SCRAPYD_USER:\$SCRAPYD_GROUP '{}' +" >> $runner; \
    echo "cd \$SCRAPYD_WORK_DIR" >> $runner; \
    su="gosu \$SCRAPYD_USER:\$SCRAPYD_GROUP"; \
    echo "$su scrapyd --pidfile /tmp/scrapyd.pid " >> $runner; \
    chmod +x $runner;
VOLUME $SCRAPYD_WORK_DIR
EXPOSE $SCRAPYD_PORT
ENTRYPOINT ["tini", "--"]
CMD ["scrapyd-runner"]
