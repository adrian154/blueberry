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
#    - Create a filesystem for the OS partition and write the kernel.
#
# 

# Directories
SRCDIR   := ./src
BUILDDIR := ./build
OUTDIR   := ./out