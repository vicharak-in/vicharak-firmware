FROM --platform=linux/arm64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN apt-get build-dep -y --no-install-recommends | apt-get install -y git-buildpackage debhelper

WORKDIR /vicharak-firmware

COPY . /vicharak-firmware/

RUN make deb -j$(nproc --all)

# Copy the *.deb files to the host
VOLUME ["/vicharak-firmware"]

# Specify the command to run when the container starts
CMD ["/bin/bash"]
