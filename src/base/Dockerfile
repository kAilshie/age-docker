ARG BUILD_MODE="prod"
ARG UBUNTU_VERSION_TAG="22.04"

# =================================================
# base
# =================================================
FROM ubuntu:${UBUNTU_VERSION_TAG} AS base

RUN apt-get update 

# Required dependencies for ArcGIS software
RUN apt-get install -y gettext-base
RUN apt-get install -y language-pack-en
RUN apt-get install -y libkeyutils1
RUN apt-get install -y iproute2

# Create the arcgis user
RUN useradd -m arcgis

# Create the base folder that ArcGIS software will be installed into
RUN mkdir /opt/arcgis
RUN chown -R arcgis:arcgis /opt/arcgis
RUN chmod -R 700 /opt/arcgis

# =================================================
# base-debug
# =================================================
FROM base AS base-debug

ENV DEBUG=true

RUN apt-get install -y iputils-ping
RUN apt-get install -y curl

# =================================================
# base-prod
# =================================================
FROM base AS base-prod

RUN apt-get install -y curl

# =================================================
# arcgis-base
# =================================================
FROM base-${BUILD_MODE} AS arcgis-base