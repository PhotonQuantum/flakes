let
  flashModel = {
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
      provider = "openrouter-compat";
      default = "~google/gemini-pro-latest";
    };

    auxiliary = {
      approval = flashModel;
      compression = flashModel;
      curator = flashModel;
      mcp = flashModel;
      session_search = flashModel;
      skills_hub = flashModel;
      title_generation = flashModel;
      triage_specifier = flashModel;
      vision = flashModel;
      web_extract = flashModel;
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
