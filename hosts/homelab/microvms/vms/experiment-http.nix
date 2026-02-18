{
  services.nginx = {
    enable = true;
    virtualHosts."experiment-http.local" = {
      default = true;
      locations."/" = {
        root = "/etc/nginx/static";
        index = "index.html";
      };
      locations."/internet/" = {
        extraConfig = ''
          resolver 1.1.1.1 8.8.8.8 ipv6=off;
          set $internet_upstream "http://example.com";
          proxy_set_header Host example.com;
          proxy_pass $internet_upstream;
        '';
      };
    };
  };

  environment.etc."nginx/static/index.html".text = ''
    <!doctype html>
    <html>
      <head><title>experiment microvm</title></head>
      <body>hello from experiment-http microvm</body>
    </html>
  '';
}
