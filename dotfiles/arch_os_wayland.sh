#/etc/profile.d/arch_os_wayland.sh or bash_profile
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
  exec dbus-run-session startplasma-wayland
fi