#!/bin/bash -e

PRODUCT=scylla

. /etc/os-release
print_usage() {
    echo "build_deb.sh --reloc-pkg build/scylla-tools-package.tar.gz"
    echo "  --reloc-pkg specify relocatable package path"
    exit 1
}
TARGET=stable
RELOC_PKG=
while [ $# -gt 0 ]; do
    case "$1" in
        "--reloc-pkg")
            RELOC_PKG=$2
            shift 2
            ;;
        *)
            print_usage
            ;;
    esac
done

is_redhat_variant() {
    [ -f /etc/redhat-release ]
}
is_debian_variant() {
    [ -f /etc/debian_version ]
}
pkg_install() {
    if is_redhat_variant; then
        sudo yum install -y $1
    elif is_debian_variant; then
        sudo apt-get install -y $1
    else
        echo "Requires to install following command: $1"
        exit 1
    fi
}

if [ ! -e SCYLLA-RELOCATABLE-FILE ]; then
    echo "do not directly execute build_rpm.sh, use reloc/build_rpm.sh instead."
    exit 1
fi

if [ "$(arch)" != "x86_64" ]; then
    echo "Unsupported architecture: $(arch)"
    exit 1
fi

if [ -e debian ] || [ -e build/release ]; then
    sudo rm -rf debian build conf/hotspot_compiler
    mkdir build
fi
if is_debian_variant; then
    sudo apt-get -y update
fi
# this hack is needed since some environment installs 'git-core' package, it's
# subset of the git command and doesn't works for our git-archive-all script.
if is_redhat_variant && [ ! -f /usr/libexec/git-core/git-submodule ]; then
    sudo yum install -y git
fi
if [ ! -f /usr/bin/git ]; then
    pkg_install git
fi
if [ ! -f /usr/bin/python ]; then
    pkg_install python
fi
if [ ! -f /usr/sbin/debuild ]; then
    pkg_install devscripts
fi
if [ ! -f /usr/bin/dh_testdir ]; then
    pkg_install debhelper
fi
if [ ! -f /usr/bin/pystache ]; then
    if is_redhat_variant; then
        sudo yum install -y /usr/bin/pystache
    elif is_debian_variant; then
        sudo apt-get install -y python-pystache
    fi
fi

if [ "$ID" = "ubuntu" ] && [ ! -f /usr/share/keyrings/debian-archive-keyring.gpg ]; then
    sudo apt-get install -y debian-archive-keyring
fi
if [ "$ID" = "debian" ] && [ ! -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ]; then
    sudo apt-get install -y ubuntu-archive-keyring
fi

if [ -z "$TARGET" ]; then
    if is_debian_variant; then
        if [ ! -f /usr/bin/lsb_release ]; then
            pkg_install lsb-release
        fi
        TARGET=`lsb_release -c|awk '{print $2}'`
    else
        echo "Please specify target"
        exit 1
    fi
fi
RELOC_PKG_FULLPATH=$(readlink -f $RELOC_PKG)
RELOC_PKG_BASENAME=$(basename $RELOC_PKG)
SCYLLA_VERSION=$(cat SCYLLA-VERSION-FILE | sed 's/\.rc/~rc/')
SCYLLA_RELEASE=$(cat SCYLLA-RELEASE-FILE)

ln -fv $RELOC_PKG_FULLPATH ../$PRODUCT-tools_$SCYLLA_VERSION-$SCYLLA_RELEASE.orig.tar.gz

cp -a dist/debian/debian debian
if [ "$PRODUCT" != "scylla" ]; then
    for i in debian/scylla-*;do
        mv $i ${i/scylla-/$PRODUCT-}
    done
fi

REVISION="1"
MUSTACHE_DIST="\"debian\": true, \"$TARGET\": true, \"product\": \"$PRODUCT\", \"$PRODUCT\": true"
pystache dist/debian/changelog.mustache "{ $MUSTACHE_DIST, \"version\": \"$SCYLLA_VERSION\", \"release\": \"$SCYLLA_RELEASE\", \"revision\": \"$REVISION\", \"codename\": \"$TARGET\" }" > debian/changelog
pystache dist/debian/control.mustache "{ $MUSTACHE_DIST }" > debian/control
pystache dist/debian/rules.mustache "{ $MUSTACHE_DIST }" > debian/rules
chmod a+rx debian/rules

debuild -rfakeroot -us -uc
