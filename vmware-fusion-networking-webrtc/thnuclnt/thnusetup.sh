#!/bin/bash

# --------------------------------------------------
# Must be ran as root
# --------------------------------------------------

if [ $EUID -ne 0 ]; then
   echo "Root permission required!"
   exit 1
fi

# --------------------------------------------------
# System commands:
# --------------------------------------------------

CP=/bin/cp
MKDIR=/bin/mkdir
RM=/bin/rm
MV=/bin/mv
CAT=/bin/cat

# --------------------------------------------------
# Locate CUPS config tool and locations
# --------------------------------------------------

CUPS_CONFIG="/usr/bin/cups-config"
CUPS_BIN=`$CUPS_CONFIG --serverbin`
if [ ! -d $CUPS_BIN ]; then
   echo "Failed to find CUPS bin $CUPS_BIN"
   exit 1
fi
CUPS_ROOT=`$CUPS_CONFIG --serverroot`
if [ ! -d $CUPS_ROOT ]; then
   echo "Failed to find CUPS root $CUPS_ROOT"
   exit 1
fi

THNUCLNT_DIR=/etc/thnuclnt

# --------------------------------------------------
# Confirm file exits; exit if not
# --------------------------------------------------

function checkFileExists() {
   if [ ! -f "$1" ]; then
      echo "$1 does not appear to be installed"
      exit 1
   fi
}

# --------------------------------------------------
# Restart cupsd to load ThinPrint filter
# --------------------------------------------------

function restartCUPS() {
   echo "Restarting printing services"
   killall -HUP cupsd
}

# --------------------------------------------------
# Remove previously installed files
# --------------------------------------------------

function doUninstall() {
   # Where the installer put the ThinPrint files:
   THNUDIR="$1"
   THNU_MANIFEST="$THNUDIR"/manifest

   # Delete the global ThinPrint directory
   echo "Deleting $THNUCLNT_DIR"
   if [ -d "$THNUCLNT_DIR" ]; then
      $RM -rf "$THNUCLNT_DIR"
   fi

   # Delete everything in the manifest
   if [ -f "$THNU_MANIFEST" ]; then
      for f in `$CAT "$THNU_MANIFEST"`; do
         echo "Deleting $f"
         $RM -f $f
      done
      $RM -f "$THNU_MANIFEST"
   fi

   restartCUPS
}

# --------------------------------------------------
# Install files that have unknown destinations
# --------------------------------------------------

function doInstall() {
   # Where the installer put the ThinPrint files:
   THNUDIR="$1"
   THNU_MANIFEST="$THNUDIR"/manifest
   $RM -f "$THNU_MANIFEST"

   # Create the global ThinPrint directory
   $MKDIR "$THNUCLNT_DIR"
   if [ ! -d "$THNUCLNT_DIR" ]; then
      echo "Failed to create $THNUCLNT_DIR"
      exit 1
   fi

   # Install the .thnumod file
   checkFileExists "$THNUDIR/.thnumod"
   echo "Copying .thnumod to $THNUCLNT_DIR"
   $CP -f "$THNUDIR/.thnumod" "$THNUCLNT_DIR"
   # Record in manifest for subsequent uninstallation
   echo "$THNUCLNT_DIR/.thnumod" >> "$THNU_MANIFEST"

   # Install the thnuclnt.conf file
   checkFileExists "$THNUDIR/thnuclnt.conf"
   echo "Copying thnuclnt.conf to $THNUCLNT_DIR"
   $CP -f "$THNUDIR/thnuclnt.conf" "$THNUCLNT_DIR"
   # Record in manifest for subsequent uninstallation
   echo "$THNUCLNT_DIR/thnuclnt.conf" >> "$THNU_MANIFEST"

   # Install the CUPS config
   for f in thnuclnt.convs thnuclnt.types; do
      checkFileExists "$THNUDIR/$f"
      echo "Copying $f to $CUPS_ROOT"
      $CP -f "$THNUDIR/$f" "$CUPS_ROOT/$f"
      # Bug 1040719: Don't add the CUPS files to the manifest.
      ## Record in manifest for subsequent uninstallation
      #echo "$CUPS_ROOT/$f" >> "$THNU_MANIFEST"
   done

   # Install CUPS filter
   checkFileExists "$THNUDIR/thnucups"
   echo "Copying thnucups to $CUPS_BIN/filter"
   $CP -f "$THNUDIR/thnucups" "$CUPS_BIN/filter"
   # Bug 1040719: Don't add the CUPS files to the manifest.
   ## Record in manifest for subsequent uninstallation
   #echo "$CUPS_BIN/filter/thnucups" >> "$THNU_MANIFEST"

   restartCUPS
}


# --------------------------------------------------
# Re-install if installed files are missing
# --------------------------------------------------

function doReinstall() {
   # Where the installer put the ThinPrint files:
   THNUDIR="$1"
   THNU_MANIFEST="$THNUDIR"/manifest

   for f in `$CAT "$THNU_MANIFEST"`; do
      if [ ! -f "$f" ]; then
         doUninstall "$THNUDIR"
         doInstall "$THNUDIR"
         break
      fi
   done
}


# --------------------------------------------------
# Verify arguments
# --------------------------------------------------
if [ $# == 2 ] && [ "$1" == "-u" ]; then
   echo "Uninstalling"
   doUninstall "$2"
elif [ $# == 2 ] && [ "$1" == "-i" ]; then
   echo "Installing files from $2"
   doInstall "$2"
elif [ $# == 2 ] && [ "$1" == "-r" ]; then
   echo "Verifying and re-installing files from $2"
   doReinstall "$2"
else
   echo "Invalid arguments"
   echo "Usage: ${0/*\//} -i <thnuclnt_dir> to install"
   echo "       ${0/*\//} -u <thnuclnt_dir> to uninstall"
   echo "       ${0/*\//} -r <thnuclnt_dir> to verify and re-install if necessary"
   exit 1
fi
exit 0

