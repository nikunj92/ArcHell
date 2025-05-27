## Usage

1. Boot from an Arch Linux installation medium
2. Clone this repository: `git clone https://github.com/username/arch-helper-scripts.git`
3. Run the scripts in sequence as needed

## Example Installation Workflow

```bash
# 1. Make partitions
./partitions.sh

# 2. Mount partitions
./mounter.sh

# 3. Install base system
./pacstrapper.sh

# 4. generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 4. Arch-chroot
arch-chroot /mnt
#  then manually set datetimectl, set locale, hosts, hostname

# 5. setup EFI
efibootmgr_helper.sh show_boot_entries
efibootmgr_helper.sh install_systemd_boot
efibootmgr_helper.sh create_arch_entry

# 5. Configure mkinicpio
# Check /etc/mkinitcpio.conf
# We are using uki so configure uki image creation with preset

# 6 Set cmdline options at /etc/kernel/cmdline, vconsole.conf, install missing deps.

# 6. Generate initramfs/UKI
mkinitcpio -p linux-uki
```

# Next Steps
```bash
  # 1. Generate secure boot keys
./secureboot_keygen.sh generate

  # 2. Sign the kernel/bootloader
./sbsign_helper.sh sign

  # 3. Enable Secure Boot and confirm

  # 4. Test graphics 

  # 5. Setup GUI
```
