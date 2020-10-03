FROM ijo42/launcher:latest
ARG UID
ARG GID

RUN if [ $GID = 0 ] || [ $UID = 0 ]; then echo "SUDO not allowed" && exit 1; fi && \
	addgroup --gid "1000" "launchserver" && \
	adduser \
    --disabled-password \
    --gecos "" \
    --home "/launchserver" \
    --ingroup "launchserver" \
    --uid "1000" \
    "launchserver" && chown -R 1000:1000 /tmp/ls /entrypoint /launchserver

COPY --chown=$UID:$GID ./ls /launchserver
WORKDIR /launchserver
USER launchserver
