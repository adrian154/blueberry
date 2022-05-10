# Everything to do with the build process is specified in this Makefile.
# Creating the final disk image involves a couple steps:
#  
#    - Assemble the bootsector and bootloader; compile the kernel.
#        - This produces three files, one for each component. 
#    - Create a blank disk image.
#    - Set up a GPT and make partitions.
#        - Two partitions are made; one is a flat binary partition containing
#          the bootloader, and the other is an ExFAT partition containing the
#          kernel.
#    - Create loopback devices for the partitions.
#    - Write the bootloader to the boot partition.
#    - Create a filesystem for the OS partition, mount it, and write the kernel.
#
# See README.md for information about how to build on your system and a list of
# dependencies. 

# Directories
SRCDIR   := ./src
BUILDDIR := ./build
OUTDIR   := ./out

# dd if=/dev/zero of=disk.img bs=1048576 count=1
# parted disk.img --script mklabel gpt mkpart primary 0 1M
# losetup -Pf --show <file>
# losetup -D <file>
# mkfs.exfat -n volumename DEVICEHERE