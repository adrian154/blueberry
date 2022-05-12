# Everything to do with the build process is specified in this Makefile. The
# process actually gets quite hairy; scroll down for explanations of how each
# component is built.
#
# See README.md for information about how to build on your system and a list of
# dependencies. 
#
# Is this Makefile horrendously overcomplicated? Maybe. I think part of it is 
# just because `make` syntax is frankly kind of abhorrent.

BUILDDIR := ./build
OUTDIR   := ./out
MOUNTDIR := ./mount

# Important files which will be consumed/produced during the build
BOOTSECTOR := $(BUILDDIR)/bootsector.bin
DISK_IMAGE := $(OUTDIR)/disk.img

# We always use /dev/loop7 for the sake of simplicity, change this if it con-
# flicts with existing loopback devices on your system.
LOOPBACK          := /dev/loop7
BOOT_PART_LOOPDEV := $(LOOPBACK)p1
OS_PART_LOOPDEV   := $(LOOPBACK)p2 

# Declare a few phony targets
.PHONY: image clean clean-disk-image

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
#    - Unmount, clean up loopback devices
#
# Annoyingly enough, this process must be run as the superuser because `mount`
# demands it.

# Assemble the final disk image. The bootsector is copied in two parts to avoid
# overwriting the MBR--even though we're using GPT, there's still an MBR to re-
# main compatible with older machines.
image: $(DISK_IMAGE) $(BOOTSECTOR)
	dd if=$(BOOTSECTOR) of=$(DISK_IMAGE) conv=notrunc bs=446 count=1
	dd if=$(BOOTSECTOR) of=$(DISK_IMAGE) conv=notrunc bs=1 count=2 skip=510 seek=510
	umount $(MOUNTDIR)
	losetup -D $(DISK_IMAGE)

# Create a blank disk image, set up the partitions, and create loopback devices
$(DISK_IMAGE): cleanup-disk
	dd if=/dev/zero of=$(DISK_IMAGE) bs=1048576 count=16
	parted $(DISK_IMAGE) --script mklabel gpt mkpart "BOOT" 34s 40s mkpart "Blueberry" 41s 100%
	losetup -P $(LOOPBACK) $(DISK_IMAGE)
	mkfs.exfat -n "Blueberry" $(OS_PART_LOOPDEV)
	mkdir -p $(MOUNTDIR)
	mount $(OS_PART_LOOPDEV) $(MOUNTDIR)

# Remove old disk images and loopback devices; tear down any mount points that
# haven't been released yet.
cleanup-disk:
	-umount $(MOUNTDIR)
	losetup -D $(DISK_IMAGE)
	mkdir -p $(OUTDIR)
	rm -rf $(OUTDIR)/*

# Remove all build files; also creates directories if they don't exist yet
clean: cleanup-disk
	mkdir -p $(BUILDDIR)
	rm -rf $(BUILDDIR)/*

# ==============================================================================
# The Bootsector
# ==============================================================================
# The bootsector is very easy to assemble, since it has no dependencies.

$(BOOTSECTOR): $(BUILDDIR) src/boot/bootsector.asm
	nasm src/boot/bootsector.asm -f bin -o $(BUILDDIR)/bootsector.bin

# Recipe which creates the build directory. 
$(BUILDDIR):
	mkdir -p $(BUILDDIR)