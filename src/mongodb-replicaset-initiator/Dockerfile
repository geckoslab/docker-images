ARG MONGO_VERSION

FROM mongo:${MONGO_VERSION}

USER root

COPY ./entrypoint.sh /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
