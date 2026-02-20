{ ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."example-http.local" = {
      default = true;
      locations."/" = {
        root = "/etc/nginx/static";
        index = "index.html";
      };
    };
  };

  environment.etc."nginx/static/index.html".text = ''
    <!doctype html>
    <html>
      <head><title>example microvm</title></head>
      <body>hello from example-http microvm</body>
    </html>
  '';
}
