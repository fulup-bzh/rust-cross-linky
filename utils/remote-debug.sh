#!/bin/bash

WORKSPACE="$1"
TARGETADDR="$2"
APPNAME="$3"
GDBPORT="$4"
TARGETUSR="$5"

# default same user for host/target
if ! test -z "$5"; then
   TARGETUSR="$5@"
fi

if test -z "$5"; then
   GDBPORT=9999
fi

if which aarch64-linux-gnu-objcopy 2>/dev/null; then
   AARCH64=aarch64-linux-gnu
elif which aarch64-suse-linux-objcopy 2>/dev/null; then
   AARCH64=aarch64-suse-linux
else
    echo "ERROR: fail to find aarch64-*-objectcopy"
    exit 2
fi

REMOTEDBG="gdbserver"
TARGETARCH="aarch64-unknown-linux-gnu"
TARGETCWD="local/bin/$TARGETUSR"
TARGETBIN=${TARGETCWD}/${APPNAME}
HOSTBIN="${WORKSPACE}/target/${TARGETARCH}/debug/${APPNAME}"

if ! test -f $HOSTBIN; then
    echo "ERROR: Binary target binary not found $HOSTBIN"
    exit 2
fi

# If binary rebuilt let's re-split debug info and update target
if test $HOSTBIN -nt $HOSTBIN.debug; then
  rm -f $HOSTBIN.debug
  $AARCH64-objcopy --only-keep-debug $HOSTBIN $HOSTBIN.debug
  $AARCH64-objcopy --add-gnu-debuglink=$HOSTBIN.debug $HOSTBIN
  $AARCH64-strip --strip-debug $HOSTBIN
  if ! test -f $HOSTBIN.debug; then
    echo "ERROR: Fail to generate debug info $HOSTBIN.debug"
    exit 2
  fi
fi #end binary rebuilt

# install target (replace with scp if needed)
ssh ${TARGET_USER}${TARGETADDR} "mkdir -p ${TARGETCWD}"
rsync "${HOSTBIN}" "${TARGET_USER}${TARGETADDR}:${TARGETCWD}"

# start debugger
ssh -q "${TARGET_USER}${TARGETADDR}" >/dev/null << EOF
  cd ${TARGETCWD}
  killall -q ${REMOTEDBG} ${APPNAME}
  echo  starting ${REMOTEDBG} *:${GDBPORT} ${APPNAME}
  ${REMOTEDBG} *:${GDBPORT} ${APPNAME} >/tmp/gdb-server.out 2>&1 &
EOF
