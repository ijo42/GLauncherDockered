FROM ijo42/launcherpre

# MANAGE USERS AND FILE PERMISSIONS
ARG UID=1000
ARG GID=1000
COPY --chown=$UID:$GID ./ls /tmp/ls
COPY --chown=$UID:$GID ./setup.sh entrypoint

RUN addgroup --gid "$GID" "launchserver" && \
	adduser \
    --disabled-password \
    --gecos "" \
    --home "/launchserver" \
    --ingroup "launchserver" \
    --uid "$UID" \
    "launchserver" && chmod +x /entrypoint

USER launchserver
EXPOSE 9274
WORKDIR /launchserver
  
ENTRYPOINT [ "/entrypoint" ]
