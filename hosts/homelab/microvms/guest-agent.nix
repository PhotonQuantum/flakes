{ lib, ... }:

{
  services.qemuGuest.enable = true;

  # Expose the conventional QEMU Guest Agent virtio-serial port.  QEMU runs
  # each MicroVM in its own state directory, so this relative path becomes
  # /var/lib/microvms/<name>/qga.sock on the host.
  microvm.qemu.extraArgs = lib.mkAfter [
    "-device"
    "virtio-serial-device"
    "-chardev"
    "socket,id=qga0,path=qga.sock,server=on,wait=off"
    "-device"
    "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
  ];
}
