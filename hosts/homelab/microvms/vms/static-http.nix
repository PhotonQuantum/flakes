import ./http-with-peer-check.nix {
  title = "homelab microvm";
  body = "hello from homelab microvm";
  serverName = "static-http.local";
  peerVmName = "routed-peer-http";
}
