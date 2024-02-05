# Build arguments
ARG SOURCE_CODE=.
ARG CI_CONTAINER_VERSION="unknown"

#@follow_tag(registry.redhat.io/ubi9/ubi:9.3)
FROM registry.redhat.io/ubi9/ubi:9.3 as builder

## Build args to be used at this step
ARG SOURCE_CODE
ARG CI_CONTAINER_VERSION
## CPaaS CODE BEGIN ##
COPY ${REMOTE_SOURCE} ${REMOTE_SOURCE_DIR}
ENV SOURCE_CODE=${REMOTE_SOURCE}/app
## CPaaS CODE END ##

# Inject the bazel cache and deps into local root bazel cache
RUN mkdir -p /root/.cache/bazel; rsync -ar --remove-source-files ${REMOTE_SOURCES_DIR}/mlmd-bazel-dist/app/_bazel_root /root/.cache/bazel/

USER root

# Note that bazel 5.3.0 should be retrieved from brew
# or directly installed from http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/bazel/5.3.0/1.el8/x86_64/bazel-5.3.0-1.el8.x86_64.rpm
RUN dnf update -y -q && \
  dnf install -y -q \
  which \
  patch \
  gcc \
  clang \
  cmake \
  make \
  openssl \
  ca-certificates \
  unzip \
  git \
  findutils \
  python3 \
  python3-devel \
  bazel

WORKDIR /mlmd-src
COPY ${SOURCE_CODE}/ ./

# Running in offline mode with --nofetch arg, cache and deps must be cloned 
# into the local root bazel cache
# "-std=c++17" is needed in order to build with ZetaSQL.
RUN bazel build -c opt --action_env=PATH \
  --define=grpc_no_ares=true \
  //ml_metadata/metadata_store:metadata_store_server \
  --cxxopt="-std=c++17" --host_cxxopt="-std=c++17" \
  --nofetch

# copying libmysqlclient source onto THIRD_PARTY folder.
RUN mkdir -p /mlmd-src/third_party
RUN cp -RL /mlmd-src/bazel-mlmd-src/external/libmysqlclient /mlmd-src/third_party/mariadb-connector-c

#@follow_tag(registry.redhat.io/ubi9/ubi-minimal:9.3)
FROM registry.redhat.io/ubi9/ubi-minimal:9.3

COPY --from=builder /mlmd-src/bazel-bin/ml_metadata/metadata_store/metadata_store_server /bin/metadata_store_server
COPY --from=builder /mlmd-src/third_party /mlmd-src/third_party

ENV GRPC_PORT "8080"
ENV METADATA_STORE_SERVER_CONFIG_FILE ""

# Introduces tzdata package here to avoid LoadTimeZone check failed error in the metadata store server.
RUN microdnf update -y && \
  microdnf install -y \
  tzdata

EXPOSE ${GRPC_PORT}

CMD \
  "/bin/metadata_store_server" \
  "--grpc_port=${GRPC_PORT}" \
  "--metadata_store_server_config_file=${METADATA_STORE_SERVER_CONFIG_FILE}"
 
LABEL com.redhat.component="odh-mlmd-grpc-server-container" \
      name="managed-open-data-hub/odh-mlmd-grpc-server-container-rhel8" \
      version="${CI_CONTAINER_VERSION}" \
      summary="odh-mlmd-grpc-server" \
      io.openshift.expose-services="" \
      io.k8s.display-name="odh-mlmd-grpc-server" \
      maintainer="['managed-open-data-hub@redhat.com']" \
      description="Sidecar container for recording and retrieving metadata associated with ML developer and data scientist workflows" \
      com.redhat.license_terms="https://www.redhat.com/licenses/Red_Hat_Standard_EULA_20191108.pdf"