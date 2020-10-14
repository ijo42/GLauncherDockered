FROM ijo42/launcher:latest
ARG UID
ARG GID

RUN if [ $GID = 0 ] || [ $UID = 0 ]; then echo "ROOT not allowed" && exit 1; fi && \
	addgroup --gid "$GID" "launchserver" && \
	adduser \
    --disabled-password \
    --gecos "" \
    --home "/launchserver" \
    --ingroup "launchserver" \
    --uid "$UID" \
    "launchserver" && chown -R $UID:$GID /tmp/ls /entrypoint /launchserver

COPY --chown=$UID:$GID ./ls /launchserver
WORKDIR /launchserver
USER launchserver
