{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "cross-seed";
  version = "5.9.2";

  src = fetchFromGitHub {
    owner = "cross-seed";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-E0AlsFV9RP01YVwjw6ZQ8Lf1IVyuudxrb5oJ61EfIyo=";
  };

  npmDepsHash = "sha256-hZKLv+bzRFiMjNemydCUC1d7xul7Mm+vOPtCUD7p9XQ=";

  meta = with lib; {
    description = "cross-seed is an app designed to help you download torrents that you can cross seed based on your existing torrents";
    homepage = "https://www.cross-seed.org";
    license = licenses.asl20;
    maintainers = with maintainers; [ rasmus-kirk ];
  };
}
