{ pkgs, ... }:
{
  # 1. using hm to manage the config because we don't want to restart the service every time we change the config
  # 2. not using services.aerospace because we want to override default config path
  environment.systemPackages = [ pkgs.aerospace ];
  launchd.user.agents.aerospace = {
    command = "${pkgs.aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
    };
  };

  system.defaults = {
    dock.expose-group-apps = true;
    spaces.spans-displays = false;
    NSGlobalDomain.NSWindowShouldDragOnGesture = true;
  };
}
