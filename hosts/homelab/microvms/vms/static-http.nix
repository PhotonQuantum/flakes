import ./http-with-peer-check.nix {
  title = "homelab microvm";
  body = "hello from homelab microvm";
  serverName = "static-http.local";
  peerIp = "10.200.0.3";
  peerName = "routed-peer-http";
}
