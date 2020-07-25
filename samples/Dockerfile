FROM ijo42/launcher:latest
ARG UID
ARG GID

RUN addgroup --gid "$GID" "launchserver" && \
	adduser \
    --disabled-password \
    --gecos "" \
    --home "/launchserver" \
    --ingroup "launchserver" \
    --uid "$UID" \
    "launchserver" && chown -R $UID:$GID /tmp/ls /entrypoint

COPY --chown=$UID:$GID ./ls /launchserver
WORKDIR /launchserver
USER launchserver