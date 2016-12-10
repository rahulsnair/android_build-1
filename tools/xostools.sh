#!/bin/bash

#
# Copyright (C) 2016 halogenOS (XOS)
#

#
# This script was originally made by xdevs23 (http://github.com/xdevs23)
#

# Get the CPU count
# CPU count is either your virtual cores when using Hyperthreading
# or your physical core count when not using Hyperthreading
# Here the virtual cores are always counted, which can be the same as
# physical cores if not using Hyperthreading or a similar feature.
CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)
# Use 4 times the CPU count to build
THREAD_COUNT_BUILD=$(($CPU_COUNT * 4))
# Use doubled CPU count to sync (auto)
THREAD_COUNT_N_BUILD=$(($CPU_COUNT * 2))

# Save the current directory before continuing the script.
# The working directory might change during the execution of specific
# functions, which should be set back to the beginning directory
# so the user does not need to do that manually.
BEGINNING_DIR="$(pwd)"

### BASIC FUNCTIONS START

# Echo with halogen color without new line
function echoxcc() {
    echo -en "\033[1;38;5;39m$@\033[0m"
}

# Echo with halogen color with new line
function echoxc() {
    echoxcc "\033[1;38;5;39m$@\033[0m\n"
}

# Echo with new line and respect escape characters
function echoe() {
    echo -e "$@"
}

# Echo with line, respect escape characters and print in bold font
function echob() {
    echo -e "\033[1m$@\033[0m"
}

# Echo without new line
function echon() {
    echo -n "$@"
}

# Echo without new line and respect escape characters
function echoen() {
    echo -en "$@"
}

### BASIC FUNCTIONS END

# Import help functions
source $(gettop)/build/tools/xostools/xostoolshelp.sh

# Import all other scripts in the import/ directory
local XD_IMPORT_PATH="$(gettop)/build/tools/xostools/import"
if [ -e "$XD_IMPORT_PATH" ]; then
    for f in $(find $XD_IMPORT_PATH/ -type f); do
        echoxcc "  Importing "
        echo "$(basename $f)..."
        source $f
    done
fi

# Handle the kitchen and automatically eat lunch if hungry
function lunchauto() {
    device="$1" 
    echo "Eating breakfast..."
    breakfast $device
    echo "Lunching..."
    lunch $device
}

# Build function
function build() {
    buildarg="$1"
    target="$2"
    cleanarg="$3 $4"
    module="${cleanarg//noclean/}"
    module="${module// /}"
    cleanarg="${cleanarg/$module/}"
    cleanarg="${cleanarg// /}"
    
    # Display help if no argument passed
    if [ -z "$buildarg" ]; then
        xostools_help_build
        return 0
    fi

    # Notify that no target device could be found
    if [ -z "$target" ]; then
        xostools_build_no_target_device
    else
        # Handle the first argument
        case "$buildarg" in

            full | module | mm)
                echob "Starting build..."
                [ -z "$module" ] && module="bacon" || \
                    echo "You have decided to build $module"
                # Of course let's check the kitchen
                lunchauto $target
                # Clean if desired
                [ "$cleanarg" == "noclean" ] || make clean
                # Now start building
                echo "Using $THREAD_COUNT_BUILD threads for build."
                [ "$buildarg" != "mm" ] && \
                    make -j$THREAD_COUNT_BUILD $module || \
                    mmma -j$THREAD_COUNT_BUILD $module
                [ $? -ne 0 ] && return $?
            ;;

            module-list)
                local bm_result
                echob "Starting batch build..."
                shift
                ALL_MODULES_TO_BUILD="$@"
                [[ "$@" == *"noclean"* ]] || make clean
                for module in $ALL_MODULES_TO_BUILD; do
                    [ "$module" == "noclean" ] && continue
                    echo
                    echob "Building module $module"
                    echo
                    build module $TOOL_THIRDARG $module noclean
                    local bm_result=$?
                done
                echob "Finished batch build"
                [ $bm_result -ne 0 ] && return $bm_result
            ;;

            # Oops.
            *) echo "Unknown build command \"$TOOL_SUBARG\"." ;;

        esac
    fi
}

# Reposync!! Laziness is taking over.
# Sync with special features and traditional repo.
function reposync() {
    # You have slow internet? You don't want to consume the whole bandwidth?
    # Same variable definition stuff as always
    REPO_ARG="$1"
    PATH_ARG="$2"
    QUIET_ARG=""
    THREADS_REPO=$THREAD_COUNT_N_BUILD
    # Automatic!
    [ -z "$REPO_ARG" ] && REPO_ARG="auto"
    # Let's decide how much threads to use
    # Self-explanatory.
    case $REPO_ARG in
        turbo)      THREADS_REPO=1000       ;;
        faster)     THREADS_REPO=112        ;;
        fast)       THREADS_REPO=64         ;;
        auto)                               ;;
        slow)       THREADS_REPO=6          ;;
        slower)     THREADS_REPO=2          ;;
        single)     THREADS_REPO=1          ;;
        easteregg)  THREADS_REPO=384        ;;
        quiet)      QUIET_ARG="-q"          ;;
        # People might want to get some good help
        -h | --help | h | help | man | halp | idk )
            echo "Usage: reposync <speed> [path]"
            echo "Available speeds are:"
            echo -en "  turbo\n  faster\n  fast\n  auto\n  slow\n" \
                     "  slower\n  single\n  easteregg\n\n"
            echo "Path is not necessary. If not supplied, defaults to workspace."
            return 0
        ;;
        # Oops...
        *) echo "Unknown argument \"$REPO_ARG\" for reposync ." ;;
    esac

    if [ "$3" == "quiet" ]; then
    QUIET_ARG="-q"
    fi
    # Sync!! Use the power of shell scripting!
    echo "Using $THREADS_REPO threads for sync."
    repo sync -j$THREADS_REPO $QUIET_ARG --force-sync \
        -c -f --no-clone-bundle --no-tags $2 $PATH_ARG
    return $?
}

# This is repoREsync. It REsyncs. Self-explanatory?
function reporesync() {
    echo "Preparing..."
    FRSTDIR="$(pwd)"
    # Let's cd to the top of the working tree
    # Hoping that we don't land in the home directory.
    cd $(gettop)
    # Critical security check to prevent deleting home directory if the build
    # directory has been removed from the work tree for whatever reason.
    if [ "$(pwd)" == "$(ls -d ~)" ]; then
        # Let's warn the user about this bad state.
        echoe "WARNING: 'gettop' is returning your \033[1;91mhome directory\033[0m!"
        echoe "         In order to protect your data, this process will be aborted now."
        return 1
    else
        # Oh yeah, we passed!
        echob "Security check passed. Continuing."
    fi

    # Now let's handle the first argument as always
    case "$1" in

        # Do a full sync
        #   full:       just delete the working tree directories and sync normally
        #   full-x:     delete everything except manifest and repo tool, means
        #               you need to resync everything again.
        #   full-local: don't update the repositories, only do a full resync locally
        full)
            # Print a very important message
            echoe \
                "WARNING: This process will delete \033[1myour whole source tree!\033[0m"
            # Ask if the girl or guy really wants to continue.
            read -p "Do you want to continue? [y\N] : " \
                 -n 1 -r
            # Check the reply.
            [[ ! $REPLY =~ ^[Yy]$ ]] && echoe "\nAborted." && return 1
            # Print some lines of words
            echob "Full source tree resync will start now."
            # Just in case...
            echo  "Your current directory is: $(pwd)"
            # ... read the printed lines so you know what's going on.
            echon "If you think that the current directory is wrong, you will "
            echo  "have now time to safely abort this process using CTRL+C."
            echoen "\n"
            echon  "Waiting for interruption..."
            # Wait 4 lovely seconds which can save your life
            sleep 4
            # Wipe out the above line, now it is redundant
            echoen "\r\033[K\r"
            echoen "Got no interruption, continuing now!"
            echoen "\n"
            # Collect all directories found in the top of the working tree
            # like build, abi, art, bionic, cts, dalvik, external, device, ...
            echo "Collecting directories..."
            ALLFD=$(echo -en $(ls -a))
            # Remove these directories and show the user the beautiful progress
            echo "Removing directories..."
            echo -en "\n\r"
            for ff in $ALLFD; do
                case "$ff" in
                    "." | ".." | ".repo");;
                    *)
                        echo -en "\rRemoving $ff\033[K"
                        rm -rf "$ff"
                    ;;
                esac
            done
            echo -en "\n"
            # And let's sync!
            echo "Starting sync..."
            reposync auto
        ;;

        repo)
            echob "Resyncing $1..."
            rm -rf $1
            reposync single $1
        ;;

        # Help me!
        "")
            xostools_help_reporesync
            cd $FRSTDIR
            return 0
        ;;

    esac
    cd $FRSTDIR
}

function JACK() {
    $(gettop)/prebuilts/sdk/tools/jack-admin stop-server
    $(gettop)/prebuilts/sdk/tools/jack-admin start-server
}

return 0
