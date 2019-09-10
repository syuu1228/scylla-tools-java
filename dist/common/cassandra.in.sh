# Settings for Scylla
SCYLLA_HOME=/var/lib/scylla
SCYLLA_CONF=/etc/scylla

# Scylla adaption. Some one will still have to find us SCYLLA_HOME
# or place us there.
if [ -f "$SCYLLA_CONF/scylla.yaml" ]; then
    if [ -f "$SCYLLA_CONF/cassandra.yaml" ]; then
        CASSANDRA_CONF=$SCYLLA_CONF
    else
        # Create a temp config dir for just this execution
        TMPCONF=`mktemp -d`
        trap "rm -rf $TMPCONF" EXIT
        cp -a "$SCYLLA_CONF"/* "$TMPCONF"
        # extract config files under /etc/scylla/cassandra/ to $TMPCONF
        mv $TMPCONF/cassandra/* $TMPCONF
        rm -rf $TMPCONF/cassandra/
        # Filter out scylla specific options that make
        # cassandra options parser go boom.
        # Also add attributes not present in scylla.yaml
        # but required by cassandra.
        `dirname $0`/filter_cassandra_attributes.py \
                "$TMPCONF/scylla.yaml" \
                > "$TMPCONF/cassandra.yaml"
        CASSANDRA_CONF=$TMPCONF
    fi
fi


CASSANDRA_HOME=/opt/scylladb/tools

# The java classpath (required)
if [ -n "$CLASSPATH" ]; then
    CLASSPATH=$CLASSPATH:$CASSANDRA_CONF
else
    CLASSPATH=$CASSANDRA_CONF
fi

for jar in /opt/scylladb/tools/lib/*.jar; do
    CLASSPATH=$CLASSPATH:$jar
done

for jar in /opt/scylladb/tools/*.jar; do
    CLASSPATH=$CLASSPATH:$jar
done

CLASSPATH="$CLASSPATH:$EXTRA_CLASSPATH"

# set JVM javaagent opts to avoid warnings/errors
if [ "$JVM_VENDOR" != "OpenJDK" -o "$JVM_VERSION" \> "1.6.0" ] \
      || [ "$JVM_VERSION" = "1.6.0" -a "$JVM_PATCH_VERSION" -ge 23 ]
then
    JAVA_AGENT="$JAVA_AGENT -javaagent:$CASSANDRA_HOME/lib/jamm-0.3.0.jar"
fi
