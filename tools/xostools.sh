#!/bin/bash

#
# Copyright (C) 2016 halogenOS (XOS)
#

#
# This script was originally made by xdevs23 (http://github.com/xdevs23)
# 


### DEBUG SECTION START

# This variable should not be changed in the script
# It is automatically set in runtime
DEBUG_ENABLED=0

# Print a debug message to screen if $DEBUG_ENABLED == 1
function logd() {
    [ $DEBUG_ENABLED == 1 ] && echo "$@"
}

### DEBUG SECTION END

### VARIABLE DEFINITION START

# Define empty variables
TOOL_ARG=""
TOOL_SUBARG=""
TOOL_THIRDARG=""
TOOL_4ARG=""
TOOL_5ARG=""

# Make sure variables are clean before using them
function vardefine() {
    TOOL_ARG=""
    TOOL_SUBARG=""
    TOOL_THIRDARG=""
    TOOL_4ARG=""
    TOOL_5ARG=""
    BUILD_TARGET_DEVICE=""
    BUILD_TARGET_MODULE=""
    [[ "$@" == *"debug"* ]] && DEBUG_ENABLED=1 || DEBUG_ENABLED=0
    TOOL_ARG="$0"
    TOOL_SUBARG="$1"
    TOOL_THIRDARG="$2"
    TOOL_4ARG="$3"
    TOOL_5ARG="$4"
    logd "TOOL_ARG=$TOOL_ARG"
    logd "TOOL_SUBARG=$TOOL_SUBARG"
    logd "TOOL_THIRDARG=$TOOL_THIRDARG"
}

# Run this when the script is being imported, just in case
vardefine

# Now make sure variables are assigned correctly to the passed arguments
# when using envsetup
if [ "$1" == "envsetup" ]; then
    TOOL_ARG="$1"
    TOOL_SUBARG="$2"
    TOOL_THIRDARG="$3"
    TOOL_4ARG="$4"
    TOOL_5ARG="$5"
    echo -en "\n"
fi

logd "Checking cpu count"

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
logd "Saving current dir"
BEGINNING_DIR="$(pwd)"

### VARIABLE DEFINITION END

# Check if envsetup has already been run if the script is running
# in standalone mode, which should not be the case
logd "Checking for envsetup"

if [ "$(declare -f breakfast > /dev/null; echo $?)" == 1 ]; then
    if   [ -f "envsetup.sh"       ]; then cd ..; source build/envsetup.sh
    elif [ -f "build/envsetup.sh" ]; then        source build/envsetup.sh
    else
        echo "envsetup.sh not found. CD to the root of the source tree first."
        return 860
    fi
    cd $BEGINNING_DIR
fi

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
logd "Sourcing help file"
source $(gettop)/build/tools/xostools/xostoolshelp.sh

# Import all other scripts in the import/ directory
logd "Importing other files"
XD_IMPORT_PATH="$(gettop)/build/tools/xostools/import"
if [ -e "$XD_IMPORT_PATH" ]; then
    for f in $(ls $XD_IMPORT_PATH/); do
        echoxcc "  Importing "
        echo "$f..."
        source $XD_IMPORT_PATH/$f
    done
fi

# Handle the kitchen and automatically eat lunch if hungry
function lunchauto() {
    BUILD_TARGET_DEVICE=""
    if [ ! -z "$TOOL_THIRDARG" ]; then BUILD_TARGET_DEVICE="$TOOL_THIRDARG";
    else                               BUILD_TARGET_DEVICE=""
    fi
    echoe "Eating breakfast..."
    breakfast $BUILD_TARGET_DEVICE
    echoe "Lunching..."
    lunch $BUILD_TARGET_DEVICE
}

logd "Checking arguments"

# Build function
function build() {
    vardefine $@
    logd "Build!"
    
    # Display help if no argument passed    
    if [ -z "$TOOL_SUBARG" ]; then
        xostools_help_build
        return 0
    fi
    
    # Notify that no target device could be found
    if [   -z "$TOOL_THIRDARG" ] || \
       [ ! -z "$TARGET_DEVICE" ]; then
        xostools_build_no_target_device
    else
        # Handle the first argument
        case "$TOOL_SUBARG" in
            
            full | module | mm)
                echob "Starting build..."
                # The default module is bacon, no matter what you specify
                BUILD_TARGET_MODULE="bacon"
                # Of course let's check the kitchen
                lunchauto
                # Now clean if wanted
                ( [ "$TOOL_5ARG" == "noclean" ] || [ "$TOOL_4ARG" == "noclean" ] ) \
                    || make -j4 clean
                # Decide which type of build we need
                [ "$TOOL_SUBARG" == "module" ] && BUILD_TARGET_MODULE="$TOOL_4ARG"
                [ "$TOOL_SUBARG" == "mm"     ] && BUILD_TARGET_MODULE="$TOOL_4ARG"
                # Now start building
                echo "Using $THREAD_COUNT_BUILD threads for build."
                [ "$TOOL_SUBARG" != "mm"     ] && \
                    make -j$THREAD_COUNT_BUILD $BUILD_TARGET_MODULE \
                    || \
                    mmma -j$THREAD_COUNT_BUILD $BUILD_TARGET_MODULE
            ;;
            
            module-list)
                echob "Starting batch build..."
                shift 2
                ALL_MODULES_TO_BUILD="$@"
                make clean
                for module in $ALL_MODULES_TO_BUILD; do
                    echo
                    echob "Building module $module"
                    echo
                    build module $TOOL_THIRDARG $module noclean
                done
                echob "Finished batch build"
            ;;
            
            # Use 'build nothing' to test the build feature without building
            # anything
            nothing)
                echob "Starting build..."
                # Default module is bacon, no matter what you specify
                BUILD_TARGET_MODULE="bacon"
                # Now let's print an useless message for experienced developers
                echoe "Note: You have specified to build \033[4mnothing\033[0m."
                # Tell the user if he has specified to clean or not
                echo -n "Skip clean: " && \
                    ( [ "$TOOL_5ARG" == "noclean" ] || [ "$TOOL_4ARG" == "noclean" ] ) \
                    && echo "yes" || echo "no"
                # Now decide which build type we need
                [ "$TOOL_THIRDARG" == "module" ] && BUILD_TARGET_MODULE="$TOOL_4ARG"
                [ "$TOOL_THIRDARG" == "mm" ]     && BUILD_TARGET_MODULE="$TOOL_4ARG"
                # Print some probably useful lines to let the girl or guy behind
                # the machine know what's going on
                echo "BUILD_TARGET_MODULE=$BUILD_TARGET_MODULE"
                echo "You are doing a '$TOOL_THIRDARG' build."
                echo "Using $THREAD_COUNT_BUILD threads for build."
                echoe "\nBuild command: "
                [ "$TOOL_SUBARG" != "mm" ] && \
                    echo -n "make -j$THREAD_COUNT_BUILD $BUILD_TARGET_MODULE" \
                    || \
                    echo -n "mmma -j$THREAD_COUNT_BUILD $BUILD_TARGET_MODULE"
                echo -en "\n"
            ;;
            
            # Oops.
            *)      echo "Unknown build command \"$TOOL_SUBARG\"."    ;;
        
        esac
    fi
}

# Reposync!! Laziness is taking over.
# Sync with special features and traditional repo.
function reposyncinternal() {
    # You have slow internet? You don't want to consume the whole bandwidth?
    # Ok, then just use "reposynclow" instead of "reposync"
    if [ "$1" == "low" ]; then
        TOOL_ARG="reposynclow"
        TOOL_SUBARG="$2"
        TOOL_THIRDARG="$3"
    else vardefine $@
    fi
    # Same variable definition stuff as always
    REPO_ARG="$TOOL_SUBARG"
    THREADS_REPO=$THREAD_COUNT_N_BUILD
    # Automatic!
    [ -z "$TOOL_SUBARG" ] && REPO_ARG="auto"
    # Let's decide how much threads to use
    # Self-explanatory.
    case $REPO_ARG in
        turbo)      THREADS_REPO=1000       ;;
        faster)     THREADS_REPO=200        ;;
        fast)       THREADS_REPO=64         ;;
        auto)                               ;;
        slow)       THREADS_REPO=6          ;;
        slower)     THREADS_REPO=2          ;;
        single)     THREADS_REPO=1          ;;
        easteregg)  THREADS_REPO=384        ;;
        # People might want to get some good help
        -h | --help | h | help | man )
            if [ $TOOL_ARG == "reposynclow" ]; then
                echo "Syncs without cloning old branches and tags"
                echo "(Fetches only that latest avaliable)"
                echo "So you save on the extra bandwidth you've got!"
            fi
            echo "Usage: $TOOL_ARG <speed>"
            echo "Available speeds are:"
            echo -en "  turbo\n  faster\n  fast\n  auto\n  slow\n"
            echo -en "  slower\n  single\n  easteregg\n\n"
            return 0
        ;;
        # Oops...
        *) echo "Unknown argument \"$REPO_ARG\" for reposync ." ;;
    esac
    
    # Sync!! Use the power of shell scripting!
    echo "Using $THREADS_REPO threads for sync."
    [ $TOOL_ARG == "reposynclow" ] && echo "Saving bandwidth for free!"
    repo sync -j$THREADS_REPO  --force-sync $([ "$TOOL_ARG" == "reposynclow" ] \
        && echo -en "-c -f --no-clone-bundle --no-tags" || echo -en "") $TOOL_THIRDARG
}

# Slow sync? Alright!
function reposync() {
    reposyncinternal low $@
}

# This is repoREsync. It REsyncs. Self-explanatory?
function reporesync() {
    vardefine $@
    echoe "Preparing..."
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
    case "$TOOL_SUBARG" in
        
        # Do a full sync
        #   full:       just delete the working tree directories and sync normally
        #   full-x:     delete everything except manifest and repo tool, means
        #               you need to resync everything again.
        #   full-local: don't update the repositories, only do a full resync locally
        full | full-x | "full-local" | full-network | full-network-x)
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
            # If the user also wants to delete project objects... just do it.
            if [ "$TOOL_SUBARG" == "full-x" ] || \
               [ "$TOOL_SUBARG" == "full-network-x" ]; then
                echoe "Removing repo projects..."
                rm -rf .repo/projects/*
                echoe "Removing repo objects..."
                rm -rf .repo/project-objects/*
            fi
            # And let's sync!
            echo "Starting sync..."
            if [ "$TOOL_SUBARG" == "full-local" ]; then
                repo sync -j$THREAD_COUNT_N_BUILD --local-only --force-sync
            else [[ "$@" == *"low"* ]] && reposynclow || reposync fast \
                $([[ "$TOOL_SUBARG" == "full-network"* ]] && \
                    echo -n "--network-only" || echo -n "")
            fi
        ;;
        
        *)
            TOOL_4ARG="$TOOL_THIRDARG"
            TOOL_THIRDARG="$TOOL_SUBARG"
            TOOL_SUBARG="repo-x"
            [ -z "$TOOL_THIRDARG" ] && xostools_help_reporesync && return 0
            [ "$TOOL_SUBARG" == "repo-x" ] && [ -z "$TOOL_4ARG" ] && \
                xostools_help_reporesync && return 0
            rm -rf $TOOL_THIRDARG
            if [ "$TOOL_SUBARG" == "repo-x" ]; then
                rm -rf .repo/project-objects/$TOOL_4ARG.git
                rm -rf .repo/projects/$TOOL_THIRDARG.git
            fi
            if [ "$TOOL_SUBARG" == "repo-local" ]; then
                repo sync $TOOL_THIRDARG -j$THREAD_COUNT_N_BUILD \
                    --local-only --force-sync --force-broken
            else [[ "$@" == *"low"* ]] && reposynclow auto $TOOL_THIRDARG || \
                reposync auto $TOOL_THIRDARG
            fi
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

# Rest is self-explanatory

logd "Change directory back to beginning dir"

cd $BEGINNING_DIR

logd "Exiting script"

return 0
