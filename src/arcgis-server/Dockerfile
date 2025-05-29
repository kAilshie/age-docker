ARG BUILD_TAG="11.4"
ARG ARCGIS_PATCH_STRATEGY="none"
ARG SERVER_POST_PATCH_STAGE="none"

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
RUN echo "Patch Policy: No patching policy is being applied."


FROM arcgis-server-base AS arcgis-server-patched-all
RUN echo "Patch Policy: Applying all patches."
RUN /opt/arcgis/server/tools/patchnotification/patchnotification -i all


FROM arcgis-server-base AS arcgis-server-patched-security
RUN echo "Patch Policy: Applying security patches."
RUN /opt/arcgis/server/tools/patchnotification/patchnotification -i sec


FROM arcgis-server-base AS arcgis-server-patched-custom
RUN echo "Patch Policy: Applying custom patching strategy"
# TODO: add logic to apply patches from a patch folder within the install-media directory


ARG ARCGIS_PATCH_STRATEGY
FROM arcgis-server-patched-${ARCGIS_PATCH_STRATEGY} AS arcgis-server-post-patch-none
RUN echo "Post Patch: Skipping post patch configuration steps."


ARG ARCGIS_PATCH_STRATEGY
FROM arcgis-server-patched-${ARCGIS_PATCH_STRATEGY} AS arcgis-server-post-patch-wine-fix
RUN echo "Post Patch: Applying wine-fix post patch configuration."
COPY --chown=arcgis:arcgis --chmod=700 ./arcgis-server/wine-fix/wine-v9.9-114final.tar.gz /opt/arcgis/wine-v9.9-114final.tar.gz
COPY --chown=arcgis:arcgis --chmod=700 ./arcgis-server/wine-fix/dot-wine-v9.9-114final.tar.gz /opt/arcgis/dot-wine-v9.9-114final.tar.gz

RUN rm -rf /opt/arcgis/server/bin/wine
RUN rm -rf /opt/arcgis/server/framework/runtime/.wine

RUN tar xzf /opt/arcgis/wine-v9.9-114final.tar.gz -C /opt/arcgis/server/bin/
RUN tar xzf /opt/arcgis/dot-wine-v9.9-114final.tar.gz -C /opt/arcgis/server/framework/runtime/

RUN rm /opt/arcgis/wine-v9.9-114final.tar.gz
RUN rm /opt/arcgis/dot-wine-v9.9-114final.tar.gz


ARG SERVER_POST_PATCH_STAGE
FROM arcgis-server-post-patch-${SERVER_POST_PATCH_STAGE} AS arcgis-server

ENV AGSSERVER_ROOT_DIR="/opt/arcgis/server"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume

COPY --chown=arcgis:arcgis --chmod=700 ./utils/. /opt/arcgis/server/
COPY --chown=arcgis:arcgis --chmod=700 ./arcgis-server/entrypoint.sh /opt/arcgis/server/

EXPOSE 6080 6443

ENTRYPOINT ["/bin/bash", "-c", "/opt/arcgis/server/entrypoint.sh"]