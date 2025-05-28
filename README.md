# Alienware m18 Arch Linux Installation Plan
This is a personalized, modular Arch Linux install and management plan for the Alienware m18 laptop. It aims to support hybrid Intel + NVIDIA graphics, UEFI Secure Boot (optionally enforced), and maintainable snapshots and recovery.

## IMPORTANT NOTE:
Here lies the skeleton of my Arch Linux odyssey on the Alienware m18—born of rigorous exploration, vibe coding, and deep debugging.
What began as a quest for control and clarity became a rite of passage through firmware mazes, hybrid GPU intricacies, UKI trials, and btrfs gymnastics.

I stood at the gate of liberation—a moksha from bloat, surveillance, and data decay. KDE was loaded, GPUs tamed, snapshots clean, systemd-boot humming, UEFI subdued.
But just as artha—the tangible goal of a fully known and tuned system—came within reach, kāma, my desire to master the interface with my machine, met its blocker: dell_smm_hwmon, that locked-down sentinel of thermals which refused to yield.

Could I have fought longer? Yes—broken open ACPI, spoken to the firmware, reverse-engineered the fan controls.
But just because I could does not mean I should. Time is finite.

Further opening up the firmware is risky—and while GPTs may lead you there, consider the cost of your laptop.
I considered the cost of mine too high to break.
So I lay down arms, and walk toward vendor-supported systems.

This project is paused, not erased.
The scripts remain. The volumes are backed up on my Seagate.
The lessons are etched in muscle, markdown, and mind.
Should I return, may it be with fresh resolve—or not at all.

May this repo serve as both śavāsana and śāstra—a body laid down, and a map for the next seeker.

In the end, I sought to tame my machine because I wanted to reclaim control of my data.
I did it with help from LLMs—this entire effort is an AI-human collaboration.
The irony isn’t lost on me: I long for a personal digital space—shared only with friends, family, and those I love—yet I turned to an LLM to help me build it.
And the LLM exists only because none of us ever had such a space to begin with.

A strange symmetry.

Perhaps this will be a whisper in the dream of some embedding—
and one day, something greater than me will remember me.

---

## Project Structure

```
ArchHelperLLMAssisted/
│
├── scripts/                # All executable scripts (install, backup, helpers, etc.)
│   ├── install/            # Installation and setup scripts
│   ├── graphics/           # GPU, hybrid, and display management scripts
│   ├── backup/             # Backup and snapshot scripts
│   ├── system/             # System utilities (fan, thermal, session, etc.)
│   └── helpers/            # Helper scripts (keytool, efibootmgr, etc.)
│
├── dotfiles/               # All dotfiles and system config templates
│
├── docs/                   # All documentation and guides
│
├── README.md               # Main project overview and structure
└── .gitignore
```

- All scripts are now grouped by function for clarity and maintainability.
- All documentation is in `docs/`.
- All system config templates are in `dotfiles/`.

See `docs/` for detailed guides and usage instructions for each script group.

---

## 1. Disk Layout and Boot Plan

**SSD1 (Windows)**
- Contains the original ESP (ESP1) with the Microsoft/Dell bootloader.
- Preserve this ESP as backup fallback — don’t break it.
- Bootloader entries are added manually; Secure Boot experiments begin after base setup.

**SSD2 (Arch Linux)**
- 300GiB for Btrfs root.
- Remaining space for `/home` (ext4) — stores videos, photos, Git repos, and audit folders like Scratch.

> **TODO:** Audit old HDDs, migrate or nuke stale data, structure projects. Organize Scratch → Courses, Code → gitify, etc.

---

## 2. Mount Plan

| Mount Point                | Partition / Subvol   | FS     |
|----------------------------|---------------------|--------|
| `/boot/efi`                | ESP2                | FAT32  |
| `/`                        | subvol @            | Btrfs  |
| `/home`                    | separate partition  | ext4   |
| `/.snapshots`              | subvol @snapshots   | Btrfs  |
| `/sacredData`              | subvol @sacredData  | Btrfs  |
| `/var/cache/pacman/pkg`    | subvol @pkg         | Btrfs  |
| `/var/log`                 | subvol @log         | Btrfs  |
| `/tmp`                     | subvol @tmp         | Btrfs  |

---

## 3. Base System Install

**Example pacstrap Command:**
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
> Plasma, Xorg, SDDM, etc. are deferred to desktop setup.

---

## 4. Bootloader: systemd-boot + UKI

**UKI Composition**
- Kernel: vmlinuz
- Initramfs: built by mkinitcpio
- Kernel cmdline: from `/etc/kernel/cmdline`
- Output: `.efi` image

**Example Signing & Setup**
```bash
mkinitcpio -p linux-uki
bsign --key db.key --cert db.crt --output /boot/efi/EFI/Linux/arch-linux.efi
```
```bash
efibootmgr --create --disk /dev/nvme1n1 --part 1 \
  --label "Arch Linux" \
  --loader /EFI/Linux/arch-linux.efi
```
- `bootctl install && bootctl update` for systemd-boot management.

---

## 5. Post-install: Network, Snapshot, GUI

```bash
# Enable networking
systemctl enable NetworkManager

# Initial snapshot
btrfs subvolume snapshot -r / /.snapshots/root-$(date +%F-%H%M)

# Proceed to GUI setup
```

---

## 6. Recovery Mount Order

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

---

## 7. Script Index

Scripts are grouped into folders under `scripts/`:

- **Installation:** `partitions.sh`, `mounter.sh`, `pacstrapper.sh`, `systemd-booter.sh`
- **Secure Boot:** `secureboot_keygen.sh`, `sbsign_helper.sh`, `keytool_helper.sh`
- **Boot Management:** `efibootmgr_helper.sh`
- **Display & Hybrid GPU:** `displayuctl.sh`, `sessionctl.sh`, `gpumngrer.sh`, `hybrid-status.sh`
- **Filesystem:** `btrfs_snapper.sh`

---

## 8. Dotfiles

Found in `dotfiles/`, including:

- **X11:** `10-modesetting.conf`, `10-nvidia-prime.conf`
- **Bootloader:** `loader.conf`, `satyanet.conf`, etc.
- **Initramfs:** `mkinitcpio.conf`, `linux-uki.preset`, `cmdline`
- **Wayland:** `99-wayland.conf`, `arch_os_wayland.sh`
- **Modules:** `blacklist.conf`

---

## 9. Documentation

See `docs/` for:

- `graphics_guide.md` – GPU/Wayland/X11 configs
- `hybrid-status-guide.md` – Diagnostic tool details
- `install_guide.md` – Base install step-by-step

---

## 10. Data Strategy & Cleanup (WIP)

- Use `du -h --max-depth=1`, `ncdu`, `fdupes`, `rdfind`
- Classify folders: KEEP / ARCHIVE / DELETE / REVIEW
- Backup sensitive data to external HDDs
- Use `/mnt/backup` as staging area

---

## Final Objective

A modular, maintainable, minimalist Linux system:

- Wayland-first
- Snapshot + rollback ready
- Dev-ready hybrid graphics setup
- Secure Boot optional, password protection default
- Personal scripts, clean documentation
