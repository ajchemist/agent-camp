{
  description = "agent-camp: coding-agent CLIs, their ACP adapters and herdr, as a Home Manager module on top of nix-basecamp";

  inputs.basecamp.url = "github:ajchemist/nix-basecamp";

  outputs = { self, basecamp, ... }:
  let
    nixpkgs = basecamp.inputs.nixpkgs;
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

    # What CI deploys: the four representative agents with their adapters
    # (goose speaks ACP itself), and herdr.
    ciSettings = {
      agent-camp.agents = nixpkgs.lib.genAttrs [ "claude" "codex" "pi" "goose" ] (_: { enable = true; acp = true; });
      agent-camp.herdr.enable = true;
    };
    linuxHome = basecamp.lib.mkHome { user = "fixture"; modules = [ self.homeModules.default ciSettings ]; };
    darwin = basecamp.lib.mkDarwin {
      user = "fixture";
      modules = [{ home-manager.sharedModules = [ self.homeModules.default ciSettings ]; }];
    };
  in {
    homeModules.default = ./module.nix;
    homeModules.agent-camp = ./module.nix;

    lib = {
      # `ask { pkgs }`: the checklist a downstream app runs before its build.
      ask = import ./ask.nix;
      # `plan { pkgs; agents; herdr; }`: read-only status rows, given the
      # same agent-camp settings the downstream sets in its module.
      plan = import ./plan.nix;
      agents = import ./agents.nix;
      inherit ciSettings;
    };

    packages = forAll (pkgs: {
      ask = self.lib.ask { inherit pkgs; };
      plan = self.lib.plan { inherit pkgs; inherit (ciSettings.agent-camp) agents herdr; };
    });

    checks = {
      x86_64-linux.home = linuxHome.activationPackage;
      aarch64-darwin.home = darwin.config.home-manager.users.fixture.home.activationPackage;
    };
  };
}
