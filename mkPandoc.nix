{pkgs, ...}:
pkgs.writeShellApplication {
  name = "my-script";
  runtimeInputs = with pkgs; [ pandoc ];
  text = ''
    tmpdir=$(mktemp -d)

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
    ' block=0 result/nixos.md > "$tmpdir"/pre.md
    # inline code "blocks" to nix code blocks
    # shellcheck disable=SC2016
    sed '/^`[^`]*`$/s/`\(.*\)`/```nix\n\1\n```/g' "$tmpdir"/pre.md > "$tmpdir"/done.md

    mkdir -p out
    cp docs/styling/style.css out
    pandoc \
      --standalone \
      --highlight-style docs/styling/gruvbox.theme \
      --metadata title="Nixarr - Option Documentation" \
      --metadata date="$(date -u '+%Y-%m-%d - %H:%M:%S %Z')" \
      --css=style.css \
      -V lang=en \
      -V --mathjax \
      -f markdown+smart \
      -o out/index.html \
      "$tmpdir"/done.md
  '';
}
