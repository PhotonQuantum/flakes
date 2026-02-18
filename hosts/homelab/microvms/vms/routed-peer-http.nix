import ./http-with-peer-check.nix {
  title = "routed peer microvm";
  body = "hello from routed-peer-http microvm";
  serverName = "routed-peer-http.local";
  peerIp = "10.200.0.2";
  peerName = "static-http";
}
