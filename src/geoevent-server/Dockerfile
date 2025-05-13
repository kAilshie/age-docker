ARG BUILD_TAG="11.4"
ARG ARCGIS_PATCH_STRATEGY="none"

FROM arcgis-server:${BUILD_TAG} AS geoevent-server-base

ARG ARCHIVE_DIR=""
ARG GEOEVENT_ARCHIVE_FILE=""

COPY --chown=arcgis:arcgis --chmod=700 ${ARCHIVE_DIR}/${GEOEVENT_ARCHIVE_FILE} /tmp/

USER arcgis

RUN tar xzf /tmp/${GEOEVENT_ARCHIVE_FILE} -C /tmp/
RUN /tmp/ArcGISGeoEventServer/Setup.sh -m silent -l yes -d /opt

RUN rm /tmp/${GEOEVENT_ARCHIVE_FILE}
RUN rm -rf /tmp/ArcGISGeoEventServer


FROM geoevent-server-base AS geoevent-server

ENV AGSSERVER_ROOT_DIR="/opt/arcgis/server"
ENV GEOEVENT_ROOT_DIR="/opt/arcgis/server/GeoEvent"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume

COPY --chown=arcgis:arcgis --chmod=700 ./utils/. /opt/arcgis/server/GeoEvent/
COPY --chown=arcgis:arcgis --chmod=700 ./geoevent-server/entrypoint.sh /opt/arcgis/server/GeoEvent/

EXPOSE 6080 6443 6143

ENTRYPOINT ["/bin/bash", "-c", "/opt/arcgis/server/GeoEvent/entrypoint.sh"]