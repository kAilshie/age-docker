ARG BUILD_TAG="11.4.0.0_1.0.0.0"
ARG ARCGIS_PATCH_STRATEGY="none"

FROM tomcat:9.0.104-jre17 AS web-adaptor-base

RUN apt-get update
RUN apt-get install -y jq=1.7.1-3build1

ARG ARCHIVE_DIR=""
ARG WEB_ADAPTOR_ARCHIVE_FILE=""

COPY --chmod=700 ${ARCHIVE_DIR}/${WEB_ADAPTOR_ARCHIVE_FILE} /tmp/

RUN tar xzf /tmp/${WEB_ADAPTOR_ARCHIVE_FILE} -C /tmp/
RUN /tmp/WebAdaptor/Setup -m silent -l yes -d /opt

RUN rm /tmp/${WEB_ADAPTOR_ARCHIVE_FILE}
RUN rm -rf /tmp/WebAdaptor

FROM web-adaptor-base AS arcgis-web-adaptor

ARG ARCGIS_VERSION=""

ENV WA_ROOT_DIR="/opt/arcgis/webadaptor${ARCGIS_VERSION}"
ENV TOMCAT_ROOT_DIR="/usr/local/tomcat"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume
RUN mkdir -p /opt/arcgis/certs

COPY --chmod=700 ./utils/. ${WA_ROOT_DIR}/
COPY --chmod=700 ./web-adaptor/entrypoint.sh ${WA_ROOT_DIR}/
COPY --chmod=700 ./web-adaptor/server.xml /usr/local/tomcat/conf/server.xml

EXPOSE 80 443

ENTRYPOINT ["/bin/bash", "-c", "${WA_ROOT_DIR}/entrypoint.sh"]