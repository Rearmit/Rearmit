#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

rp_module_id="mupen64plus-rearmit"
rp_module_desc="N64 emulator MUPEN64Plus"
rp_module_help="ROM Extensions: .z64 .n64 .v64\n\nCopy your N64 roms to $romdir/n64"
rp_module_licence="GPL2 https://raw.githubusercontent.com/mupen64plus/mupen64plus-core/master/LICENSES"
rp_module_repo=":_pkg_info_mupen64plus-rearmit"
rp_module_section="main"
rp_module_flags="sdl2"

function depends_mupen64plus-rearmit() {
    local depends=(cmake libsamplerate0-dev libspeexdsp-dev libsdl2-dev libpng-dev libfreetype6-dev fonts-freefont-ttf libboost-filesystem-dev)
    isPlatform "rpi" && depends+=(libraspberrypi-bin libraspberrypi-dev)
    isPlatform "mesa" && depends+=(libgles2-mesa-dev)
    isPlatform "gl" && depends+=(libglew-dev libglu1-mesa-dev)
    isPlatform "x86" && depends+=(nasm)
    isPlatform "vero4k" && depends+=(vero3-userland-dev-osmc)
    # was a vero4k only line - I think it's not needed or can use a smaller subset of boost
    isPlatform "osmc" && depends+=(libboost-all-dev)
    getDepends "${depends[@]}"
}

function _get_repos_mupen64plus-rearmit() {
    local repos=(
        'mupen64plus mupen64plus-core master'
        'mupen64plus mupen64plus-ui-console master'
        'mupen64plus mupen64plus-audio-sdl master'
        'mupen64plus mupen64plus-input-sdl master'
        'mupen64plus mupen64plus-rsp-hle master'
        'mupen64plus mupen64plus-video-rice master'
    )

    if [ ! isPlatform "H6" ]; then
        repos+=(
            'mupen64plus mupen64plus-video-glide64mk2 master'
        )
    fi

    local repo
    for repo in "${repos[@]}"; do
        echo "$repo"
    done
}

function _pkg_info_mupen64plus-rearmit() {
    local mode="$1"
    local repo
    case "$mode" in
        get)
            local hashes=()
            local hash
            local date
            local newest_date
            while read repo; do
                repo=($repo)
                date=$(git -C "$md_build/${repo[1]}" log -1 --format=%aI)
                hash="$(git -C "$md_build/${repo[1]}" log -1 --format=%H)"
                hashes+=("$hash")
                if rp_dateIsNewer "$newest_date" "$date"; then
                    newest_date="$date"
                fi
            done < <(_get_repos_mupen64plus-rearmit)
            # store an md5sum of the various last commit hashes to be used to check for changes
            local hash="$(echo "${hashes[@]}" | md5sum | cut -d" " -f1)"
            echo "local pkg_repo_date=\"$newest_date\""
            echo "local pkg_repo_extra=\"$hash\""
            ;;
        newer)
            local hashes=()
            local hash
            while read repo; do
                repo=($repo)
                # if we have any repos set to a specific git hash (eg GLideN64 then we use that) otherwise check
                if [[ -n "${repo[3]}" ]]; then
                    hash="${repo[3]}"
                else
                    if ! hash="$(rp_getRemoteRepoHash git https://github.com/${repo[0]}/${repo[1]} ${repo[2]})"; then
                        __ERRMSGS+=("$hash")
                        return 3
                    fi
                fi
                hashes+=("$hash")
            done < <(_get_repos_mupen64plus-rearmit)
            # store an md5sum of the various last commit hashes to be used to check for changes
            local hash="$(echo "${hashes[@]}" | md5sum | cut -d" " -f1)"
            if [[ "$hash" != "$pkg_repo_extra" ]]; then
                return 0
            fi
            return 1
            ;;
        check)
            local ret=0
            while read repo; do
                repo=($repo)
                out=$(rp_getRemoteRepoHash git https://github.com/${repo[0]}/${repo[1]} ${repo[2]})
                if [[ -z "$out" ]]; then
                    printMsgs "console" "$id repository failed - https://github.com/${repo[0]}/${repo[1]} ${repo[2]}"
                    ret=1
                fi
            done < <(_get_repos_mupen64plus-rearmit)
            return "$ret"
            ;;
    esac
}

function sources_mupen64plus-rearmit() {
    local commit
    local repo
    while read repo; do
        repo=($repo)
        gitPullOrClone "$md_build/${repo[1]}" https://github.com/${repo[0]}/${repo[1]} ${repo[2]} ${repo[3]}
    done < <(_get_repos_mupen64plus-rearmit)
}

function build_mupen64plus-rearmit() {
    rpSwap on 1000

    local dir
    local params=()
    for dir in *; do
        if [[ -f "$dir/projects/unix/Makefile" ]]; then
            params=()
            isPlatform "rpi1" && params+=("VFP=1" "VFP_HARD=1")
            isPlatform "videocore" || [[ "$dir" == "mupen64plus-audio-omx" ]] && params+=("VC=1")
            if isPlatform "mesa" || isPlatform "mali" || isPlatform "armbian"; then
                params+=("USE_GLES=1")
            fi
            isPlatform "neon" && params+=("NEON=1")
            isPlatform "x11" && params+=("OSD=1" "PIE=1")
            isPlatform "x86" && params+=("SSE=SSE2")
            isPlatform "armv6" && params+=("HOST_CPU=armv6")
            isPlatform "armv7" && params+=("HOST_CPU=armv7")
            isPlatform "aarch64" && params+=("HOST_CPU=aarch64")

            [[ "$dir" == "mupen64plus-video-glide64mk2" ]] && params+=("USE_FRAMESKIPPER=1")
            [[ "$dir" == "mupen64plus-ui-console" ]] && params+=("COREDIR=$md_inst/lib/" "PLUGINDIR=$md_inst/lib/mupen64plus/")
            make -C "$dir/projects/unix" "${params[@]}" clean
            # temporarily disable distcc due to segfaults with cross compiler and lto
            DISTCC_HOSTS="" make -C "$dir/projects/unix" all "${params[@]}" OPTFLAGS="$CFLAGS -O3 -flto"
        fi
    done

    rpSwap off
    md_ret_require=(
        'mupen64plus-ui-console/projects/unix/mupen64plus'
        'mupen64plus-core/projects/unix/libmupen64plus.so.2.0.0'
        'mupen64plus-audio-sdl/projects/unix/mupen64plus-audio-sdl.so'
        'mupen64plus-input-sdl/projects/unix/mupen64plus-input-sdl.so'
        'mupen64plus-rsp-hle/projects/unix/mupen64plus-rsp-hle.so'
        'mupen64plus-video-rice/projects/unix/mupen64plus-video-rice.so'
    )

    if [ ! isPlatform "H6" ]; then
        md_ret_require+=('mupen64plus-video-glide64mk2/projects/unix/mupen64plus-video-glide64mk2.so')
    fi
}

function install_mupen64plus-rearmit() {
    for source in *; do
        if [[ -f "$source/projects/unix/Makefile" ]]; then
            # optflags is needed due to the fact the core seems to rebuild 2 files and relink during install stage most likely due to a buggy makefile
            local params=()
            isPlatform "videocore" || [[ "$dir" == "mupen64plus-audio-omx" ]] && params+=("VC=1")
            if isPlatform "mesa" || isPlatform "mali" || isPlatform "armbian"; then
                params+=("USE_GLES=1")
            fi
            isPlatform "neon" && params+=("NEON=1")
            isPlatform "x11" && params+=("OSD=1" "PIE=1")
            isPlatform "x86" && params+=("SSE=SSE2")
            isPlatform "armv6" && params+=("HOST_CPU=armv6")
            isPlatform "armv7" && params+=("HOST_CPU=armv7")
            isPlatform "aarch64" && params+=("HOST_CPU=aarch64")
            isPlatform "x86" && params+=("SSE=SSE2")

            make -C "$source/projects/unix" PREFIX="$md_inst" OPTFLAGS="$CFLAGS -O3 -flto" "${params[@]}" install
        fi
    done
    rm -f "$md_inst/share/mupen64plus/InputAutoCfg.ini"
}

function configure_mupen64plus-rearmit() {
    addEmulator 1 "${md_id}-gles2rice" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-rice %ROM% %XRES%x%YRES%"
    ! isPlatform "H6" && addEmulator 0 "${md_id}-glide64" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-glide64mk2 %ROM% %XRES%x%YRES%"

    addSystem "n64"

    mkRomDir "n64"
    moveConfigDir "$home/.local/share/mupen64plus" "$md_conf_root/n64/mupen64plus"

    [[ "$md_mode" == "remove" ]] && return

    # copy hotkey remapping start script
    cp "$md_data/mupen64plus.sh" "$md_inst/bin/"
    chmod +x "$md_inst/bin/mupen64plus.sh"

    mkUserDir "$md_conf_root/n64/"

    # Copy config files
    cp -v "$md_inst/share/mupen64plus/"{*.ini,font.ttf} "$md_conf_root/n64/"
    isPlatform "rpi" && cp -v "$md_inst/share/mupen64plus/"*.conf "$md_conf_root/n64/"

    local config="$md_conf_root/n64/mupen64plus.cfg"
    local cmd="$md_inst/bin/mupen64plus --configdir $md_conf_root/n64 --datadir $md_conf_root/n64"

    # if the user has an existing mupen64plus config we back it up, generate a new configuration
    # copy that to rp-dist and put the original config back again. We then make any ini changes
    # on the rp-dist file. This preserves any user configs from modification and allows us to have
    # a default config for reference
    if [[ -f "$config" ]]; then
        mv "$config" "$config.user"
        su "$user" -c "$cmd"
        mv "$config" "$config.rp-dist"
        mv "$config.user" "$config"
        config+=".rp-dist"
    else
        su "$user" -c "$cmd"
    fi

    iniConfig " = " "" "$config"

    if ! grep -q "\[Video-General\]" "$config"; then
        echo "[Video-General]" >> "$config"
    fi
    iniSet "VerticalSync" "True"


    # Create GlideN64 section in .cfg
    if ! grep -q "\[Video-Rice\]" "$config"; then
        echo "[Video-Rice]" >> "$config"
    fi

    iniSet "ScreenUpdateSetting" "7"

    addAutoConf mupen64plus_audio 0
    addAutoConf mupen64plus_compatibility_check 0

    addAutoConf mupen64plus_hotkeys 1
    addAutoConf mupen64plus_texture_packs 1

    chown -R $user:$user "$md_conf_root/n64"
}