{ pkgs, config, ... }:

{
  programs.nixvim = {
    enable = true;
    extraPackages = with pkgs; [ rust-analyzer ];
    opts = {
      number = true;
      relativenumber = true;
      clipboard = "unnamedplus";
      undofile = true;
      undodir = config.lib.nixvim.mkRaw ''vim.fn.stdpath("data") .. "/undo"'';
      guifont = "Jetbrains Mono:h14";
      hlsearch = true;
    };
    globals = {
      startuptime_exe_path = "/etc/profiles/per-user/${config.home.username}/bin/nvim";
    };
    extraConfigLua = ''
      require('smear_cursor').setup({
        legacy_computing_symbols_support = true,
      })
    '';
    luaLoader.enable = true;
    colorschemes.catppuccin = {
      enable = true;
      lazyLoad.enable = true;
      settings = {
        flavour = "auto";
        integrations = {
          copilot_vim = true;
          lsp_trouble = true;
          which_key = true;
        };
      };
    };
    plugins =
      let
        lazy = [
          "auto-save"
          "which-key"
          "trouble"
          "treesitter"
          "telescope"
        ];
        lazyLoadInject = {
          lazyLoad = {
            enable = true;
            settings = {
              event = "DeferredUIEnter";
            };
          };
        };
        plugs = {
          nix.enable = true;
          auto-save.enable = true;
          auto-session.enable = true;
          dressing.enable = true;
          gitsigns.enable = true;
          wakatime.enable = true;
          which-key.enable = true;
          lz-n.enable = true;
          treesitter = {
            enable = true;
            settings = {
              indent.enable = true;
              highlight.enable = true;
              incremental_selection = {
                enable = true;
                keymaps = {
                  init_selection = "¬";
                  node_decremental = "˙";
                  node_incremental = "¬";
                };
              };
            };
          };
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
          telescope = {
            enable = true;
            extensions = {
              frecency.enable = true;
              file-browser.enable = true;
            };
          };
          lualine = {
            enable = true;
            settings = {
              theme = "catppuccin";
              sections = {
                lualine_c = [
                  {
                    __unkeyed = "filename";
                    path = 3;
                  }
                  "lsp_progress"
                ];
              };
            };
          };
          bufferline = {
            enable = true;
            # settings = {
            #   highlights = config.lib.nixvim.mkRaw ''require("catppuccin.groups.integrations.bufferline").get()'';
            # };
          };
          lsp = {
            enable = true;
            servers = {
              eslint.enable = true;
              pyright.enable = true;
              nixd.enable = true;
              # rnix-lsp.enable = true;
              # rust-analyzer.enable = true;
            };
          };
          mini = {
            enable = true;
            modules.icons = { };
            mockDevIcons = true;
          };
          vim-suda = {
            enable = true;
            settings = {
              noninteractive = 1;
            };
          };
          trouble.enable = true;
        };
      in
      builtins.foldl' (acc: name: acc // { "${name}" = plugs.${name} // lazyLoadInject; }) plugs lazy;
    extraPlugins = with pkgs.vimPlugins; [
      lualine-lsp-progress
      luasnip
      quick-scope
      vim-startuptime
      smear-cursor-nvim
    ];
    globals = {
      mapleader = " ";
      macos_alt_is_meta = true;
    };
    keymaps = [
      {
        key = "H";
        action = "^";
      }
      {
        key = "L";
        action = "$";
      }
      {
        mode = [
          "i"
          "v"
        ];
        key = "<S-CR>";
        action = "<Esc>";
      }
      {
        mode = "n";
        key = "ZA";
        action = "<cmd>w suda://%<Return>:q<CR>";
      }
      {
        mode = "n";
        key = "<C-w>";
        action = "<cmd>bd<CR>";
        options = {
          silent = true;
          desc = "Close buffer";
        };
      }
      {
        mode = "n";
        key = "<C-b>";
        action = "<cmd>BufferLinePick<CR>";
        options = {
          desc = "Pick buffer";
        };
      }
      {
        mode = [
          "l"
          "i"
        ];
        key = "<C-S-[>";
        action = "<cmd>BufferLineCyclePrev<CR>";
        options = {
          desc = "Previous buffer";
        };
      }
      {
        mode = [
          "l"
          "i"
        ];
        key = "<C-S-]>";
        action = "<cmd>BufferLineCycleNext<CR>";
        options = {
          desc = "Next buffer";
        };
      }
      {
        mode = "n";
        key = "<Leader>s";
        action = "<cmd>Telescope live_grep<CR>";
        options = {
          silent = true;
          desc = "Search";
        };
      }
      {
        mode = "n";
        key = "<Leader>f";
        action = "<cmd>Telescope find_files<CR>";
        options = {
          silent = true;
          desc = "Find files";
        };
      }
      {
        mode = "n";
        key = "<Leader>b";
        action = "<cmd>Telescope file_browser<CR>";
        options = {
          silent = true;
          desc = "File browser";
        };
      }
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
      {
        mode = "n";
        key = "<leader>hs";
        action = "<cmd>Gitsigns stage_hunk<CR>";
        options = {
          silent = true;
          desc = "Stage hunk";
        };
      }
      {
        mode = "n";
        key = "<leader>hd";
        action = "<cmd>Gitsigns reset_hunk<CR>";
        options = {
          silent = true;
          desc = "Reset hunk";
        };
      }
      {
        mode = "n";
        key = "*";
        action = "<cmd>let @/=expand(\"<cword>\")<CR>";
        options = {
          silent = true;
          desc = "Search word under cursor";
        };
      }
      {
        mode = [
          "n"
          "i"
        ];
        key = "<2-LeftMouse>";
        action = "<cmd>let @/=expand(\"<cword>\")<CR>";
        options = {
          silent = true;
          desc = "Search word under cursor";
        };
      }
      {
        mode = "c";
        key = "e!!";
        action = "e suda://%";
      }
      {
        mode = "c";
        key = "r!!";
        action = "e suda://%";
      }
      {
        mode = "c";
        key = "w!!";
        action = "w suda://%";
      }
    ];
  };
}
