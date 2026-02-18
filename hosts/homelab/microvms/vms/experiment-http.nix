import ./http-with-peer-check.nix {
  title = "experiment microvm";
  body = "hello from experiment-http microvm";
  serverName = "experiment-http.local";
  peerVmName = "isolated-peer-http";
}
