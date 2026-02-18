import ./http-with-peer-check.nix {
  title = "routed peer microvm";
  body = "hello from routed-peer-http microvm";
  serverName = "routed-peer-http.local";
  peerVmName = "static-http";
}
