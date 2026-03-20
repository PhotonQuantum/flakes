import ./http-with-peer-check.nix {
  title = "isolated peer microvm";
  body = "hello from isolated-peer-http microvm";
  serverName = "isolated-peer-http.local";
  peerVmName = "experiment-http";
}
