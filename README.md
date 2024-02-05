# MLMD Bazel Dist

This repository contains Bazel cache and external dependencies to make the [ml-metadata](https://github.com/opendatahub-io/ml-metadata) build working in a disconnected environment.

> __NOTE__: This worlkflow was tested using `Bazel==5.3.0` only as this was the version used by `ml-metadata` project.

## Generate Dist

In order to re-generate the `_bazel_root` directory please follow these steps:

1. Build a container image from Dockerfile.deps

```bash
docker build -t <IMG_NAME>:latest -f Dockerfile.deps .
```

2. Run the image

```bash
docker run --name <CONTAINER_NAME> -it <IMG_NAME>:latest
```

3. Copy the content from the running container into this repo

Open a new terminal, then retrieve the container id:
```bash
docker ps -aqf "name=<CONTAINER_NAME>"
```

Then copy the content into the repository

```bash
docker cp <CONTAINER_ID>:/root/.cache/bazel/_bazel_root/cache ./_bazel_root/cache
docker cp <CONTAINER_ID>:/root/.cache/bazel/_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429 ./_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429
docker cp <CONTAINER_ID>:/root/.cache/bazel/_bazel_root/install/1a80ecdfe78ff11e1566d5084a48c3f7 ./_bazel_root/1a80ecdfe78ff11e1566d5084a48c3f7

# remove this as this is a cyclic reference to the ml-metadata project, not required
rm -rf ./_bazel_root/13c4dbfe298d1ad9f047b4ec78c9d429/external/ml_metadata
```
> __NOTE__: `13c4dbfe298d1ad9f047b4ec78c9d429` and `1a80ecdfe78ff11e1566d5084a48c3f7` are hashes computed by Bazel, using the same Bazel version (i.e., 5.3.0) and same base image (i.e., ubi9) should make those hashes always the same. If that is not the case consider changing them.

> __NOTE__: the overall size of this repo is approximately 15GB

## Include the Dist into you Container Image

In this section I will show how to include this content into the container image before running the `Bazel` build.

### Prerequisites

- Able to inject this repository as part of the Dockerfile definition
- Bazel properly installed in the container image

### Copy required content

Simply add the following line to your Dockerfile:

```bash
RUN cp -R <path-to-this-repo>/_bazel_root/* $(bazel info output_base)/..
```

With this command you are going to copy all external dependencies together with the Bazel cache into the local root cache.