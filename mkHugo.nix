{pkgs, ...}:
pkgs.writeShellApplication {
  name = "my-script";
  runtimeInputs = with pkgs; [hugo];
  text = ''
    cat hugo/content/header.md result/nixos.md | sed "s/DATE-TIMESTAMP/$(date -u +%Y-%m-%d)/g" > hugo/content/index.md
    cd hugo
    hugo
  '';
}
