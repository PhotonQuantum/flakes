{ pkgs, ... }:

{
  programs.nixvim = {
    colorschemes.catppuccin.settings.integrations = {
      copilot_vim = true;
      lsp_trouble = true;
    };

    plugins = {
      cmp = {
        enable = true;
        settings = {
          completion = {
            completeopt = "menu,menuone,noselect";
            keyword_length = 2;
          };
          snippet.expand = ''
            function(args)
              require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            end
          '';
          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = ''
              cmp.mapping(function(fallback)
                                -- This little snippet will confirm with tab, and if no entry is selected, will confirm the first item
                                if (cmp.visible() and vim.b._copilot.suggestions == nil) then
                                  local entry = cmp.get_selected_entry()
                                  if not entry then
                                    cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                                  else
                                    cmp.confirm()
                                  end
                                else
                                  fallback()
                                end
                              end, {"i","s",}) '';
            "<Up>" = "cmp.mapping.select_prev_item()";
            "<Down>" = "cmp.mapping.select_next_item()";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "nvim_lsp_document_symbol"; }
            { name = "nvim_lsp_signature_help"; }
            { name = "buffer"; }
            { name = "path"; }
            { name = "luasnip"; }
          ];
        };
      };
      copilot-vim = {
        enable = true;
        settings = {
          filetypes = {
            "*" = true;
          };
          assume_mapped = true;
        };
      };
      lsp = {
        enable = true;
        servers = {
          eslint.enable = true;
          pyright.enable = true;
          nixd.enable = true;
        };
      };
      trouble = {
        enable = true;
        lazyLoad = {
          enable = true;
          settings = {
            event = "DeferredUIEnter";
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      luasnip
    ];

    keymaps = [
      {
        mode = "n";
        key = "<Leader>d";
        action = "<cmd>TroubleToggle document_diagnostics<CR>";
        options = {
          silent = true;
          desc = "Document diagnostics";
        };
      }
      {
        mode = [
          "l"
          "i"
        ];
        key = "<D-M-l>";
        action = "<cmd>lua vim.lsp.buf.format{async=true}<CR>";
        options = {
          silent = true;
          desc = "Format";
        };
      }
    ];
  };
}
