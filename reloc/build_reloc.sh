#!/bin/bash -e

. /etc/os-release

print_usage() {
    echo "build_reloc.sh --clean --nodeps"
    echo "  --clean clean build directory"
    echo "  --nodeps    skip installing dependencies"
    echo "  --version V  product-version-release string (overriding SCYLLA-VERSION-GEN)"
    exit 1
}

CLEAN=
NODEPS=
VERSION_OVERRIDE=
while [ $# -gt 0 ]; do
    case "$1" in
        "--clean")
            CLEAN=yes
            shift 1
            ;;
        "--nodeps")
            NODEPS=yes
            shift 1
            ;;
        "--version")
            VERSION_OVERRIDE="$2"
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


if [ ! -e reloc/build_reloc.sh ]; then
    echo "run build_reloc.sh in top of scylla dir"
    exit 1
fi

if [ "$CLEAN" = "yes" ]; then
    rm -rf build target
fi

if [ -f "$DEST" ]; then
    rm "$DEST"
fi

if [ -z "$NODEPS" ]; then
    if [ $EUID -ne 0 ]; then
        SUDO=sudo
    fi
    $SUDO ./install-dependencies.sh
fi

VERSION=$(./SCYLLA-VERSION-GEN ${VERSION_OVERRIDE:+ --version "$VERSION_OVERRIDE"})
# the former command should generate build/SCYLLA-PRODUCT-FILE and some other version
# related files
PRODUCT=`cat build/SCYLLA-PRODUCT-FILE`
DEST="build/$PRODUCT-tools-$VERSION.noarch.tar.gz"

printf "version=%s" $VERSION > build.properties

DEB_ARCH=`dpkg --print-architecture`

# Our ant build.xml requires JAVA8_HOME to be set. In case it wasn't (e.g.,
# dbuild sets it), let's try some common possibilities
if [ -z "$JAVA8_HOME" ]; then
    for i in /usr/lib/jvm/java-1.8.0 /usr/lib/jvm/java-1.8.0-openjdk-"$DEB_ARCH"
    do
        if [ -e "$i" ]; then
            export JAVA8_HOME="$i"
            break
        fi
    done
fi

# On Fedora, default JDK may mistakenly configured to OpenJDK8 by package
# manager for some reason.
# It will breaks ant build since we call --release option which is not
# available OpenJDK8.
# To avoid build failure, we should specify JAVA_HOME to OpenJDK11.
if [ -z "$JAVA_HOME" ]; then
    for i in /usr/lib/jvm/java-11 /usr/lib/jvm/java-11-openjdk-"$DEB_ARCH"
    do
        if [ -e "$i" ]; then
            export JAVA_HOME="$i"
            break
        fi
    done
fi

ant jar
dist/debian/debian_files_gen.py
scripts/create-relocatable-package.py --version $VERSION "$DEST"
