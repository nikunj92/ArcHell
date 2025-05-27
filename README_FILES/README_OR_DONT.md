# Alienware m18 Arch Linux Installation Plan

## Step 1: Drive Setup & Boot Configuration

### Storage Layout

#### SSD1 (Windows)
- Installing bootloader on ESP
- Existing ESP (ESP1) with Microsoft bootloader and Dell 

( TODO: backup restore.  Scratch -> Courses and Learning -> (university astronomy) 
                          Code -> gitify and sort my shit
. Need to sort all projects )

#### SSD2 (Arch Linux)
- root (500GiB) for Linux installation
- home (rest) for home [- large data partition with Scratch to sort. -> Mark the ssd uuid . - nice to have opt to extend ssd life and optimize storage.{ocassional dumps to Windows}] -> will contain git repo. Videos. Photos.

I am a Data mess!!! TBs of unstruct data! What the hell!!!! Archive and manage this shit better or nuke it man! Anyway carrying on

### Mount Plan (at install time)
| Mount Point | Partition | Type |
|-------------|-----------|------|
| `/boot/efi` | ESP2 | FAT32 |
| `/` | btrfs root subvol (@) | BTRFS |
| `/home` | separate partition | ext4 |
| `/.snapshots` | btrfs subvol (@snapshots) | BTRFS |
| `/sacredData` | btrfs subvol (@sacredData) | BTRFS |
| `/var/cache/pacman/pkg` | btrfs subvol (@pkg) | BTRFS |
| `/var/log` | btrfs subvol (@log) | BTRFS |
| `/tmp` | btrfs subvol (@tmp) | BTRFS |

### Boot Mode

- Use UEFI Audit Mode (allows unsigned boot, suitable for setup/testing)
- Secure Boot Enforcing fails due to:
  - MOK integration issues on Dell firmware
- Wporkaround: backed up ESP and stored on seperate media. Dont break this! Now installing systemd and ignoring the rest. Need to boot in audit anyway - may as well do it from here.
- Learning UEFI + signing - remains a non priority - a curiousity, not required - password protection is sufficient and only way to really protect. Encrypt disks if you want. Seperate a recovery. Dont brick it.

## Step 2: Filesystem & Subvolume Strategy

### Btrfs Subvolumes (on root)
- `@` → System root
- `@snapshots` → Base system snapshots
- `@sacredData` → Sensitive data backed up externally
- `@pkg` → Package cache (excluded from backups)
- `@log` → System logs (excluded from backups)
- `@tmp` → Temp files (excluded from backups)

### Notes
- `/home` is ext4 and excluded from system snapshots
- Subvol separation ensures backups stay clean and small
- Git projects go in `/opt` or similar under `@` - Need to walk towards copying and auditing and archiving and deleting the data. I could throw the recycle bin in my old 500G HDDs even - pull the ssd data on the newly formatted SEAGATE!! those HDDs are failing!
- 

## Step 2.5: Base System Pacstrap & Hardware Mapping

### Pacstrap Strategy

This section selects foundational packages tailored to the Alienware m18 hardware to ensure that networking, audio, graphics, and performance features work out of the box.

#### Base System
- `base linux linux-firmware mkinitcpio btrfs-progs`
  - base, linux, linux-firmware: Core system
  - mkinitcpio: For initramfs and later UKI creation
  - btrfs-progs: Filesystem tools for subvolume setup

#### CPU & Microcode
- `intel-ucode`
  - Intel hybrid CPU fixups, required for proper initialization

#### GPU & Graphics Drivers
```
mesa vulkan-intel libva-intel-driver libva-utils
nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
```
- Hybrid graphics setup (Intel + NVIDIA 4090)
- Includes support for hardware acceleration (VA-API, Vulkan)
- NVIDIA packages are DKMS-based for kernel compatibility

#### Sound & Audio Stack
- `sof-firmware alsa-ucm-conf alsa-utils pipewire wireplumber`
- Dell m18 uses SOF?; PipeWire for unified audio stack

#### Network
- `networkmanager iwd`
- NetworkManager as main controller
- iwd as backend for Wi-Fi

#### Utilities & Extras
- `git sudo vim efibootmgr dosfstools man-db man-pages`
- Developer tools, UEFI management, basic command-line utilities

### Example Pacstrap Command

```bash
pacstrap /mnt \
  base linux linux-firmware mkinitcpio btrfs-progs \
  intel-ucode sof-firmware alsa-utils alsa-ucm-conf pipewire wireplumber \
  mesa vulkan-intel libva-intel-driver libva-utils \
  nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings \
  networkmanager iwd \
  git sudo vim efibootmgr dosfstools man-db man-pages \
  lsof rsync htop unzip tar
```

> Note: GUI packages like plasma, xorg, sddm are deferred to the desktop setup phase

### Manual Snapshot Command

```bash
btrfs subvolume snapshot -r / /.snapshots/root-$(date +%F-%H%M)
```

## Step 3: Bootloader & Secure Boot

### Bootloader

**systemd-boot**: Lightweight and native to systemd; it simplifies UEFI boot management and supports Unified Kernel Images (UKIs) natively.

### UKI Structure

Built using mkinitcpio, generating a .efi file containing:
- The kernel (vmlinuz)
- Initramfs (built from `/etc/mkinitcpio.conf`)
- Kernel command line (via `/etc/kernel/cmdline`)

### Signing Flow

Use bsign to create a signed Unified Kernel Image:

```bash
mkinitcpio -p linux-uki
bsign --key db.key --cert db.crt --output /boot/efi/EFI/Linux/arch-linux.efi
```

### Common Signing Diagnostics

Check if the key loads:
```bash
openssl x509 -in db.crt -text -noout
openssl rsa -in db.key -check
```

Verify a signed EFI binary:
```bash
sbverify --list /boot/efi/EFI/Linux/arch-linux.efi
```

Sign manually (alternative):
```bash
sbsign --key db.key --cert db.crt --output signed.efi original.efi
```

### UEFI Boot Entry with efibootmgr

```bash
efibootmgr --create --disk /dev/nvme1n1 --part 1 \
  --label "Arch Linux" \
  --loader /EFI/Linux/arch-linux.efi
```

Check current entries:
```bash
efibootmgr -v
```

### Systemd Integration

systemd-boot reads loader entries from:
- `/boot/efi/loader/loader.conf`
- `/boot/efi/loader/entries/*.conf`

Example entry:
```
# /boot/efi/loader/entries/arch.conf
title   Arch Linux
linux   /EFI/Linux/arch-linux.efi
options root=UUID=<root-part-uuid> rw
```

Enable systemd-boot installation and updates:
```bash
bootctl install
bootctl update
```

### Testing & Validation

1. Reboot and select the new boot entry
2. If Secure Boot is enabled and signing is valid, system should boot cleanly
3. If in audit mode, boot will succeed even without signature enforcement
4. Validate functionality, then transition to enforcing Secure Boot if desired

> Always back up ESPs before experimenting. Keeping ESP1 (Windows) untouched ensures fallback safety but I live dangerously ;)

### Bootloader Summary

- **systemd-boot** (simple + supports Unified Kernel Image)
- **UKI Structure**
  - Built with mkinitcpio
  - Components:
    - Kernel (vmlinuz)
    - Initramfs
    - Embedded cmdline
  - Output: .efi image
- **Signing Flow**
  ```bash
  mkinitcpio -p linux-uki
  sbsign --key db.key --cert db.crt --output /boot/efi/EFI/Linux/arch-linux.efi
  ```
- **Testing & Validation**
  - Boot from `/boot/efi/EFI/Linux/arch-linux.efi`
  - If boot succeeds → enroll keys manually in firmware (later)
  - Once key enrollment is possible, switch Secure Boot to enforcing

## After Base Setup

1. Enable network (iwd or NetworkManager)
2. Confirm drivers, microcode, and firmware are functional
3. Snapshot the root volume as rollback point
4. Proceed to GUI installation and customizations

## Helpful Commands, Recovery, and Tips

### Mounting Order for Recovery

If boot fails and you need to recover using a live USB:

```bash
mount -o subvol=@ /dev/nvme1n1pX /mnt
mount -o subvol=@snapshots /dev/nvme1n1pX /mnt/.snapshots
mount -o subvol=@sacredData /dev/nvme1n1pX /mnt/sacredData
mount -o subvol=@pkg /dev/nvme1n1pX /mnt/var/cache/pacman/pkg
mount -o subvol=@log /dev/nvme1n1pX /mnt/var/log
mount -o subvol=@tmp /dev/nvme1n1pX /mnt/tmp
mount /dev/nvme1n1pY /mnt/home
mount /dev/nvme1n1pZ /mnt/boot/efi
arch-chroot /mnt
```

> Replace /dev/nvme1n1pX with appropriate partitions.

### Helpful Tools

- `lsblk`, `blkid`, `fdisk -l`: Disk layout info
- `efibootmgr -v`: Show UEFI boot entries
- `bootctl status`: Validate systemd-boot install
- `openssl x509`, `sbsign`, `sbverify`: For Secure Boot signing and validation
- `mkinitcpio -p linux-uki`: Rebuild UKI after kernel/initramfs changes
- `btrfs subvolume list /`: Audit subvolumes
- `btrfs send/receive`: Backup snapshot to external drive
- `rsync -aAXv`: Good for backup/restore

### Note: Future Recovery Partition

Consider building a small dedicated recovery partition:
- Base Arch install
- Networking (iwd/NetworkManager)
- Filesystem + signing tools
- No GUI, but capable of chroot rescue

## Additional TODO: Seagate HDD Management

- The 2TB Seagate external HDD is formatted and mountable. Will use this to grab the data from the other 2 500G HDDs. They are old. Seagate seems to be decent but I did suffer data loss. Need to test the two old HDDs
- Still pending: full data audit, cleanup, and deduplication
- Eventually mount to `/mnt/backup` or similar
- Use rsync or btrfs send workflows for snapshot offloading
- Consider scheduling periodic backups from `@sacredData`, `@snapshots`

### Data Auditing Plan (WIP)

1. Traverse disk with `du -h --max-depth=1` to spot large folders
2. Use `ncdu` for interactive exploration
3. Consider `fdupes` or `rdfind` for finding duplicate files
4. Develop exclusion list for bulk rsync or copy jobs
5. Categorize files into: KEEP / ARCHIVE / DELETE / REVIEW

## Final Objective

Create an educational, intentional README.md documenting:
- Minimalist Arch + UEFI setup on Alienware m18
- Secure Boot handling (will be defferred. It maybe useful but a password is needed anyway. So can passwd protect and secure without UEFI if needed. UEFI custom key management is tricky and BIOS level)
- Clean btrfs + ext4 design with intentional backups
- Git-ready, dev-optimized system
- Modular, snapshot-friendly, long-term maintainable setup

# Lessons
 - UKI_CMDLINE doesnt exist - pay attention to mkinitcpio preset and base settings.
 - loading requires btrfs in kernel
 - basic install systemd - update add arch entry to be something that is more like just adding systemd boot manager
 - Arch entry gets auto detected in systemd boot - trouble shoot later