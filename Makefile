# Everything to do with the build process is specified in this Makefile. The
# process actually gets quite hairy; scroll down for explanations of how each
# component is built.
#
# See README.md for information about how to build on your system and a list of
# dependencies. 
#
# Is this Makefile horrendously overcomplicated? Maybe. I think part of it is 
# just because `make` syntax is frankly kind of abhorrent.

SRCDIR   := ./src
BUILDDIR := ./build
OUTDIR   := ./out
MOUNTDIR := ./mount

# Important files which will be consumed/produced during the build
BOOTSECTOR := $(BUILDDIR)/bootsector.bin
DISK_IMAGE := $(OUTDIR)/disk.img

# Declare a few phony targets
.PHONY: image

# ==============================================================================
# The Disk Image
# ==============================================================================
# Once the kernel, bootloader, and bootsector are built, we can construct the
# final disk image. This process consists of a couple steps:
# 
#    - Create a blank disk image and initialize the GPT
#    - Create loopback devices for the partitions 
#    - Write the bootloader to the boot partition
#    - Initialize a filesystem (exFAT) for the OS partition
#    - Mount the filesystem and write the kernel
#    - 
#

image: $(BOOTSECTOR) mount

# Create a blank disk image and set up the partitions
$(DISK_IMAGE): 
	dd if=/dev/zero of=disk.img bs=1048576 count=16
	parted disk.img --script mklabel gpt mkpart extended 34s 40s mkpart primary 41s 100%

# Set up loopback devices and mount disk image
mount: $(DISK_IMAGE)
	LOOPBACK_NAME := $(losetup -Pf --show $(DISK_IMAGE))

# Unmount disk image and tear down loopback devices
mount_cleanup:
	umount $(MOUNTDIR)
	losetup -D $(DISK_IMAGE)

# Remove all build files; also creates directories if they don't exist yet
clean:
	mkdir -p $(SRCDIR) $(BUILDDIR) $(OUTDIR) $(MOUNTDIR)
	rm -rf $(SRCDIR)/* $(BUILDDIR)/* $(OUTDIR)/* $(MOUNTDIR)/*

# dd if=/dev/zero of=disk.img bs=1048576 count=16
# parted disk.img --script mklabel gpt mkpart extended 34s 40s mkpart primary 41s 100%
# losetup -Pf --show <file>
# losetup -D <file>
# mkfs.exfat -n volumename DEVICEHERE