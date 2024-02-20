{pkgs, ...}:
pkgs.writeShellApplication {
  name = "my-script";
  runtimeInputs = with pkgs; [hugo];
  text = ''
    cat hugo/content/header.md result/home.md | sed "s/DATE-TIMESTAMP/$(date -u +%Y-%m-%d)/g" > hugo/content/home-manager/index.md
    cat hugo/content/header.md result/nixos.md | sed "s/DATE-TIMESTAMP/$(date -u +%Y-%m-%d)/g" > hugo/content/nixos/index.md
    cd hugo
    hugo
  '';
}
