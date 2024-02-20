{
  lib,
  pkgs,
  runCommand,
  nixosOptionsDoc,
  inputs,
  ...
}: let
  # Make sure the used package is scrubbed to avoid actually
  # instantiating derivations.
  # evaluate our options
  evalHome = lib.evalModules {
    # TODO: understand why pkgs needs to be passed here
    specialArgs = {inherit pkgs;};
    modules = [
      {
        # disabled checking that all option definitions have matching declarations
        config._module.check = false;
      }
      inputs.home-manager.nixosModules.default
      ./home-manager/fonts
      ./home-manager/foot
      ./home-manager/fzf
      ./home-manager/git
      ./home-manager/gruvboxTheme
      ./home-manager/helix
      ./home-manager/homeManagerScripts
      ./home-manager/jiten
      ./home-manager/joshuto
      ./home-manager/kakoune
      ./home-manager/ssh
      ./home-manager/terminalTools
      ./home-manager/userDirs
      ./home-manager/zathura
      ./home-manager/zsh
    ];
  };
  # generate our docs
  optionsDocHome = nixosOptionsDoc {
    inherit (evalHome) options;
  };

  # Same for nixos
  evalNixos = lib.evalModules {
    specialArgs = {inherit pkgs;};
    modules = [
      {
        config._module.check = false;
      }
      inputs.home-manager.nixosModules.default
      ./nixos/servarr
      ./nixos/nixosScripts
    ];
  };
  optionsDocNixos = nixosOptionsDoc {
    inherit (evalNixos) options;
  };
in
  # create a derivation for capturing the markdown output
  runCommand "options-doc.md" {} ''
    mkdir -p $out
    cat ${optionsDocHome.optionsCommonMark} | tail -n +210 >> $out/home.md
    cat ${optionsDocNixos.optionsCommonMark} | tail -n +210 >> $out/nixos.md
  ''
