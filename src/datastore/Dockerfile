ARG BUILD_TAG="11.4"
ARG ARCGIS_PATCH_STRATEGY="none"

FROM arcgis-base:${BUILD_TAG} AS arcgis-datastore-base

ARG ARCHIVE_DIR=""
ARG DATASTORE_ARCHIVE_FILE=""

COPY --chown=arcgis:arcgis --chmod=700 ${ARCHIVE_DIR}/${DATASTORE_ARCHIVE_FILE} /tmp/

USER arcgis

RUN tar xzf /tmp/${DATASTORE_ARCHIVE_FILE} -C /tmp/
RUN /tmp/ArcGISDataStore_Linux/Setup -m silent -l yes -d /opt -f Complete

RUN rm /tmp/${DATASTORE_ARCHIVE_FILE}
RUN rm -rf /tmp/ArcGISDataStore_Linux

RUN mkdir /opt/arcgis/datastore/usr/arcgisdatastore


FROM arcgis-datastore-base AS arcgis-datastore

ENV DATASTORE_ROOT_DIR="/opt/arcgis/datastore"
ENV VOLUME_ROOT_DIR="/opt/arcgis/volume"

RUN mkdir -p /opt/arcgis/volume

COPY --chown=arcgis:arcgis --chmod=700 ./utils/. /opt/arcgis/datastore/
COPY --chown=arcgis:arcgis --chmod=700 ./datastore/entrypoint.sh /opt/arcgis/datastore/

# All Data stores
EXPOSE 2443

# Relational Data Stores
EXPOSE 9876
EXPOSE 25672 44369
EXPOSE 45671 45672

# Tile Cache Data Stores
EXPOSE 29080 29081
EXPOSE 4369 
EXPOSE 29085 29086 29087 29088 29089 29090
EXPOSE 29082

# Spatiotemporal Data Stores
EXPOSE 9220 9320

# Graph Data Stores
EXPOSE 9828 9829 9831 

# Object Data Stores
EXPOSE 11211 
EXPOSE 29878 29879 
EXPOSE 9820 9830 9840
EXPOSE 9880 29874 29876 29882
EXPOSE 29875 29877 29883
EXPOSE 29860 29861 29862 29863
EXPOSE 29858 29859

ENTRYPOINT ["/bin/bash", "-c", "/opt/arcgis/datastore/entrypoint.sh"]