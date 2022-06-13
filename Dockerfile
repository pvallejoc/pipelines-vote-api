FROM image-registry.openshift-image-registry.svc:5000/openshift/golang:latest as builder

WORKDIR /build
ADD . /build/
#####
# Don't include container-selinux and remove
# directories used by yum that are just taking
# up space.
#RUN useradd build; yum -y update; rpm --restore shadow-utils 2>/dev/null; yum -y install cpp buildah fuse-overlayfs xz --exclude container-selinux; rm -rf /var/cache /var/log/dnf* /var/log/yum.*;

ADD https://raw.githubusercontent.com/containers/buildah/main/contrib/buildahimage/stable/containers.conf /etc/containers/

# Adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf
#RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

# Define uid/gid ranges for our user https://github.com/containers/buildah/issues/3053
#RUN echo -e "build:1:999\nbuild:1001:64535" > /etc/subuid; \
# echo -e "build:1:999\nbuild:1001:64535" > /etc/subgid; \
# mkdir -p /home/build/.local/share/containers; \
# chown -R build:build /home/build

#VOLUME /var/lib/containers
#VOLUME /home/build/.local/share/containers

ENV BUILDAH_ISOLATION=chroot

######

RUN mkdir /tmp/cache
RUN CGO_ENABLED=0 GOCACHE=/tmp/cache go build  -mod=vendor -v -o /tmp/api-server .

FROM scratch

WORKDIR /app
COPY --from=builder /tmp/api-server /app/api-server

CMD [ "/app/api-server" ]
