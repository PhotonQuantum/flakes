let
  deepseekFlash = {
    provider = "deepseek";
    model = "deepseek-v4-flash";
  };
  visionModel = {
    provider = "openrouter-compat";
    model = "~google/gemini-flash-latest";
  };
in
{
  hermes = {
    providers.openrouter-compat = {
      name = "openrouter-compat";
      base_url = "https://openrouter.ai/api/v1";
      key_env = "OPENROUTER_API_KEY";
      api_mode = "chat_completions";
    };

    model = {
      provider = "deepseek";
      default = "deepseek-v4-pro";
    };

    auxiliary = {
      approval = deepseekFlash;
      compression = deepseekFlash;
      curator = deepseekFlash;
      mcp = deepseekFlash;
      session_search = deepseekFlash;
      skills_hub = deepseekFlash;
      title_generation = deepseekFlash;
      triage_specifier = deepseekFlash;
      vision = visionModel;
      web_extract = deepseekFlash;
    };

    memory = {
      provider = "hindsight";
      memory_enabled = true;
      user_profile_enabled = true;
    };

    web = {
      search_backend = "firecrawl";
      extract_backend = "firecrawl";
    };

    streaming = {
      enabled = true;
      transport = "auto";
      edit_interval = 0.8;
      buffer_threshold = 24;
      fresh_final_after_seconds = 60;
    };

    plugins.enabled = [
      "disk-cleanup"
      "hermes-lcm"
    ];

    context.engine = "lcm";

    security.allow_lazy_installs = true;

    terminal.cwd = "/opt/data/workspace";
  };

  hindsight = {
    mode = "local_external";
    api_url = "http://127.0.0.1:8888";
    bank_id = "hermes";
    recall_budget = "mid";
    memory_mode = "hybrid";
    auto_recall = true;
    auto_retain = true;
  };
}
