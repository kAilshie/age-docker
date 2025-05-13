ARG BUILD_TAG="11.4"
ARG ARCGIS_PATCH_STRATEGY="none"

FROM arcgis-base:${BUILD_TAG} AS portal-base

ARG ARCHIVE_DIR=""
ARG PORTAL_ARCHIVE_FILE=""

COPY --chown=arcgis:arcgis --chmod=700 ${ARCHIVE_DIR}/${PORTAL_ARCHIVE_FILE} /tmp/

USER arcgis

RUN tar xzf /tmp/${PORTAL_ARCHIVE_FILE} -C /tmp/
RUN /tmp/PortalForArcGIS/Setup -m silent -l yes -d /opt

RUN rm /tmp/${PORTAL_ARCHIVE_FILE}
RUN rm -rf /tmp/PortalForArcGIS

#RUN mkdir /opt/arcgis/portal/usr/arcgisportal


FROM portal-base AS arcgis-portal

ENV PORTAL_ROOT_DIR="/opt/arcgis/portal"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume

COPY --chown=arcgis:arcgis --chmod=700 ./utils/. /opt/arcgis/portal/
COPY --chown=arcgis:arcgis --chmod=700 ./portal/entrypoint.sh /opt/arcgis/portal/

EXPOSE 7080 7443 7654

ENTRYPOINT ["/bin/bash", "-c", "/opt/arcgis/portal/entrypoint.sh"]