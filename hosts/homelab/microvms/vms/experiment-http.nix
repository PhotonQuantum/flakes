import ./http-with-peer-check.nix {
  title = "experiment microvm";
  body = "hello from experiment-http microvm";
  serverName = "experiment-http.local";
  peerIp = "10.201.0.3";
  peerName = "isolated-peer-http";
}
