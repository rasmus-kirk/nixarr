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
      tmpdir=$(mktemp -d)

      mkdir -p $out
      cp -r docs docs/wiki $out

      # Generate md docs
      cat ${optionsDocNixos.optionsCommonMark} > "$tmpdir"/nixos-options.md

      buildwiki () {
        file_path="$1"
        filename=$(basename -- "$file_path")
        dir_path=$(dirname "$file_path" | sed 's|^docs/||')
        filename_no_ext="''${filename%.*}"

        mkdir -p "$out"/"$dir_path"

        pandoc \
          --standalone \
          --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
          --highlight-style docs/pandoc/gruvbox.theme \
          --lua-filter docs/pandoc/lua/anchor-links.lua \
          --css /docs/pandoc/style.css \
          --css /docs/pandoc/inline-code-style.css \
          --template docs/pandoc/template.html \
          -V lang=en \
          -V --mathjax \
          -f markdown+smart \
          -o $out/"$dir_path"/"$filename_no_ext".html \
          "$file_path"
      }

      # Make home page
      sed '1d' README.md > "$tmpdir/readme.md"
      pandoc \
        --metadata title="Nixarr - Media Server Nixos Module" \
        --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
        --standalone \
        --highlight-style docs/pandoc/gruvbox.theme \
        --template docs/pandoc/template.html \
        --css docs/pandoc/style.css \
        -V lang=en \
        -V --mathjax \
        -f markdown+smart \
        -o $out/index.html \
        "$tmpdir/readme.md"

      # Make wiki pages
      find docs/wiki -type f -name "*.md" | while IFS= read -r file; do
        buildwiki "$file"
      done

      # Make options
      cd $out
      pandoc \
        --standalone \
        --metadata title="Nixarr - Option Documentation" \
        --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
        --highlight-style docs/pandoc/gruvbox.theme \
        --template docs/pandoc/template.html \
        --css docs/pandoc/style.css \
        --lua-filter docs/pandoc/lua/indent-code-blocks.lua \
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
        "$tmpdir"/nixos-options.md
    '';
  }
