{
  description = "Unified hosts file with base extensions.";
  outputs = { self, nixpkgs, ... }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.unix;

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
      });
    in
    {
      nixosModules.ad-block = { config, ... }:
        with nixpkgs.lib;
        let
          cfg = config.networking.stevenBlackHosts;
          alternatesList = (if cfg.blockFakenews then [ "fakenews" ] else []) ++
                           (if cfg.blockGambling then [ "gambling" ] else []) ++
                           (if cfg.blockPorn then [ "porn" ] else []) ++
                           (if cfg.blockSocial then [ "social" ] else []);
          alternatesPath = "alternates/" + builtins.concatStringsSep "-" alternatesList + "/";
        in
        {
          options.networking.stevenBlackHosts = {
            enable = mkEnableOption "Steven Black's hosts file";
            enableIPv6 = mkEnableOption "IPv6 rules" // {
              default = config.networking.enableIPv6;
              defaultText = literalExpression "config.networking.enableIPv6";
            };
            blockFakenews = mkEnableOption "fakenews hosts entries";
            blockGambling = mkEnableOption "gambling hosts entries";
            blockPorn = mkEnableOption "porn hosts entries";
            blockSocial = mkEnableOption "social hosts entries";
          };
          config = mkIf cfg.enable {
            networking.extraHosts =
              let
                orig = builtins.readFile ("${self}/" + (if alternatesList != [] then alternatesPath else "") + "hosts");
                ipv6 = builtins.replaceStrings [ "0.0.0.0" ] [ "::" ] orig;
              in orig + (optionalString cfg.enableIPv6 ("\n" + ipv6));
          };
        };

      nixosModules.default = self.nixosModules.ad-block;

      packages.x86_64-linux.default = with import nixpkgs { system = "x86_64-linux"; }; stdenv.mkDerivation {
        name = "ad-block-host-list";
        buildInputs = [];
        src = ./.;
        installPhase = ''
          mkdir -p $out
          cp hosts $out/
        '';
      };


      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              python3
              python3Packages.flake8
              python3Packages.requests
            ];
          };
        });
    };
}
