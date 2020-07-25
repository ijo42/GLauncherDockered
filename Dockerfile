FROM ijo42/launcherpre

COPY ./ls /tmp/ls
COPY ./entrypoint entrypoint

RUN chmod +x /entrypoint

EXPOSE 9274
ENTRYPOINT [ "/entrypoint" ]
