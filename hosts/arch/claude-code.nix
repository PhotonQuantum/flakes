{ ... }:
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  programs.claude-code = {
    enable = true;
    package = null;
    agentsDir = ./claude-code/agents;
  };
}
