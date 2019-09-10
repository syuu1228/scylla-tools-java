#!/bin/bash
#
# Copyright (C) 2019 ScyllaDB
#

#
# This file is part of Scylla.
#
# Scylla is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Scylla is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scylla.  If not, see <http://www.gnu.org/licenses/>.
#

set -e

print_usage() {
    cat <<EOF
Usage: install.sh [options]

Options:
  --root /path/to/root     alternative install root (default /)
  --prefix /prefix         directory prefix (default /usr)
  --pkg package            specify build package (tools/tools-core)
  --help                   this helpful message
EOF
    exit 1
}

root=/
prefix=/opt/scylladb/

while [ $# -gt 0 ]; do
    case "$1" in
        "--root")
            root="$2"
            shift 2
            ;;
        "--prefix")
            prefix="$2"
            shift 2
            ;;
        "--pkg")
            pkg="$2"
            shift 2
            ;;
        "--help")
            shift 1
	    print_usage
            ;;
        *)
            print_usage
            ;;
    esac
done
if [ -n "$pkg" ] && [ "$pkg" != "tools" -a "$pkg" != "tools-core" ]; then
    print_usage
    exit 1
fi

scylla_version=$(cat SCYLLA-VERSION-FILE)
scylla_release=$(cat SCYLLA-RELEASE-FILE)

rprefix="$root/$prefix"
retc="$root/etc"
rusr="$root/usr"

install -d -m755 "$rprefix"/tools/bin
install -d -m755 "$rusr"/bin

if [ -z "$pkg" ] || [ "$pkg" = "tools-core" ]; then
    install -d -m755 "$retc"/scylla/cassandra
    install -d -m755 "$rprefix"/tools/lib
    install -d -m755 "$rprefix"/tools/licenses
    install -m644 conf/cassandra-env.sh "$retc"/scylla/cassandra
    install -m644 conf/logback.xml "$retc"/scylla/cassandra
    install -m644 conf/logback-tools.xml "$retc"/scylla/cassandra
    install -m644 conf/jvm.options "$retc"/scylla/cassandra
    install -m644 lib/*.jar "$rprefix"/tools/lib
    install -m644 lib/*.zip "$rprefix"/tools/lib
    install -m644 lib/licenses/* "$rprefix"/tools/licenses
    ln -srf "$rprefix"/tools/lib/apache-cassandra-$scylla_version-$scylla_release.jar "$rprefix"/tools/lib/apache-cassandra.jar
    install -m644 dist/common/cassandra.in.sh "$rprefix"/tools
    for i in tools/bin/{filter_cassandra_attributes.py,cassandra_attributes.py} bin/scylla-sstableloader; do
        bn=$(basename $i)
        install -m755 $i "$rprefix"/tools/bin
        ln -srf "$rprefix"/tools/bin/$bn "$rusr"/bin/$bn
    done
fi

if [ -z "$pkg" ] || [ "$pkg" = "tools" ]; then
    install -d -m755 "$rprefix"/tools/pylib
    install -d -m755 "$retc"/bash_completion.d
    install -m644 dist/common/nodetool-completion "$retc"/bash_completion.d
    cp -r pylib/cqlshlib "$rprefix"/tools/pylib
    for i in bin/{nodetool,sstableloader,cqlsh,cqlsh.py} tools/bin/{cassandra-stress,cassandra-stressd,sstabledump,sstablelevelreset,sstablemetadata,sstablerepairedset}; do
        bn=$(basename $i)
        install -m755 $i "$rprefix"/tools/bin
        ln -srf "$rprefix"/tools/bin/$bn "$rusr"/bin/$bn
    done
fi
