FROM ijo42/launcherpre

COPY ./ls /tmp/ls
COPY ./entrypoint entrypoint

RUN chmod +x /entrypoint

USER launchserver
EXPOSE 9274
WORKDIR /launchserver
  
ENTRYPOINT [ "/entrypoint" ]
