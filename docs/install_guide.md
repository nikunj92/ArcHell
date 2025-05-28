# Installation Guide for Alienware m18 Arch Linux Setup

This guide walks you through the installation process for Arch Linux on the Alienware m18, focusing on a modular, maintainable setup with hybrid Intel + NVIDIA graphics and UEFI Secure Boot (optional). Each step includes explanations to help you understand the underlying system and the rationale behind the choices.

---

## Usage

1. **Boot from an Arch Linux installation medium**  
   Use the official Arch ISO to boot into a live environment.

2. **Clone this repository**  
   Clone the helper scripts to simplify the installation process:
   ```bash
   git clone https://github.com/username/arch-helper-scripts.git
   cd arch-helper-scripts
   ```

3. **Run the scripts in sequence as needed**  
   The scripts are modular, allowing you to run only the parts you need.

---

## Example Installation Workflow

### 1. Partition the Drives
The `partitions.sh` script creates the necessary partitions for the dual-drive setup:
- **SSD1 (Windows)**: Preserve the existing ESP (ESP1) for fallback.
- **SSD2 (Arch Linux)**: Create partitions for Btrfs root and ext4 `/home`.

```bash
./partitions.sh
```

### 2. Mount the Partitions
The `mounter.sh` script mounts the partitions with the correct subvolumes for Btrfs:
- Subvolumes like `@`, `@snapshots`, `@pkg`, etc., ensure clean backups and efficient storage.

```bash
./mounter.sh
```

### 3. Install the Base System
The `pacstrapper.sh` script installs the base system with essential packages tailored for the Alienware m18:
- Includes Intel microcode, NVIDIA drivers, and PipeWire for audio.

```bash
./pacstrapper.sh
```

### 4. Generate `fstab`
Generate the filesystem table to ensure the system mounts correctly on boot:
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

### 5. Enter the Chroot Environment
Switch to the new system environment to configure it:
```bash
arch-chroot /mnt
```
> **Note:** Inside the chroot, manually set the timezone, locale, hostname, and hosts file.

### 6. Configure the Bootloader
Use the `efibootmgr_helper.sh` script to set up systemd-boot:
- This lightweight bootloader integrates well with systemd and supports Unified Kernel Images (UKIs).

```bash
efibootmgr_helper.sh show_boot_entries
efibootmgr_helper.sh install_systemd_boot
efibootmgr_helper.sh create_arch_entry
```

### 7. Configure Initramfs and UKI
- Check `/etc/mkinitcpio.conf` to ensure the correct hooks and modules are included.
- Set kernel command-line options in `/etc/kernel/cmdline` (e.g., `nvidia-drm.modeset=1`).

Generate the UKI:
```bash
mkinitcpio -p linux-uki
```

---

## Next Steps

### 1. Generate Secure Boot Keys
If you plan to use Secure Boot, generate the necessary keys:
```bash
./secureboot_keygen.sh generate
```

### 2. Sign the Kernel and Bootloader
Sign the UKI and bootloader with your Secure Boot keys:
```bash
./sbsign_helper.sh sign
```

### 3. Enable Secure Boot
Enable Secure Boot in the BIOS and test the signed kernel.

### 4. Test Graphics
Verify that both Intel and NVIDIA GPUs are working correctly:
- Use `hybrid-status.sh` for diagnostics.

### 5. Set Up the GUI
Install and configure your desktop environment (e.g., KDE Plasma):
```bash
pacman -S plasma xorg sddm
systemctl enable sddm
```

---

## Why This Approach?

1. **Btrfs Subvolumes**: Subvolumes like `@snapshots` and `@pkg` keep backups clean and efficient.
2. **systemd-boot**: Simple, lightweight, and integrates well with UKIs.
3. **Hybrid Graphics**: Optimized for both power efficiency (Intel) and performance (NVIDIA).
4. **Secure Boot**: Optional but provides an additional layer of security.
5. **Modular Scripts**: Allows flexibility and customization for your specific needs.
