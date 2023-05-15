FROM quay.io/centos/centos:stream9 as base
ARG channel="stable"
ARG location

RUN [ -z "${channel}" ] && echo "ARG channel is required" && exit 1 || true

RUN yum -y install jq xz
RUN ARCH=$(uname -m) ; echo $ARCH \
	; curl https://builds.coreos.fedoraproject.org/streams/${channel}.json -o stable.json && \
		cat stable.json | jq -r --arg arch "$ARCH" '.architectures[$arch].artifacts.qemu.release'


FROM base AS executor-img

#RUN ARCH=$(uname -m)

RUN ARCH=$(uname -m) ; echo $ARCH ; \
	if [[ $ARCH == "ppc64le" ]] ; then \
	echo "Downloading https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20220906.3.1/ppc64le/fedora-coreos-36.20220906.3.1-qemu.ppc64le.qcow2.xz" && \
	curl -s -o coreos_production_qemu_image.qcow2.xz https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20220906.3.1/ppc64le/fedora-coreos-36.20220906.3.1-qemu.ppc64le.qcow2.xz && \
	unxz coreos_production_qemu_image.qcow2.xz ; \
	else \
	echo $ARCH && \
	echo "Downloading" $(cat stable.json | jq -r --arg arch "$ARCH" '.architectures[$arch].artifacts.qemu.formats."qcow2.xz".disk.location') && \
	curl -s -o coreos_production_qemu_image.qcow2.xz $(cat stable.json | jq -r --arg arch "$ARCH" '.architectures[$arch].artifacts.qemu.formats."qcow2.xz".disk.location') && \
	unxz coreos_production_qemu_image.qcow2.xz \
	; fi

FROM base AS final
ARG channel=stable

RUN mkdir -p /userdata
WORKDIR /userdata

RUN ARCH=$(uname -m) ; \
	yum -y update && \
	yum -y remove jq && \
	if [[ $ARCH == "ppc64le" ]] ; then \
	echo "Downloading " && \
	curl -s -o qemu-kvm-core-6.2.0-12.module_el8.7.0+1140+ff0772f9.ppc64le.rpm  https://rpmfind.net/linux/centos/8-stream/AppStream/ppc64le/os/Packages/qemu-kvm-core-6.2.0-20.module_el8.7.0+1218+f626c2ff.1.ppc64le.rpm && \
	rpm -i qemu-kvm-core-6.2.0-12.module_el8.7.0+1140+ff0772f9.ppc64le.rpm && \
	yum -y clean all; \
	else \
	yum -y install openssh-clients qemu-kvm && \
	yum -y clean all \
	; fi

COPY --from=executor-img /coreos_production_qemu_image.qcow2 /userdata/coreos_production_qemu_image.qcow2
COPY start.sh /userdata/start.sh

RUN chgrp -R 0 /userdata && \
    chmod -R g=u /userdata

LABEL com.coreos.channel ${channel}

ENTRYPOINT ["/bin/bash", "/userdata/start.sh"]
