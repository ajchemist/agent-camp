{
  description = "agent-camp: coding-agent CLIs, their ACP adapters and herdr, as a Home Manager module";

  # Upstream directly, the same URLs as nix-basecamp's: a downstream points
  # all three at its own with `follows`, so one lock pins them for everything.
  # home-manager and nix-darwin serve only the checks and the CI deploy.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "git+https://github.com/nix-community/home-manager.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "git+https://github.com/nix-darwin/nix-darwin.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-darwin, ... }:
  let
    fixture = import ./ci/fixture.nix { inherit nixpkgs home-manager nix-darwin; };
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});

    # What CI deploys: the four representative harnesses with their adapters
    # (goose speaks ACP itself), and herdr.
    ciSettings = {
      agent-camp.harnesses = nixpkgs.lib.genAttrs [ "claude" "codex" "pi" "goose" ] (_: { enable = true; acp = true; });
      agent-camp.herdr.enable = true;
    };
    linuxHome = fixture.home { user = "fixture"; modules = [ self.homeModules.default ciSettings ]; };
    darwin = fixture.darwin {
      user = "fixture";
      modules = [{ home-manager.sharedModules = [ self.homeModules.default ciSettings ]; }];
    };
    hostChecks = system: import ./checks.nix {
      pkgs = nixpkgs.legacyPackages.${system};
      mkHome = modules: fixture.home {
        inherit system modules; user = "fixture";
        homeDirectory = if nixpkgs.lib.hasSuffix "darwin" system then "/Users/fixture" else "/home/fixture";
      };
      module = self.homeModules.default;
      inherit ciSettings;
    };
  in {
    homeModules.default = ./module.nix;
    homeModules.agent-camp = ./module.nix;

    lib = {
      # `ask { pkgs }`: the checklist a downstream app runs before its build.
      ask = import ./ask.nix;
      # `plan { pkgs; harnesses; herdr; }`: read-only status rows, given the
      # same agent-camp settings the downstream sets in its module.
      plan = import ./plan.nix;
      harnesses = import ./harnesses.nix;
      inherit ciSettings;
    };

    packages = forAll (pkgs: {
      ask = self.lib.ask { inherit pkgs; };
      plan = self.lib.plan { inherit pkgs; inherit (ciSettings.agent-camp) harnesses herdr; };
    });

    # `home`: the module in a real Home Manager / nix-darwin build. The rest
    # (checks.nix) catch at build time what would otherwise first fail on a
    # deploy host. CI runs all of them before it deploys.
    checks = {
      x86_64-linux = { home = linuxHome.activationPackage; } // hostChecks "x86_64-linux";
      aarch64-darwin = { home = darwin.config.home-manager.users.fixture.home.activationPackage; } // hostChecks "aarch64-darwin";
    };
  };
}
