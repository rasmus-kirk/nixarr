{
  lib,
  pkgs,
  runCommand,
  nixosOptionsDoc,
  inputs,
  ...
}: let
  evalNixos = lib.evalModules {
    specialArgs = {inherit pkgs;};
    modules = [
      {
        config._module.check = false;
      }
      #inputs.home-manager.nixosModules.default
      ./nixarr
    ];
  };
  optionsDocNixos = nixosOptionsDoc {
    inherit (evalNixos) options;
  };
in
  # create a derivation for capturing the markdown output
  runCommand "options-doc.md" {} ''
    mkdir -p $out
    cat ${optionsDocNixos.optionsCommonMark} | tail -n +58 >> $out/nixos.md
    sed -i '/\*Declared by:\*/{N;d;}' $out/nixos.md
  ''
