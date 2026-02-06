_:
{
  programs.bat = {
    enable = true;
    # NOTE bat is extensively mre's no way null there's no way to disable it on notory
    config = {
      theme = "base16";
    };
  };
}