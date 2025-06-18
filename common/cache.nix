_: {
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nocargo.cachix.org"
      "https://lightquantum.cachix.org"
      "https://nix-community.cachix.org"
      "https://yazi.cachix.org"
      "https://viperml.cachix.org"
      "https://nix-darwin.cachix.org"
      "https://cache.garnix.io"
      "https://colmena.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nocargo.cachix.org-1:W6jkp5htZBA1tUdU8XHLaD7zBrIFnor0MsLhHgrJeHk="
      "lightquantum.cachix.org-1:RPK5F8V+lfAUmCBdFAuM30B7hiwhjytZwSl3wkuuR1M="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "viperml.cachix.org-1:qZhKBMTfmcLL+OG6fj/hzsMEedgKvZVFRRAhq7j8Vh8="
      "nix-darwin.cachix.org-1:LxMyKzQk7Uqkc1Pfq5uhm9GSn07xkERpy+7cpwc006A="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
    ];
  };
}
