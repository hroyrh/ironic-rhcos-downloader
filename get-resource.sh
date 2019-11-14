#!/bin/bash -xe
#CACHEURL=http://172.22.0.1/images

# Which image should we use
export RHCOS_IMAGE_URL=${1:-$RHCOS_IMAGE_URL}
if [ -z "$RHCOS_IMAGE_URL" ] ; then
    echo "No image URL provided"
    exit 1
fi

# When provided by openshift-installer the URL is like
# "https://releases-art-rhcos.svc.ci.openshift.org/art/storage/releases/rhcos-4.2/420.8.20190708.2/rhcos-420.8.20190708.2-openstack.qcow2?sha256=xxx"
# NOTE: strip sha256 query string in the image url
RHCOS_IMAGE_URL_STRIPPED=`echo $RHCOS_IMAGE_URL | cut -f 1 -d \?`
if [[ $RHCOS_IMAGE_URL_STRIPPED = *.qcow2 ]] || [[ $RHCOS_IMAGE_URL_STRIPPED = *.qcow2.gz  ]]
then
    RHCOS_IMAGE_FILENAME_RAW=$(basename $RHCOS_IMAGE_URL_STRIPPED)
    RHCOS_IMAGE_FILENAME_OPENSTACK=${RHCOS_IMAGE_FILENAME_RAW/.gz}
    IMAGE_URL=$(dirname $RHCOS_IMAGE_URL_STRIPPED)
else
    echo "Unexpected image format $RHCOS_IMAGE_URL"
    exit 1
fi
RHCOS_IMAGE_FILENAME_COMPRESSED=${RHCOS_IMAGE_FILENAME_OPENSTACK/-openstack/-compressed}
FFILENAME="rhcos-ootpa-latest.qcow2"

mkdir -p /shared/html/images /shared/tmp
TMPDIR=$(mktemp -d -p /shared/tmp)
cd $TMPDIR

# We have a File in the cache that matches the one we want, use it
if [ -s "/shared/html/images/$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum" ]; then
    echo "$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum found, contents:"
    cat /shared/html/images/$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum
elif curl -I --fail "$CACHEURL/$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum"; then
    curl -g -O "$CACHEURL/$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED"
    curl -g -O "$CACHEURL/$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum"
else
    curl -g --insecure --compressed -L -o "${RHCOS_IMAGE_FILENAME_RAW}" "${IMAGE_URL}/${RHCOS_IMAGE_FILENAME_RAW}"

    if [[ $RHCOS_IMAGE_FILENAME_RAW == *.gz ]]; then
      gzip -d "$RHCOS_IMAGE_FILENAME_RAW"
    fi

    qemu-img convert -O qcow2 -c "$RHCOS_IMAGE_FILENAME_OPENSTACK" "$RHCOS_IMAGE_FILENAME_COMPRESSED"
    md5sum "$RHCOS_IMAGE_FILENAME_COMPRESSED" | cut -f 1 -d " " > "$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum"
fi

if [ -s "${RHCOS_IMAGE_FILENAME_COMPRESSED}.md5sum" ] ; then
    cd /shared/html/images
    chmod 755 $TMPDIR
    mv $TMPDIR $RHCOS_IMAGE_FILENAME_OPENSTACK
    ln -sf "$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED" $FFILENAME
    ln -sf "$RHCOS_IMAGE_FILENAME_OPENSTACK/$RHCOS_IMAGE_FILENAME_COMPRESSED.md5sum" "$FFILENAME.md5sum"
else
    rm -rf $TMPDIR
fi
