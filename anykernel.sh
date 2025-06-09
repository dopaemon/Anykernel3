### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Modified by Keosh for KernelSU selection

### AnyKernel setup
# begin properties
properties() { '
kernel.string=DoraCore GKI 5.10 by dopaemon && keosh - KernelSU Selection
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

### AnyKernel install
# begin attributes
attributes() {
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;
} # end attributes


## boot shell variables
block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh && attributes;

# KernelSU Selection Logic
ui_print " ";
ui_print "-------------------------------------------------";
ui_print "          Processing KernelSU Selection";
ui_print "-------------------------------------------------";
ui_print " ";

# Check if kernel images exist with detailed info
if [ -f "Image-kernelsu" ]; then
  KERNELSU_SIZE=$(stat -c%s "Image-kernelsu" 2>/dev/null || wc -c < "Image-kernelsu" 2>/dev/null || echo "unknown");
fi;

if [ -f "Image-standard" ]; then
  STANDARD_SIZE=$(stat -c%s "Image-standard" 2>/dev/null || wc -c < "Image-standard" 2>/dev/null || echo "unknown");
fi;

if [ "$KERNELSU_CHOICE" = "with" ]; then
  ui_print " - Installing DoraCore with KernelSU support...";
  ui_print "   + Root access enabled";
  ui_print "   + KernelSU integration active";

  # Check if KernelSU kernel image exists
  if [ -f "Image-kernelsu" ]; then
    ui_print "   + Using KernelSU-enabled kernel image";

    # Remove existing Image file if it exists
    [ -f "Image" ] && rm -f "Image";

    cp -f Image-kernelsu Image;
    COPY_RESULT=$?;

    if [ $COPY_RESULT -eq 0 ]; then
      if [ -f "Image" ]; then
        IMAGE_SIZE=$(stat -c%s "Image" 2>/dev/null || wc -c < "Image" 2>/dev/null || echo "unknown");
      fi;
    else
      exit 2;
    fi;
  else
    exit 2;
  fi;
elif [ "$KERNELSU_CHOICE" = "without" ]; then
  ui_print " - Installing DoraCore without KernelSU...";
  ui_print "   + Standard kernel installation";
  ui_print "   + No root access";

  # Check if standard kernel image exists
  if [ -f "Image-standard" ]; then
    ui_print "   + Using standard kernel image";

    # Remove existing Image file if it exists
    [ -f "Image" ] && rm -f "Image";

    cp -f Image-standard Image;
    COPY_RESULT=$?;

    if [ $COPY_RESULT -eq 0 ]; then
      if [ -f "Image" ]; then
        IMAGE_SIZE=$(stat -c%s "Image" 2>/dev/null || wc -c < "Image" 2>/dev/null || echo "unknown");
      fi;
    else
      exit 2;
    fi;
  else
    exit 2;
  fi;
else
  ui_print " - Unknown or empty selection (KERNELSU_CHOICE='$KERNELSU_CHOICE')";
  ui_print "   + Defaulting to standard kernel installation";
  ui_print "   + No root access";

  if [ -f "Image-standard" ]; then
    ui_print "   + Using standard kernel image";

    # Remove existing Image file if it exists
    [ -f "Image" ] && rm -f "Image";

    cp -f Image-standard Image;
    COPY_RESULT=$?;

    if [ $COPY_RESULT -eq 0 ]; then
      if [ -f "Image" ]; then
        IMAGE_SIZE=$(stat -c%s "Image" 2>/dev/null || wc -c < "Image" 2>/dev/null || echo "unknown");
      fi;
    else
      exit 2;
    fi;
  else
    exit 2;
  fi;
fi;
ui_print " ";
ui_print "-------------------------------------------------";
ui_print " ";

# boot install
dump_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

write_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
## end boot install
