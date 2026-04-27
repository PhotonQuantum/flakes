{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.vicinae = {
    enable = true;
    package = pkgs.emptyDirectory.overrideAttrs (_: {
      version = "0.20.14";
      meta.mainProgram = "empty-directory";
    });

    settings = {
      telemetry.system_info = false;
      theme.dark.name = "catppuccin-mocha";
    };

    extensions = [
      (config.lib.vicinae.mkExtension {
        name = "nix";
        src = pkgs.generated.vicinae_extensions.src + "/extensions/nix";
      })
      (config.lib.vicinae.mkExtension {
        name = "arch-packages";
        src = pkgs.generated.vicinae_extensions.src + "/extensions/arch-packages";
      })
    ];
  };

  home.activation.vicinae-refresh-apps = lib.mkForce (
    lib.hm.dag.entryAfter [ "installPackages" ] ''
      /usr/bin/vicinae deeplink vicinae://launch/core/refresh-apps
    ''
  );

  home.activation.vicinaeSystemdUnit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="$PATH:/usr/bin" $DRY_RUN_CMD systemctl --user enable vicinae.service
  '';
}
