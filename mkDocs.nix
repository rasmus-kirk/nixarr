{
  lib,
  pkgs,
  nixosOptionsDoc,
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
  pkgs.stdenv.mkDerivation {
    name = "nixdocs2html";
    src = ./.;
    buildInputs = with pkgs; [pandoc];
    phases = ["unpackPhase" "buildPhase"];
    buildPhase = ''
      #tmpdir=$(mktemp -d)
      tmpdir="$out/debug"
      mkdir -p $out
      mkdir -p $tmpdir
      cp -r docs $out
      tail -n +2 README.md > "$tmpdir/index.md"
      cd $out

      # Generate md docs
      cat ${optionsDocNixos.optionsCommonMark} > "$tmpdir"/nixos.md

      pandoc \
        --standalone \
        --metadata title="Nixarr - Option Documentation" \
        --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
        --highlight-style docs/pandoc/gruvbox.theme \
        --template docs/pandoc/template.html \
        --css docs/pandoc/style.css \
        --lua-filter docs/pandoc/lua/anchor-links.lua \
        --lua-filter docs/pandoc/lua/code-default-to-nix.lua \
        --lua-filter docs/pandoc/lua/remove-utils.lua \
        --lua-filter docs/pandoc/lua/headers-lvl2-to-lvl3.lua \
        --lua-filter docs/pandoc/lua/remove-declared-by.lua \
        --lua-filter docs/pandoc/lua/inline-to-fenced-nix.lua \
        --lua-filter docs/pandoc/lua/remove-module-args.lua \
        -V lang=en \
        -V --mathjax \
        -f markdown+smart \
        -o $out/options.html \
        "$tmpdir"/nixos.md

      pandoc \
        --metadata title="Nixarr" \
        --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
        --standalone \
        --highlight-style docs/pandoc/gruvbox.theme \
        --template docs/pandoc/template.html \
        --css docs/pandoc/style.css \
        -V lang=en \
        -V --mathjax \
        -f markdown+smart \
        -o $out/index.html \
        "$tmpdir/index.md"
    '';
  }
