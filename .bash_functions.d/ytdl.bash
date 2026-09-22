# Source from ~/.bash_functions; Bash functions require Bash.
# yt-dlp wrapper with consistent download defaults.
#
# Defaults:
#   - MP4 output/remux
#   - English subtitles (including auto-generated)
#   - Embedded metadata and chapters
#   - SponsorBlock sponsor removal
#   - Firefox browser cookies
#
# Downloads are saved to:
#   /home/pmusselman/Videos/YTDL/
#
# Wrapper options are intentionally distinct from yt-dlp's own short options.
ytdl() {
    local mode="download"
    local args=()
    local defaultArgs=()
    local dependency
    local outputDir="/home/pmusselman/Videos/YTDL"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -F|--formats)
                mode="formats"
                shift
                ;;

            -S|--subs)
                mode="subs"
                shift
                ;;

            -I|--info)
                mode="info"
                shift
                ;;

            -P|--playlist)
                args+=("--yes-playlist")
                shift
                ;;

            -V|--video-only)
                args+=("-f" "bestvideo")
                shift
                ;;

            -A|--audio-only)
                mode="audio"
                shift
                ;;

            -N|--no-sponsorblock)
                args+=("--sponsorblock-remove" "none")
                shift
                ;;

            -C|--no-cookies)
                args+=("--no-cookies")
                shift
                ;;

            -q|--quiet)
                args+=("--quiet")
                shift
                ;;

            -v|--verbose)
                args+=("--verbose")
                shift
                ;;

            -h|--help)
                cat <<'EOF'
Custom yt-dlp wrapper

Usage:
  ytdl [OPTIONS] [yt-dlp OPTIONS] URL...

Downloads are saved to:
  /home/pmusselman/Videos/YTDL/

Normal download:
  ytdl "URL"

Wrapper options:
  -F, --formats          List available formats; don't download
  -S, --subs             List available subtitles; don't download
  -I, --info             Show video information; don't download
  -P, --playlist         Force playlist download
  -V, --video-only       Download best video only
  -A, --audio-only       Extract audio as MP3
  -N, --no-sponsorblock  Disable SponsorBlock removal
  -C, --no-cookies       Don't use Firefox cookies
  -q, --quiet             Quiet output
  -v, --verbose           Verbose yt-dlp output
  -h, --help              Show this help

Examples:
  ytdl "URL"
  ytdl -F "URL"
  ytdl -S "URL"
  ytdl -I "URL"
  ytdl -P "PLAYLIST_URL"
  ytdl -A "URL"
  ytdl -N "URL"
  ytdl --playlist-end 5 "PLAYLIST_URL"

Any option not listed above is passed directly to yt-dlp.
EOF
                return 0
                ;;

            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # /home/pmusselman must already exist.
    if [[ ! -d "/home/pmusselman" ]]; then
        echo "Error: /home/pmusselman does not exist." >&2
        return 1
    fi

    # Create the download directory if necessary.
    if [[ ! -d "$outputDir" ]]; then
        mkdir -p "$outputDir" || {
            echo "Error: Unable to create $outputDir." >&2
            return 1
        }
    fi

    if [[ ${#args[@]} -eq 0 ]]; then
        echo "Error: No URL or yt-dlp arguments supplied." >&2
        echo "Run 'ytdl --help' for usage." >&2
        return 1
    fi

    for dependency in yt-dlp ffmpeg; do
        if ! command -v "$dependency" &>/dev/null; then
            printf "Error: %s is not installed or not in PATH.\n" "$dependency" >&2
            return 1
        fi
    done

    case "$mode" in
        formats)
            yt-dlp -F "${args[@]}"
            return $?
            ;;

        subs)
            yt-dlp --list-subs "${args[@]}"
            return $?
            ;;

        info)
            yt-dlp --dump-single-json --no-download "${args[@]}"
            return $?
            ;;

        audio)
            defaultArgs=(
                -P "$outputDir"
                -x
                --audio-format mp3
                --embed-metadata
                --sponsorblock-remove sponsor
                --cookies-from-browser firefox
            )
            ;;

        download)
            defaultArgs=(
                -P "$outputDir"
                --merge-output-format mp4
                --remux-video mp4
                --embed-subs
                --sub-langs en
                --write-auto-subs
                --embed-metadata
                --embed-chapters
                --sponsorblock-remove sponsor
                --cookies-from-browser firefox
            )
            ;;
    esac

    echo "Running yt-dlp..."
    yt-dlp "${defaultArgs[@]}" "${args[@]}"
    local exitCode=$?

    if [[ $exitCode -eq 0 ]]; then
        echo "yt-dlp: Download completed successfully."
    else
        printf "yt-dlp: Download failed (exit code %s).\n" "$exitCode" >&2
    fi

    return "$exitCode"
}
