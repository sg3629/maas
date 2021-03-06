#!/bin/bash

IFACE_MGMT=$1
NET_MGMT=$2
NET_BRIDGE=$3
MGMTBR=$4

ip2int()
{
    local a b c d
    { IFS=. read a b c d; } <<< $1
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

int2ip()
{
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

netmask()
{
    local mask=$((0xffffffff << (32 - $1))); shift
    int2ip $mask
}


broadcast()
{
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr | ~mask))
}

network()
{
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr & mask))
}

first()
{
    local addr=$(ip2int $1)
    addr=`expr $addr + 1`
    int2ip $addr
}

MBITS=`echo "$NET_MGMT" | cut -d/ -f2`
MNETW=`echo "$NET_MGMT" | cut -d/ -f1`
MMASK=`netmask $MBITS`
MHOST=`first $MNETW`

BBITS=`echo "$NET_BRIDGE" | cut -d/ -f2`
BNETW=`echo "$NET_BRIDGE" | cut -d/ -f1`
BMASK=`netmask $BBITS`
BHOST=`first $BNETW`

OUT=$(mktemp -u)
cat /etc/network/interfaces | awk '/## CORD - DO NOT EDIT BELOW THIS LINE/{exit};1' | awk "/^auto / { if (\$2 == \"${IFACE_MGMT}\") { IN=1 } else {IN=0} } /^iface / { if (\$2 == \"${IFACE_MGMT}\") { IN=1 } else {IN=0}}  /^#/ || /^\s*\$/ { IN=0 } IN==0 {print} IN==1 { print \"#\" \$0 }" > $OUT

cat <<EOT >> $OUT
## CORD - DO NOT EDIT BELOW THIS LINE

auto ${IFACE_MGMT}
iface ${IFACE_MGMT} inet static
    address ${MHOST}
    network ${MNETW}
    netmask ${MMASK}
    gateway ${MHOST}

auto ${MGMTBR}
iface ${MGMTBR} inet static
    address ${BHOST}
    network ${BNETW}
    netmask ${BMASK}
    gateway ${BHOST}
EOT

diff /etc/network/interfaces $OUT 2>&1 > /dev/null
if [ $? -ne 0 ]; then
    cp /etc/network/interfaces /etc/network/interfaces.last
    cp $OUT /etc/network/interfaces
    echo -n "true"
else
    echo -n "false"
fi

rm $OUT
