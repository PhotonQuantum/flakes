{ inputs, lib, ... }:
let
  homelabSecrets = import ../../secrets/homelab.nix;
  microvmInventory = import ./microvms/inventory.nix { inherit inputs lib; };
  beszelSecretRoot = homelabSecrets.beszel.secretDir;

  mkVmAgentKey = name: {
    name = "beszel_agent_${name}.env";
    value = {
      keyFile = "${beszelSecretRoot}/agents/${name}.env";
      destDir = "/var/keys";
      user = "microvm";
      group = "kvm";
      permissions = "0400";
    };
  };

  mkExtraAgentKey = name: {
    name = "beszel_agent_${name}.env";
    value = {
      keyFile = "${beszelSecretRoot}/agents/${name}.env";
      destDir = "/var/keys";
      user = "root";
      group = "root";
      permissions = "0400";
    };
  };

  extraAgents = builtins.filter (
    name: !(builtins.elem name microvmInventory.beszel.agentMachines)
  ) homelabSecrets.beszel.extraAgents;
in
{
  deployment.keys = {
    "beszel_hub.env" = {
      keyFile = "${beszelSecretRoot}/hub.env";
      destDir = "/var/keys";
      user = "microvm";
      group = "kvm";
      permissions = "0400";
    };
    "beszel_hub_config.yml" = {
      keyFile = "${beszelSecretRoot}/hub_config.yml";
      destDir = "/var/keys";
      user = "microvm";
      group = "kvm";
      permissions = "0400";
    };
    beszel_hub_id_ed25519 = {
      keyFile = "${beszelSecretRoot}/hub_id_ed25519";
      destDir = "/var/keys";
      user = "microvm";
      group = "kvm";
      permissions = "0400";
    };
  }
  // builtins.listToAttrs (map mkVmAgentKey microvmInventory.beszel.agentMachines)
  // builtins.listToAttrs (map mkExtraAgentKey extraAgents);
}
