#!/bin/sh
#-------------------------------------------------------#
##HELP
if [ "${SHOW_HELP}" = "1" ] || [ "${SHOW_HELP}" = "ON" ]; then
  printf "\n" ; echo "AppRun Helper Format: NixAppImage (https://l.ajam.dev/nixappimage)"
  echo "Set ENV (\$VARIABLE=1 | \$VARIABLE=ON) or Run With: \$VARIABLE=1 /path/to/\$APP.NixAppImage"
  echo "Example: SHOW_HELP=1 ./\$APP.NixAppImage --> Show this Help"
  echo "Example: export SHOW_HELP=1 && ./\$APP.NixAppImage --> Also Show this Help"
  echo "(\$VARIABLE=1 | \$VARIABLE=ON) --> Enable \$MODE|\$FEATURE"
  echo "(\$VARIABLE=0 | \$VARIABLE=OFF) --> Disable \$MODE|\$FEATURE"
  echo "VARIABLES:"
  echo "SHOW_HELP --> Toggle Help Message"
  echo "VERBOSE --> Toggle Verbose Mode (Shows Each Step)"
  echo "DEBUG --> Toggle Debug (set -x) Mode"
  echo "SHOW_SYMLINKS --> Lists all available binaries in the \$PKG"
  echo "BWRAP_MODE=STABLE --> Use Stable BubbleWrap from NixPkgs [Default: STABLE]"
  echo "BWRAP_MODE=LATEST --> Use Latest BubbleWrap from Toolpacks (https://l.ajam.dev/bwrap-latest)"
  echo "BWRAP_MODE=PATCHED --> Use Patched BubbleWrap (https://l.ajam.dev/bwrap-patched) to Allow Nested Bwrap (DANGEROUS)"
  echo "ENABLE_ADMIN --> Toggle Package's CAP_SYS_ADMIN Capability (DANGEROUS) [Default: 0|OFF]"
  echo "ENABLE_DEV --> Toggle Package's access to Device (/dev) (from Host) [Default: 1|ON]"
  echo "ENABLE_NET --> Toggle Package's access to Network (Internet) (from Host) [Default: 1|ON]"
  echo "SHARE_HOME --> Toggle Package's access (Read|Write) to \$HOME (+\$XDG) Dir (from Host) [Default: 1|ON]"
  echo "SHARE_MEDIA --> Toggle Package's access (Read|Write) to /media Dir (from Host) [Default: 0|OFF]"
  echo "SHARE_MNT --> Toggle Package's access (Read|Write) to /mnt Dir (from Host) [Default: 0|OFF]"
  echo "SHARE_OPT --> Toggle Package's access (Read|Write) to /opt Dir (from Host) [Default: 0|OFF]"
  printf "\n" ; exit 0
fi
##Can be run with DEBUG=1, VERBOSE=1 displays additional info
if [ "${DEBUG}" = "1" ]; then
    set -x
fi
##Get/Set ENV Vars (From Pkg)
#Get the AppDir Path
SELF_PATH="$(dirname "$(realpath "$0")")"
#Get the ${ARGV0}
SELF_NAME="${ARGV0}"
#Set path
export PATH="${SELF_PATH}/usr/bin:${PATH}"
#Sanity Checks
if [ "${BWRAP_MODE}" = "LATEST" ]; then
   BWRAP_BIN="${SELF_PATH}/bwrap-bin"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=LATEST --> ${BWRAP_BIN}"
elif [ "${BWRAP_MODE}" = "PATCHED" ]; then
   BWRAP_BIN="${SELF_PATH}/bwrap-patched"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=PATCHED --> ${BWRAP_BIN}"
elif [ -z "${BWRAP_MODE}" ] || [ "${BWRAP_MODE}" = "STABLE" ]; then
   BWRAP_BIN="${SELF_PATH}/bwrap"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=STABLE --> ${BWRAP_BIN}"
fi
if [ ! -e "${BWRAP_BIN}" ]; then
   echo "ERROR: FATAL Bubblewrap (bwrap) Binary NOT FOUND at ${BWRAP_BIN} [BWRAP_MODE = ${BWRAP_MODE}]"
   echo "WARNING: Trying Default (Stable) bwrap at \$APPDIR/bwrap [BWRAP_MODE = STABLE]"
   if [ ! -e "${SELF_PATH}/bwrap" ]; then
     echo "ERROR: FATAL DEFAULT Bubblewrap (bwrap) Binary NOT FOUND at \$APPDIR/bwrap"
     exit 1
   else
     BWRAP_BIN="${SELF_PATH}/bwrap"
     echo "WARNING: Setting BWRAP_MODE=STABLE --> ${BWRAP_BIN}"
     chmod +x "${BWRAP_BIN}" 2>/dev/null
   fi
else
   chmod +x "${BWRAP_BIN}" 2>/dev/null
fi
if [ ! -d "${SELF_PATH}/nix/store" ]; then
   echo "ERROR: FATAL /nix/store NOT FOUND at \$APPDIR/nix/store"
 exit 1
fi
##Get/Set ENVS (from Host)
#User
if [ -z "${USER}" ] || [ "${USER}" = "" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: \$USER is Unknown"
   USER="$(whoami)"
   if [ -n "${USER}" ]; then
     [ "${VERBOSE}" = "1" ] && echo "INFO: Setting USER --> ${USER}"
   else
     [ "${VERBOSE}" = "1" ] && echo "WARNING: FAILED to find \$USER"
   fi
fi
#Home
if [ -z "${HOME}" ] || [ "${HOME}" = "" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: HOME Directory is empty/unset"
   HOME="$(getent passwd "${USER}" | cut -d: -f6)"
fi
#NIX
if [ -d "/nix/store" ]; then
   echo "WARNING: NixAppImage WILL NOT WORK (properly) on NixOS (You have /nix/store)"
fi
#Tmp
SYSTMP="$(dirname "$(mktemp -u)")"
#XDG
if [ -d "${HOME}" ]; then
  [ "${VERBOSE}" = "1" ] && echo "INFO: Setting HOME Directory --> ${HOME}"
  if [ -z "${XDG_CACHE_HOME}" ]; then
     XDG_CACHE_HOME="${HOME}/.cache"
  fi
  if [ -z "${XDG_CONFIG_HOME}" ]; then
     XDG_CONFIG_HOME="${HOME}/.config"
  fi
  if [ -z "${XDG_DATA_HOME}" ]; then
     XDG_DATA_HOME="${HOME}/.local/share"
  fi
  if [ -z "${XDG_RUNTIME_DIR}" ]; then
     XDG_RUNTIME_DIR="/run/user/$(id -u)"
  fi
  if [ -z "${XDG_STATE_HOME}" ]; then
     XDG_STATE_HOME="${HOME}/.local/state"
  fi
  XDG_HAS_VARS="YES"
else
  [ "${VERBOSE}" = "1" ] && echo "WARNING: FAILED to set HOME Directory"
  [ "${VERBOSE}" = "1" ] && echo "WARNING: NOT Inheriting any XDG VARS"
fi
#DISPLAY
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  WAYLAND_DIS_BIND="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
  [ "${VERBOSE}" = "1" ] && echo "INFO: Setting WAYLAND_DISPLAY --> ${WAYLAND_DISPLAY}"
  DISPLAY_SHARES="--setenv 'WAYLAND_DISPLAY' ${WAYLAND_DISPLAY}"
  [ "${VERBOSE}" = "1" ] && echo "INFO: Binding WAYLAND_DISPLAY --> ${WAYLAND_DIS_BIND} (RO)"
  DISPLAY_SHARES="${DISPLAY_SHARES} --ro-bind-try ${WAYLAND_DIS_BIND} ${WAYLAND_DIS_BIND}"
elif [ -n "${DISPLAY:-}" ]; then
  [ "${VERBOSE}" = "1" ] && echo "INFO: Setting X11_DISPLAY --> ${DISPLAY}"
  XDISPLAY_SHARES="--setenv 'DISPLAY' ${DISPLAY}"
  if [ -z "${XAUTH}" ] || [ "${XAUTH}" = "" ]; then
     [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XAUTH --> ${HOME}/.Xauthority"
     XAUTH="${HOME}/.Xauthority"
  fi
  [ "${VERBOSE}" = "1" ] && echo "INFO: Binding XAUTH --> ${XAUTH} (RO)"
  XDISPLAY_SHARES="${XDISPLAY_SHARES} --ro-bind-try ${XAUTH} ${XAUTH}"
  [ "${VERBOSE}" = "1" ] && echo "INFO: Binding X11 Socket --> ${SYSTMP}/.X11-unix (RO)"
  XDISPLAY_SHARES="${XDISPLAY_SHARES} --ro-bind-try "${SYSTMP}/.X11-unix" '/tmp/.X11-unix'"
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##PreFlight Checks
#Check if SELF_NAME exists in the /usr/bin directory
if [ -x "${SELF_PATH}/usr/bin/${SELF_NAME}" ] && [ -f "${SELF_PATH}/usr/bin/${SELF_NAME}" ]; then
   [ "${VERBOSE}" = "1" ] && echo "INFO: Invoking (self) CMD --> ${SELF_PATH}/usr/bin/${SELF_NAME}"
   DEFAULT_CMD="$(readlink -f "${SELF_PATH}/usr/bin/${SELF_NAME}")"
else
   #In case a provided entrypoint already exists
   ENTRYPOINT_DEFAULT="$(readlink -f "${SELF_PATH}/entrypoint")"
   DEFAULT_CMD=""
   #If entrypoint exists use it
   if [ -x "${ENTRYPOINT_DEFAULT}" ] && [ -f "${ENTRYPOINT_DEFAULT}" ]; then
       [ "${VERBOSE}" = "1" ] && echo "INFO: Using Default Entrypoint --> ${ENTRYPOINT_DEFAULT}"
       DEFAULT_CMD="$(readlink -f "${ENTRYPOINT_DEFAULT}")"
   else
       #Find first executable bin in AppDir/bin & use that
       for exec_bin in "${SELF_PATH}/usr/bin/"*; do
           if [ -x "${exec_bin}" ] && [ -f "${exec_bin}" ]; then
               [ "${VERBOSE}" = "1" ] && echo "INFO: Using Default CMD --> ${exec_bin}"
               DEFAULT_CMD="$(readlink -f "${exec_bin}")"
               break
           fi
       done
   fi
fi
#Can be run with SHOW_SYMLINKS=1, to print all bins
if [ "${SHOW_SYMLINKS}" = "1" ] || [ "${SHOW_SYMLINKS}" = "ON" ]; then
  [ "${VERBOSE}" = "1" ] && echo "INFO: Displaying Possible Symlinks"
  for bin in "${SELF_PATH}/usr/bin/"* "${SELF_PATH}/usr/bin/."*; do
    [ -f "${bin}" ] && printf "%s " "${bin##*/}"
  done
  printf "\n" ; exit 0
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##BWRAP
#BWRAP_BINDS="$(printf '%s ' $(printf '%s\n' /* | grep -v -E "dev|nix|proc" | xargs -I % echo --bind % %))"
#CAP_SYS_ADMIN == root, escaping sandbox is easy [Default: Disabled]
if [ "${ENABLE_ADMIN}" = "1" ] || [ "${ENABLE_ADMIN}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: Adding CAP_SYS_ADMIN (DANGEROUS)"
   ADMIN_STATUS="--cap-add 'cap_sys_admin'"
fi
#Disables Device Sharing [Default:Enabled]
if [ "${ENABLE_DEV}" = "0" ] || [ "${ENABLE_DEV}" = "OFF" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to /dev"
   DEV_STATUS=""
else
   DEV_STATUS="--dev-bind-try '/dev' '/dev'"
fi
#Disables networking [Default: Enabled]
if [ "${ENABLE_NET}" = "0" ] || [ "${ENABLE_NET}" = "OFF" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to Network"
   NET_STATUS="--unshare-net"
else
  #Enables Net Access
   [ "${VERBOSE}" = "1" ] && echo "INFO: ENABLING Access to Network"
   NET_STATUS="--share-net"
  #Shares certs
   [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/ca-certificates (RO)"
   NET_STATUS="${NET_STATUS} --ro-bind-try '/etc/ca-certificates' '/etc/ca-certificates'"
  #Share Hosts
   [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/hosts (RO)"
   NET_STATUS="${NET_STATUS} --ro-bind-try '/etc/hosts' '/etc/hosts'"
  #Shares DNS etc
   [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/resolv.conf (RO)"
   NET_STATUS="${NET_STATUS} --ro-bind-try '/etc/resolv.conf' '/etc/resolv.conf'"
  #Allows binding to port < 1000
   [ "${VERBOSE}" = "1" ] && echo "INFO: Allowing to Network Services to Bind to ports < 1000"
   NET_STATUS="${NET_STATUS} --cap-add 'cap_net_bind_service'"
fi
#Share ${HOME} [Default: Shared]
if { [ "${SHARE_HOME}" = "0" ] || [ "${SHARE_HOME}" = "OFF" ]; } || [ -z "${HOME}" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to HOME"
   SHARE_HOME=""
elif [ -d "${HOME}" ] && [ "${XDG_HAS_VARS}" = "YES" ]; then
   [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing HOME --> ${HOME} (RW)"
   SHARE_HOME="--bind-try ${HOME} ${HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_CACHE_HOME --> ${XDG_CACHE_HOME} (RW)"
   XDG_INHERITS="--setenv 'XDG_CACHE_HOME' ${XDG_CACHE_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_CONFIG_HOME --> ${XDG_CONFIG_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv 'XDG_CONFIG_HOME' ${XDG_CONFIG_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_DATA_HOME --> ${XDG_DATA_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv 'XDG_DATA_HOME' ${XDG_DATA_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_STATE_HOME --> ${XDG_STATE_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv 'XDG_STATE_HOME' ${XDG_STATE_HOME}"
fi
#Share /media [Default: NOT Shared]
if [ "${SHARE_MEDIA}" = "1" ] || [ "${SHARE_MEDIA}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /media (RW)"
   SHARE_MEDIA="--bind-try '/media' '/media'"
fi
#Share /mnt [Default: NOT Shared]
if [ "${SHARE_MNT}" = "1" ] || [ "${SHARE_MNT}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /mnt (RW)"
   SHARE_MNT="--bind-try '/mnt' '/mnt'"
fi
#Share /opt [Default: NOT Shared]
if [ "${SHARE_OPT}" = "1" ] || [ "${SHARE_OPT}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /opt (RW)"
   SHARE_OPT="--bind-try '/opt' '/opt'"
fi
#Construct Main Bwrap Runner
bwrap_run(){
  [ "${VERBOSE}" = "1" ] && echo "INFO: BubbleWrap Version --> $("${BWRAP_BIN}" --version)"
  eval exec "${BWRAP_BIN}" \
    --dir "${XDG_RUNTIME_DIR}" \
    --proc "/proc" \
    --bind-try "/run" "/run" \
    --bind-try "${SYSTMP}" "/tmp" \
    --bind-try '/sys' '/sys' \
    --ro-bind "${SELF_PATH}/nix" '/nix' \
    --ro-bind-try '/etc/asound.conf' '/etc/asound.conf' \
    --ro-bind '/etc/fonts' '/etc/fonts' \
    --ro-bind-try '/etc/group' '/etc/group' \
    --ro-bind-try '/etc/hostname' '/etc/hostname' \
    --ro-bind-try '/etc/localtime' '/etc/localtime' \
    --ro-bind-try '/etc/machine-id' '/etc/machine-id' \
    --ro-bind-try '/etc/nsswitch.conf' '/etc/nsswitch.conf' \
    --ro-bind-try '/etc/passwd' '/etc/passwd' \
    --ro-bind-try '/lib/firmware' '/lib/firmware' \
    --ro-bind-try '/usr/share/fonts' '/usr/share/fonts' \
    --ro-bind-try '/usr/share/fontconfig' '/usr/share/fontconfig' \
    --ro-bind-try '/usr/share/locale' '/usr/share/locale' \
    --ro-bind-try '/usr/share/themes' '/usr/share/themes' \
    --setenv 'DEFAULT_CMD' "${DEFAULT_CMD}" \
    --setenv 'PATH' "$(printf "'%s'" "${PATH}")" \
    --setenv 'SELF_PATH' "${SELF_PATH}" \
    --setenv 'XDG_RUNTIME_DIR' "${XDG_RUNTIME_DIR}" "${XDG_INHERITS}" \
    --die-with-parent "${ADMIN_STATUS}" "${DEV_STATUS}" "${NET_STATUS}" \
    "${SHARE_HOME}" "${SHARE_MEDIA}" "${SHARE_MNT}" "${SHARE_OPT}" "${DEFAULT_CMD}" "$@"
}
#-------------------------------------------------------#


#-------------------------------------------------------#
#Run Found AppRun|Executable if default cmd wasn't specified
if [ $# -eq 0 ]; then
    bwrap_run
else
    #Check if the first argument is an executable in the bin directory
    if [ -x "${SELF_PATH}/usr/bin/$1" ] && [ -f "${SELF_PATH}/usr/bin/$1" ]; then
        SELF_CMD="$(printf '%s' "$1")"
        shift
        [ "${VERBOSE}" = "1" ] && echo "INFO: Invoking (ARG) CMD --> ${SELF_PATH}/usr/bin/${SELF_CMD}"
        DEFAULT_CMD="$(readlink -f "${SELF_PATH}/usr/bin/${SELF_CMD}")"
        bwrap_run "$@"
    else
        #If not, run the default command with all arguments
        bwrap_run "$@"
    fi
fi
#-------------------------------------------------------#
#Reset set -x
if [ "${DEBUG}" = "1" ]; then
    set +x
fi
#-------------------------------------------------------#
#END
echo "Re Run: 'SHOW_HELP=1 \$NAME_OR_PATH_OF_THE_PKG_YOU_JUST_RAN' to see the Help Menu"
#-------------------------------------------------------#
