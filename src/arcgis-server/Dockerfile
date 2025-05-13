ARG BUILD_TAG="11.4"
ARG ARCGIS_PATCH_STRATEGY="none"

FROM arcgis-base:${BUILD_TAG} AS arcgis-server-base

ARG ARCHIVE_DIR=""
ARG SERVER_ARCHIVE_FILE=""

COPY --chown=arcgis:arcgis --chmod=700 ${ARCHIVE_DIR}/${SERVER_ARCHIVE_FILE} /tmp/

USER arcgis

RUN tar xzf /tmp/${SERVER_ARCHIVE_FILE} -C /tmp/
RUN /tmp/ArcGISServer/Setup -m silent -l yes -d /opt

RUN rm /tmp/${SERVER_ARCHIVE_FILE}
RUN rm -rf /tmp/ArcGISServer

RUN mkdir /opt/arcgis/server/usr/arcgisserver


FROM arcgis-server-base AS arcgis-server-patched-none
# TODO: add logic to indicate no patches have been applied


FROM arcgis-server-base AS arcgis-server-patched-all
RUN /opt/arcgis/server/tools/patchnotification/patchnotification -i all


FROM arcgis-server-base AS arcgis-server-patched-security
RUN /opt/arcgis/server/tools/patchnotification/patchnotification -i sec


FROM arcgis-server-base AS arcgis-server-patched-custom
# TODO: add logic to apply patches from a patch folder within the install-media directory


FROM arcgis-server-patched-${ARCGIS_PATCH_STRATEGY} AS arcgis-server

ENV AGSSERVER_ROOT_DIR="/opt/arcgis/server"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume

COPY --chown=arcgis:arcgis --chmod=700 ./utils/. /opt/arcgis/server/
COPY --chown=arcgis:arcgis --chmod=700 ./arcgis-server/entrypoint.sh /opt/arcgis/server/

EXPOSE 6080 6443

ENTRYPOINT ["/bin/bash", "-c", "/opt/arcgis/server/entrypoint.sh"]