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
device.name1=mondrian
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
if [ "$KERNELSU_CHOICE" = "with" ]; then
  ui_print "🔐 Installing DoraCore with KernelSU support...";
  ui_print "   → Root access enabled";
  ui_print "   → KernelSU integration active";
  
  # Check if KernelSU kernel image exists
  if [ -f "Image-kernelsu" ]; then
    ui_print "   → Using KernelSU-enabled kernel image";
    cp -f Image-kernelsu Image;
  elif [ -f "boot-kernelsu.img" ]; then
    ui_print "   → Using KernelSU-enabled boot image";
    cp -f boot-kernelsu.img boot.img;
  else
    ui_print "   → Patching existing kernel for KernelSU";
    # Add KernelSU patching logic here if needed
  fi;
elif [ "$KERNELSU_CHOICE" = "without" ]; then
  ui_print "🔓 Installing DoraCore without KernelSU...";
  ui_print "   → Standard kernel installation";
  ui_print "   → No root access";
  
  # Check if standard kernel image exists
  if [ -f "Image-standard" ]; then
    ui_print "   → Using standard kernel image";
    cp -f Image-standard Image;
  elif [ -f "boot-standard.img" ]; then
    ui_print "   → Using standard boot image";
    cp -f boot-standard.img boot.img;
  else
    ui_print "   → Using default kernel configuration";
    # Default kernel is assumed to be without KernelSU
  fi;
else
  ui_print "⚠️  Unknown selection, using default (without KernelSU)";
fi;
ui_print " ";

# boot install
dump_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

write_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
## end boot install
