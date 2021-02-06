#!/usr/bin/env bash

# This file is part of Nintendont.it RetroPie Project
#
# The Nintendont.it RetroPie Project is the legal property of gleam2003 aka Arnaldo Valente
#

rp_module_id="mupen64plus-ntdnt"
rp_module_desc="N64 emulator MUPEN64Plus"
rp_module_help="ROM Extensions: .z64 .n64 .v64\n\nCopy your N64 roms to $romdir/n64"
rp_module_licence="GPL2 https://raw.githubusercontent.com/mupen64plus/mupen64plus-core/master/LICENSES"
rp_module_section="main"
rp_module_flags=""

function depends_mupen64plus-ntdnt() {
    local depends=(cmake libsamplerate0-dev libspeexdsp-dev libsdl2-dev)
    isPlatform "x11" && depends+=(libglew-dev libglu1-mesa-dev libboost-filesystem-dev)
    isPlatform "x86" && depends+=(nasm)
    getDepends "${depends[@]}"
}

function sources_mupen64plus-ntdnt() {
    local repos=(
        'mupen64plus core'
        'mupen64plus ui-console'
        'mupen64plus audio-sdl'
        'mupen64plus input-sdl'
        'mupen64plus rsp-hle'
        'mupen64plus video-rice'
        'mupen64plus video-glide64mk2'
        )
    local repo
    local dir
    for repo in "${repos[@]}"; do
        repo=($repo)
        dir="$md_build/mupen64plus-${repo[1]}"
        gitPullOrClone "$dir" https://github.com/${repo[0]}/mupen64plus-${repo[1]} ${repo[2]}
    done
}

function build_mupen64plus-ntdnt() {
    rpSwap on 750

    local dir
    local params=()
    for dir in *; do
        if [[ -f "$dir/projects/unix/Makefile" ]]; then
            params=()
            isPlatform "rpi1" && params+=("VFP=1" "VFP_HARD=1")
            isPlatform "videocore" || [[ "$dir" == "mupen64plus-audio-omx" ]] && params+=("VC=1")
            if isPlatform "mesa" || isPlatform "mali"; then
                params+=("USE_GLES=1")
            fi
            isPlatform "neon" && params+=("NEON=1")
            isPlatform "x11" && params+=("OSD=1" "PIE=1")
            isPlatform "x86" && params+=("SSE=SSE2")
            isPlatform "armv6" && params+=("HOST_CPU=armv6")
            isPlatform "armv7" && params+=("HOST_CPU=armv7")
            isPlatform "aarch64" && params+=("HOST_CPU=aarch64")

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
        'mupen64plus-video-glide64mk2/projects/unix/mupen64plus-video-glide64mk2.so'
        )
}

function install_mupen64plus-ntdnt() {
    for source in *; do
        if [[ -f "$source/projects/unix/Makefile" ]]; then
            # optflags is needed due to the fact the core seems to rebuild 2 files and relink during install stage most likely due to a buggy makefile
            export USE_GLES=1
            export NEON=1
            export VFP_HARD=1
            export CPU=ARM
            export ARCH_DETECTED=32BITS
            export PIC=1
            export NEW_DYNAREC=1
            export CFLAGS="-marm -mfpu=neon -mfloat-abi=hard"
            make -C "$source/projects/unix" PREFIX="$md_inst" OPTFLAGS="$CFLAGS -O3 -flto" install
        fi
    done
    rm -f "$md_inst/share/mupen64plus/InputAutoCfg.ini"
}

function configure_mupen64plus-ntdnt() {
    addEmulator 1 "${md_id}-gles2rice$name" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-rice %ROM%"
    addEmulator 0 "${md_id}-glide64" "n64" "$md_inst/bin/mupen64plus.sh mupen64plus-video-glide64mk2 %ROM%"

    addSystem "n64"

    mkRomDir "n64"

    [[ "$md_mode" == "remove" ]] && return

    # copy hotkey remapping start script
    cp "$md_data/mupen64plus.sh" "$md_inst/bin/"
    chmod +x "$md_inst/bin/mupen64plus.sh"

    mkUserDir "$md_conf_root/n64/"

    cp -v "$md_inst/share/mupen64plus/"{*.ini,font.ttf} "$md_conf_root/n64/"
    isPlatform "rpi" && cp -v "$md_inst/share/mupen64plus/"*.conf "$md_conf_root/n64/"

    local config="$md_conf_root/n64/mupen64plus.cfg"
    local cmd="$md_inst/bin/mupen64plus --configdir $md_conf_root/n64 --datadir $md_conf_root/n64"

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
    iniSet "ScreenWidth" "1280"
    iniSet "ScreenHeight" "720"
    iniSet "VerticalSync" "False"
    iniSet "ScreenUpdateSetting" "7"

    addAutoConf mupen64plus_audio 0
    addAutoConf mupen64plus_compatibility_check 0
    addAutoConf mupen64plus_hotkeys 1
    addAutoConf mupen64plus_texture_packs 1

    chown -R $user:$user "$md_conf_root/n64"
}
