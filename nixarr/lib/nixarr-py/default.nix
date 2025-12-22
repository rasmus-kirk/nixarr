{pkgs, ...}: let
  nixarr-py = let
    inherit (pkgs.python3Packages) buildPythonPackage setuptools;
  in
    buildPythonPackage {
      pname = "nixarr";
      version = "0.1.0";
      pyproject = true;

      src = ./.;
      build-system = [setuptools];
      dependencies = pkgs.callPackage ./python-deps.nix {};
    };
in
  nixarr-py
