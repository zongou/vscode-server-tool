#! /bin/sh
# MIT License
# Copyright (c) [2023] [zongou@outlook.com]

# yarn config set registry https://registry.npmmirror.com

set -e -u
# Configurations
is_cn_proxy() { false; }
APP_DIR="./code-server"
# Test
is_termux() { test "${TERMUX_VERSION+1}"; }
is_alpine() { test -f /etc/os-release && test "$(grep "^ID=" /etc/os-release | cut -d= -f2-)"="alpine"; }

# Utilities
RED='\033[31m'
DEF='\033[0m'
msg() { printf "%s${*}\n" '' >&2; }
exit_on_error() { msg "${RED}ERROR: ${DEF}${*}" && exit 1; }

rebuild_borken_dependencies() {
    if test $# -gt 0 && test -d "$1"; then
        _TMP_APP_DIR="${1}"
        find "$_TMP_APP_DIR" -path "*/lib/vscode" -prune | while IFS= read -r dir; do
            msg "rebuild_broken_dependencies at ${dir}"
            (cd "$dir" && yarn)
        done
    else
        exit_on_error "Please specify the app directory!"
    fi
}

patch_released_app() {
    if test $# -gt 0 && test -d "$1"; then
        _TMP_APP_DIR="${1}"
        # _TMP_BUILD_DIR="$HOME/tmp_yarn_build_dir"
        _TMP_BUILD_DIR="$(mktemp --directory --tmpdir="${HOME}")"
        trap "msg \"\\r\\033[2KExit immediatly as requested.\"; rm -rf \"\${_TMP_BUILD_DIR}\"; exit 1" HUP INT TERM
        trap " trap - EXIT; rm -rf \"\${_TMP_BUILD_DIR}\"; exit 1" EXIT
        setup_build_env
        mkdir -p "${_TMP_BUILD_DIR}"

        (
            cd "${_TMP_BUILD_DIR}" &&
                (
                    # yarn add argon2@0.30.3 spdlog@0.13.6 node-pty@0.11.0-beta29 @parcel/watcher@2.1.0 keytar --ignore-engines
                    # yarn --ignore-engines add argon2 spdlog node-pty @parcel/watcher keytar

                    yarn --ignore-engines add spdlog node-pty "@parcel/watcher@npm:@parcel/watcher-$(
                        if is_termux; then
                            printf '%s' android-arm64
                        elif is_alpine; then
                            printf '%s' linux-arm64-musl
                        fi
                    )"
                )
        )

        # for module_name in argon2 spdlog node-pty @parcel/watcher keytar; do
        for module_name in spdlog node-pty @parcel/watcher; do
            find "${_TMP_APP_DIR}" \( -path "*/node_modules/${module_name}" -or -path "*/node_modules/@*/${module_name}" \) -prune | while IFS= read -r module_dir; do
                echo "replace ${module_name} at ${module_dir}"
                if test -d "${_TMP_BUILD_DIR}/node_modules/${module_name}"; then
                    rm -rf "${module_dir}" && cp -r "${_TMP_BUILD_DIR}/node_modules/${module_name}" "$(dirname "${module_dir}")"
                else
                    msg "Warn: ${_TMP_BUILD_DIR}/node_modules/${module_name} not exists!"
                fi
            done
        done

        relink_node "${_TMP_APP_DIR}"
        if is_termux; then
            termux_fix_ptyhostmainjs "${_TMP_APP_DIR}"
            termux_link_ripgrep "${_TMP_APP_DIR}"
        fi

        trap - EXIT HUP INT TERM
        rm -rf "${_TMP_BUILD_DIR}"
    else
        exit_on_error "Please specify the code-server/openvscode-server directory!"
    fi
}

# fix ptyhost dose not support android
termux_fix_ptyhostmainjs() {
    if test $# -gt 0 && test -d "$1"; then
        find "${1}" -name "ptyHostMain.js" | while IFS= read -r file; do
            msg "fix ptyMainHost.js at ${file}"
            sed -i 's|;case"linux":|;case"android":case"linux":|' "${file}"
        done
    fi
}

relink_node() {
    if test $# -gt 0 && test -d "$1"; then
        find "${1}" -name "node" \( -type f -or -type l \) | while IFS= read -r file; do
            msg "relink node binary at ${file}"
            ln -sf "$(command -v node)" "${file}"
        done
    fi
}

termux_link_ripgrep() {
    if test $# -gt 0 && test -d "$1"; then
        find "${1}" -name "ripgrep" -type d | while IFS= read -r dir; do
            msg "link repgrep binary at ${dir}"
            ln -sf "$(command -v rg)" "${dir}/bin"
        done
    fi
}

setup_build_env() {
    if is_alpine; then
        apk add alpine-sdk libstdc++ libc6-compat libsecret-dev python3 yarn || exit 1
    elif is_termux; then
        apt install build-essential binutils libandroid-spawn libsecret ripgrep python3 nodejs-lts yarn -y || exit 1
    else
        exit_on_error "this script is designed to build code-server on alpine and termux only!"
    fi

    # FORCE_NODE_VERSION="$(node --version | cut -d. -f 1)"
    FORCE_NODE_VERSION='FALSE'
    export FORCE_NODE_VERSION
    if is_cn_proxy; then setup_cn_proxy; fi
}

build_app() {
    trap "msg \"\\r\\033[2KExit immediatly as requested.\"; rm -rf \"\${APP_DIR}\"; exit 1" HUP INT TERM
    trap " trap - EXIT; rm -rf \"\${APP_DIR}\"; exit 1" EXIT
    if (mkdir -p "${APP_DIR}" && cd "${APP_DIR}" && yarn --ignore-engines add code-server); then
        rebuild_borken_dependencies "${APP_DIR}" || return 1
        if is_termux; then
            termux_fix_ptyhostmainjs "${APP_DIR}"
            termux_link_ripgrep "${APP_DIR}"
        fi
    else
        return 1
    fi
    trap - EXIT HUP INT TERM
}

test_app() {
    "${APP_DIR}/node_modules/.bin/code-server" --host 0.0.0.0 --port 8080 --auth none ||
        "${APP_DIR}/node_modules/.bin/code-server" --host 0.0.0.0 --port 8888 --auth none
}

main() {
    _show_help() {
        msg "Build code-server on termux and alpine."
        msg "Usage:"
        msg "$(basename "$0") [option]"
        msg "options:"
        msg "  -h|--help        show this help"
        msg "  --cn-proxy       use CN proxy"
        msg "  build            build code-server with yarn"
        msg "  patch            patch released app"
    }
    if test $# -gt 0; then
        while test $# -gt 0; do
            case "$1" in
            -h | --help)
                shift
                _show_help
                exit
                ;;
            build)
                shift
                setup_build_env
                build_app
                relink_node "${APP_DIR}"
                test_app
                break
                ;;
            patch)
                shift
                patch_released_app "$@"
                break
                ;;
            --* | -*)
                exit_on_error "option not recognized: [$1]"
                ;;
            *)
                exit_on_error "argument not recognized: [${1}]"
                ;;
            esac
        done
    else
        _show_help
        exit 1
    fi
}

main "$@"
