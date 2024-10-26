#!/bin/sh
#-------------------------------------------------------#
##GOALS: 
# - Universal AppRun for all NixAppImages (CLI/GUI/Everything)
# - Handle ARGV0, Symlinks, CMDLINE ARGS accurately (without requiring yet another AppRun)
# - Use Sane & Safe Bwrap Options By Default (Principle Of Least Privilege)
# - Provide Configurable Options for BubbleWrap & the App Itself at Runtime (without extracting & rebuilding)
#
##Non-Goals:
# - POSIXism (Prefer Performance & Features over Barebones useless Minimalism)
# - Don't try to be a runtime, We are just AppRun
#
## Names to ENV VARS are deliberately chosen to not conflict, so yes they suck
#-------------------------------------------------------#


#-------------------------------------------------------#
##Can be run with DEBUG=1, VERBOSE=1 displays additional info
if [ "${DEBUG}" = "1" ]; then
    set -x
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Check PATH [NEEDS TO BE AT TOP]
if [ -z "${PATH}" ] || [ "${PATH}" = "" ]; then
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    echo "WARNING: Your \$PATH is empty, Setting it to PATH=${PATH}"
else
    case "${PATH}" in
        */*:* | *:*/*)
            [ "${VERBOSE}" = "1" ] && echo "INFO: Using PATH --> ${PATH}"
            #Will fail anyway, since which itself a coreutils
            if ! which basename du cut dirname getent printf realpath readlink >/dev/null 2>&1; then
                PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                echo "WARNING: Coreutils (Buysbox) commands not found, Appending default \$PATH & Trying Again"
                echo "INFO: Using PATH --> ${PATH}"
                if ! which basename du cut dirname getent printf realpath readlink >/dev/null 2>&1; then
                    echo "ERROR: Coreutils (Buysbox) commands still not found after \$PATH update"
                    exit 1
                fi
            fi
            ;;
        *)
            PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            echo "WARNING: Your \$PATH seems broken, Setting it to PATH=${PATH}"
            ;;
    esac
fi
##Validate at least some coreutils exist
if ! which basename du cut dirname getent printf realpath readlink >/dev/null 2>&1; then
   echo "ERROR: Coreutils (Buysbox) commands not found anywhere in \$PATH (${PATH})"
   echo "NEEDED: Coreutils OR Buysbox (Installed via Symlinked) in \$PATH (${PATH})"
   exit 1
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##HELP
if [ "${SHOW_HELP}" = "1" ] || [ "${SHOW_HELP}" = "ON" ]; then
  printf "\n" ; echo "AppRun Helper Format: NixAppImage (https://l.ajam.dev/nixappimage)"
  echo "Set ENV (\$VARIABLE=1 | \$VARIABLE=ON) or Run With: \$VARIABLE=1 \"/path/to/\$APP.NixAppImage\""
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
  echo "BWRAP_EXTRA_ARGS --> Args that will be passed directly to Bwrap (CAREFUL)"
  echo "Intro --> https://wiki.archlinux.org/title/Bubblewrap"
  echo "ManPage --> https://man.archlinux.org/man/bwrap.1"
  echo "To Specify: BWRAP_EXTRA_ARGS=\"\$BWRAP_OPT_WITHOUT_QUOTES\" /path/to/\$APP.NixAppImage"
  echo "Example (Mounts Host /usr/bin to Container /usr/bin): BWRAP_EXTRA_ARGS=\"--ro-bind-try /usr/bin /usr/bin\" /path/to/\$APP.NixAppImage"
  printf "\n" ; exit 0
fi
#-------------------------------------------------------#


#-------------------------------------------------------#
##Get/Set ENV Vars (From Pkg)
#Get the AppDir Path
SELF_PATH="$(dirname "$(realpath "$0")")" ; export SELF_PATH
#Get the ${ARGV0}
SELF_NAME="${ARGV0:-${0##*/}}" ; export SELF_NAME
PATH="${SELF_PATH}/usr/bin:${PATH}"
SANITIZED_PATH="$(printf "'%s'" "${PATH}")"
export PATH SANITIZED_PATH
[ "${VERBOSE}" = "1" ] && echo "INFO: Setting FINAL PATH --> ${PATH}"
##Sanity Checks
case "${BWRAP_MODE}" in
  "LATEST")
    BWRAP_BIN="${SELF_PATH}/bwrap-bin"
    export BWRAP_BIN
    [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=LATEST --> ${BWRAP_BIN}"
    ;;
  "PATCHED")
    BWRAP_BIN="${SELF_PATH}/bwrap-patched"
    export BWRAP_BIN
    [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=PATCHED --> ${BWRAP_BIN}"
    ;;
  "" | "STABLE")
    BWRAP_BIN="${SELF_PATH}/bwrap"
    export BWRAP_BIN
    [ "${VERBOSE}" = "1" ] && echo "INFO: Setting BWRAP_MODE=STABLE --> ${BWRAP_BIN}"
    ;;
esac
if [ ! -e "${BWRAP_BIN}" ]; then
   echo "ERROR: FATAL Bubblewrap (bwrap) Binary NOT FOUND at ${BWRAP_BIN} [BWRAP_MODE = ${BWRAP_MODE}]"
   echo "WARNING: Trying Default (Stable) bwrap at \$APPDIR/bwrap [BWRAP_MODE = STABLE]"
   if [ ! -e "${SELF_PATH}/bwrap" ]; then
     echo "ERROR: FATAL DEFAULT Bubblewrap (bwrap) Binary NOT FOUND at \$APPDIR/bwrap"
     exit 1
   else
     BWRAP_BIN="${SELF_PATH}/bwrap" ; export BWRAP_BIN
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
#-------------------------------------------------------#


#-------------------------------------------------------#
##Get/Set ENVS (from Host)
#User
case "${USER}" in
  "" )
    [ "${VERBOSE}" = "1" ] && echo "WARNING: \$USER is Unknown"
    USER="$(whoami)"
    export USER
    if [ -n "${USER}" ]; then
      [ "${VERBOSE}" = "1" ] && echo "INFO: Setting USER --> ${USER}"
    else
      [ "${VERBOSE}" = "1" ] && echo "WARNING: FAILED to find \$USER"
    fi
    ;;
esac
#Home
if [ -z "${HOME}" ] || [ "${HOME}" = "" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: HOME Directory is empty/unset"
   HOME="$(getent passwd "${USER}" | cut -d: -f6)" ; export HOME
fi
#NIX
if [ -d "/nix/store" ]; then
   echo "WARNING: NixAppImage WILL NOT WORK (properly) on NixOS (You have /nix/store)"
fi
#Tmp
SYSTMP="$(dirname "$(mktemp -u)")"
##XDG
if [ -d "${HOME}" ]; then
    [ "${VERBOSE}" = "1" ] && echo "INFO: Setting HOME Directory --> ${HOME}"
    case "${XDG_CACHE_HOME}" in
        '') XDG_CACHE_HOME="${HOME}/.cache"
            export XDG_CACHE_HOME ;;
    esac
    case "${XDG_CONFIG_HOME}" in
        '') XDG_CONFIG_HOME="${HOME}/.config"
            export XDG_CONFIG_HOME ;;
    esac
    case "${XDG_DATA_HOME}" in
        '') XDG_DATA_HOME="${HOME}/.local/share"
            export XDG_DATA_HOME ;;
    esac
    case "${XDG_RUNTIME_DIR}" in
        '') XDG_RUNTIME_DIR="/run/user/$(id -u)"
            export XDG_RUNTIME_DIR ;;
    esac
    case "${XDG_STATE_HOME}" in
        '') XDG_STATE_HOME="${HOME}/.local/state"
            export XDG_STATE_HOME ;;
    esac
    XDG_HAS_VARS="YES"
    export XDG_HAS_VARS
else
    [ "${VERBOSE}" = "1" ] && echo "WARNING: FAILED to set HOME Directory"
    [ "${VERBOSE}" = "1" ] && echo "WARNING: NOT Inheriting any XDG VARS"
fi
#DISPLAY
case "${WAYLAND_DISPLAY:-}" in
  ?*)
    WAYLAND_DIS_BIND="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
    [ "${VERBOSE}" = "1" ] && echo "INFO: Setting WAYLAND_DISPLAY --> ${WAYLAND_DISPLAY}"
    DISPLAY_SHARES="--setenv 'WAYLAND_DISPLAY' ${WAYLAND_DISPLAY}"
    [ "${VERBOSE}" = "1" ] && echo "INFO: Binding WAYLAND_DISPLAY --> ${WAYLAND_DIS_BIND} (RO)"
    DISPLAY_SHARES="${DISPLAY_SHARES} --ro-bind-try ${WAYLAND_DIS_BIND} ${WAYLAND_DIS_BIND}"
    ;;
  *)
    case "${DISPLAY:-}" in
      ?*)
        [ "${VERBOSE}" = "1" ] && echo "INFO: Setting X11_DISPLAY --> ${DISPLAY}"
        XDISPLAY_SHARES="--setenv DISPLAY ${DISPLAY}"
        if [ -z "${XAUTH}" ]; then
          [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XAUTH --> ${HOME}/.Xauthority"
          XAUTH="${HOME}/.Xauthority"
        fi
        [ "${VERBOSE}" = "1" ] && echo "INFO: Binding XAUTH --> ${XAUTH} (RO)"
        XDISPLAY_SHARES="${XDISPLAY_SHARES} --ro-bind-try ${XAUTH} ${XAUTH}"
        [ "${VERBOSE}" = "1" ] && echo "INFO: Binding X11 Socket --> ${SYSTMP}/.X11-unix (RO)"
        XDISPLAY_SHARES="${XDISPLAY_SHARES} --ro-bind-try ${SYSTMP}/.X11-unix /tmp/.X11-unix"
        export XDISPLAY_SHARES
        ;;
    esac
    ;;
esac
#-------------------------------------------------------#


#-------------------------------------------------------#
##Pre-Exec Checks
#Check if SELF_NAME exists in the /usr/bin directory
if [ -x "${SELF_PATH}/usr/bin/${SELF_NAME}" ] && [ -f "${SELF_PATH}/usr/bin/${SELF_NAME}" ]; then
    SELF_NAME_EXECUTABLE=0
else
    SELF_NAME_EXECUTABLE=1
fi
case "${SELF_NAME_EXECUTABLE}" in
    0)
        [ "${VERBOSE}" = "1" ] && echo "INFO: Invoking (self) CMD --> ${SELF_PATH}/usr/bin/${SELF_NAME}"
        DEFAULT_CMD="$(readlink -f "${SELF_PATH}/usr/bin/${SELF_NAME}")"
        export DEFAULT_CMD
        ;;
    1)
        #In case a provided entrypoint already exists
        ENTRYPOINT_DEFAULT="$(readlink -f "${SELF_PATH}/entrypoint")"
        export ENTRYPOINT_DEFAULT
        DEFAULT_CMD=""
        #If entrypoint exists use it
        if [ -x "${ENTRYPOINT_DEFAULT}" ] && [ -f "${ENTRYPOINT_DEFAULT}" ]; then
            [ "${VERBOSE}" = "1" ] && echo "INFO: Using Default Entrypoint --> ${ENTRYPOINT_DEFAULT}"
            DEFAULT_CMD="$(readlink -f "${ENTRYPOINT_DEFAULT}")"
            export DEFAULT_CMD
        else
            #Find the first executable bin in AppDir/bin & use that
            for exec_bin in "${SELF_PATH}/usr/bin/"*; do
                if [ -x "${exec_bin}" ] && [ -f "${exec_bin}" ]; then
                    [ "${VERBOSE}" = "1" ] && echo "INFO: Using Default CMD --> ${exec_bin}"
                    DEFAULT_CMD="$(readlink -f "${exec_bin}")"
                    export DEFAULT_CMD
                    break
                fi
            done
        fi
        ;;
    *)
        #A mystery
        echo "WARNING: An unexpected ERROR occurred with ${SELF_PATH}/usr/bin/${SELF_NAME}."
        ;;
esac
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
# Check for admin capabilities
case "${ENABLE_ADMIN}" in
    1|ON)
        [ "${VERBOSE}" = "1" ] && echo "WARNING: Adding CAP_SYS_ADMIN (DANGEROUS)"
        ADMIN_STATUS="--cap-add cap_sys_admin"
        export ADMIN_STATUS
        ;;
esac
#Disables Device Sharing [Default:Enabled]
case "${ENABLE_DEV}" in
    0|OFF)
        [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to /dev"
        DEV_STATUS=""
        ;;
    *)
        DEV_STATUS="--dev-bind-try /dev /dev"
        export DEV_STATUS
        ;;
esac
#Disables networking [Default: Enabled]
case "${ENABLE_NET}" in
    "0"|"OFF")
        [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to Network"
        NET_STATUS="--unshare-net"
        ;;
    *)
        #Enables Net Access
        [ "${VERBOSE}" = "1" ] && echo "INFO: ENABLING Access to Network"
        NET_STATUS="--share-net"
        #Shares certs
        [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/ca-certificates (RO)"
        NET_STATUS="${NET_STATUS} --ro-bind-try /etc/ca-certificates /etc/ca-certificates"
        #Share Hosts
        [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/hosts (RO)"
        NET_STATUS="${NET_STATUS} --ro-bind-try /etc/hosts /etc/hosts"
        #Shares DNS etc
        [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing /etc/resolv.conf (RO)"
        NET_STATUS="${NET_STATUS} --ro-bind-try /etc/resolv.conf /etc/resolv.conf"
        #Allows binding to port < 1000
        [ "${VERBOSE}" = "1" ] && echo "INFO: Allowing Network Services to Bind to ports < 1000"
        NET_STATUS="${NET_STATUS} --cap-add cap_net_bind_service"
        ;;
esac
export NET_STATUS
#Share ${HOME} [Default: Shared]
if { [ "${SHARE_HOME}" = "0" ] || [ "${SHARE_HOME}" = "OFF" ]; } || [ -z "${HOME}" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: DISABLING Access to HOME"
   SHARE_HOME=""
elif [ -d "${HOME}" ] && [ "${XDG_HAS_VARS}" = "YES" ]; then
   [ "${VERBOSE}" = "1" ] && echo "INFO: Sharing HOME --> ${HOME} (RW)"
   SHARE_HOME="--bind-try ${HOME} ${HOME}" ; export SHARE_HOME
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_CACHE_HOME --> ${XDG_CACHE_HOME} (RW)"
   XDG_INHERITS="--setenv XDG_CACHE_HOME ${XDG_CACHE_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_CONFIG_HOME --> ${XDG_CONFIG_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv XDG_CONFIG_HOME ${XDG_CONFIG_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_DATA_HOME --> ${XDG_DATA_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv XDG_DATA_HOME ${XDG_DATA_HOME}"
   [ "${VERBOSE}" = "1" ] && echo "INFO: Setting XDG_STATE_HOME --> ${XDG_STATE_HOME} (RW)"
   XDG_INHERITS="${XDG_INHERITS} --setenv XDG_STATE_HOME ${XDG_STATE_HOME}"
   export XDG_INHERITS
fi
#Share /media [Default: NOT Shared]
if [ "${SHARE_MEDIA}" = "1" ] || [ "${SHARE_MEDIA}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /media (RW)"
   SHARE_MEDIA="--bind-try /media /media"
   export SHARE_MEDIA
fi
#Share /mnt [Default: NOT Shared]
if [ "${SHARE_MNT}" = "1" ] || [ "${SHARE_MNT}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /mnt (RW)"
   SHARE_MNT="--bind-try /mnt /mnt"
   export SHARE_MNT
fi
#Share /opt [Default: NOT Shared]
if [ "${SHARE_OPT}" = "1" ] || [ "${SHARE_OPT}" = "ON" ]; then
   [ "${VERBOSE}" = "1" ] && echo "WARNING: SHARING Access to /opt (RW)"
   SHARE_OPT="--bind-try /opt /opt"
   export SHARE_OPT
fi
#Get BWRAP_EXTRA_ARGS
if [ "${BWRAP_EXTRA_ARGS+set}" = "set" ] && [ "${#BWRAP_EXTRA_ARGS}" -gt 2 ]; then
   SANITIZED_BWRAP_EXTRA_ARGS="$(printf "'%s'" "${BWRAP_EXTRA_ARGS}" | tr -d "'\"")"
   export BWRAP_EXTRA_ARGS="${SANITIZED_BWRAP_EXTRA_ARGS}"
   echo "INFO: Passing BWRAP_EXTRA_ARGS to BWRAP: '${BWRAP_EXTRA_ARGS}'"
fi
#Construct Main Bwrap Runner
#shellcheck disable=SC2294
#complains about "$@", but we need it to pass CMD_LINE Args to ${DEFAULT_CMD} itself
#https://www.shellcheck.net/wiki/SC2294 --> This is irrelevant here.
bwrap_run(){
  [ "${VERBOSE}" = "1" ] && echo "INFO: BubbleWrap Version --> $("${BWRAP_BIN}" --version)"
  eval "${BWRAP_BIN}" \
    --dir "${XDG_RUNTIME_DIR}" \
    --proc "/proc" \
    --bind-try "/run" "/run" \
    --bind-try "${SYSTMP}" "/tmp" \
    --bind-try '/sys' '/sys' \
    --ro-bind "${SELF_PATH}/nix" '/nix' \
    --ro-bind-try '/etc/asound.conf' '/etc/asound.conf' \
    --ro-bind-try '/etc/fonts' '/etc/fonts' \
    --ro-bind-try '/etc/group' '/etc/group' \
    --ro-bind-try '/etc/hostname' '/etc/hostname' \
    --ro-bind-try '/etc/localtime' '/etc/localtime' \
    --ro-bind-try '/etc/machine-id' '/etc/machine-id' \
    --ro-bind-try '/etc/nsswitch.conf' '/etc/nsswitch.conf' \
    --ro-bind-try '/etc/passwd' '/etc/passwd' \
    --ro-bind-try '/etc/pulse' '/etc/pulse' \
    --ro-bind-try '/lib/firmware' '/lib/firmware' \
    --ro-bind-try '/usr/share/fonts' '/usr/share/fonts' \
    --ro-bind-try '/usr/share/fontconfig' '/usr/share/fontconfig' \
    --ro-bind-try '/usr/share/icons' '/usr/share/icons' \
    --ro-bind-try '/usr/share/locale' '/usr/share/locale' \
    --ro-bind-try '/usr/share/themes' '/usr/share/themes' \
    --setenv 'DEFAULT_CMD' "${DEFAULT_CMD}" \
    --setenv 'PATH' "${SANITIZED_PATH}" \
    --setenv 'SELF_PATH' "${SELF_PATH}" \
    --setenv 'XDG_RUNTIME_DIR' "${XDG_RUNTIME_DIR}" "${XDG_INHERITS}" \
    --die-with-parent "${ADMIN_STATUS}" "${DEV_STATUS}" "${NET_STATUS}" "${SHARE_HOME}" "${SHARE_MEDIA}" \
    "${SHARE_MNT}" "${SHARE_OPT}" "${BWRAP_EXTRA_ARGS}" "${DEFAULT_CMD}" "$@"
}
#-------------------------------------------------------#


#-------------------------------------------------------#
#Run Found AppRun|Executable if default cmd wasn't specified
if [ $# -eq 0 ]; then
    bwrap_run || true
else
    #Check if the first argument is an executable in the bin directory
    if [ -x "${SELF_PATH}/usr/bin/$1" ] && [ -f "${SELF_PATH}/usr/bin/$1" ]; then
        SELF_CMD="$(printf '%s' "$1")" ; export SELF_CMD
        shift
        [ "${VERBOSE}" = "1" ] && echo "INFO: Invoking (ARG) CMD --> ${SELF_PATH}/usr/bin/${SELF_CMD}"
        DEFAULT_CMD="$(readlink -f "${SELF_PATH}/usr/bin/${SELF_CMD}")" ; export DEFAULT_CMD
        bwrap_run "$@" || true
    else
        #If not, run the default command with all arguments
        bwrap_run "$@" || true
    fi
fi
#-------------------------------------------------------#
#Reset set -x
if [ "${DEBUG}" = "1" ]; then
    set +x
fi
#-------------------------------------------------------#
#END
echo "Re Run: ' SHOW_HELP=1 ${SELF_NAME} ' to see the Help Menu"
#-------------------------------------------------------#