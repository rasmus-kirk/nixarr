{
  lib,
  pkgs,
  runCommand,
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
in pkgs.stdenv.mkDerivation {
    name = "nixdocs2html";
    src = ./.;
    buildInputs = with pkgs; [ pandoc ];
    phases = ["unpackPhase" "buildPhase"];
    buildPhase = ''
      tmpdir=$(mktemp -d)
      mkdir -p $out
      cp docs/styling/style.css $out

      # Generate md docs
      cat ${optionsDocNixos.optionsCommonMark} | tail -n +58 >> "$tmpdir"/nixos.md

      # Remove "Declared by" lines
      sed -i '/\*Declared by:\*/{N;d;}' "$tmpdir"/nixos.md

      # Code blocks to nix code blocks
      # shellcheck disable=SC2016
      awk '
      /^```$/ {
          if (!block) {
              print "```nix";  # Start of a code block
              block = 1;
          } else {
              print "```";  # End of a code block
              block = 0;
          }
          next;
      }
      { print }  # Print all lines, including those inside code blocks
      ' block=0 "$tmpdir"/nixos.md > "$tmpdir"/1.md
      # inline code "blocks" to nix code blocks
      # shellcheck disable=SC2016
      sed '/^`[^`]*`$/s/`\(.*\)`/```nix\n\1\n```/g' "$tmpdir"/1.md > "$tmpdir"/2.md
      # Remove bottom util-nixarr options
      sed '/util-nixarr/,$d' "$tmpdir"/2.md > "$tmpdir"/done.md

      pandoc \
        --standalone \
        --highlight-style docs/styling/gruvbox.theme \
        --metadata title="Nixarr - Option Documentation" \
        --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
        --css=style.css \
        -V lang=en \
        -V --mathjax \
        -f markdown+smart \
        -o $out/index.html \
        "$tmpdir"/done.md
    '';
  }
