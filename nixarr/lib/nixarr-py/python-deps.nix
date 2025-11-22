{
  fetchPypi,
  fetchFromGitHub,
  lib,
  python3Packages,
  writeTextFile,
}: let
  inherit
    (python3Packages)
    buildPythonPackage
    pydantic
    python-dateutil
    setuptools
    typing-extensions
    urllib3
    requests
    ;

  lazy-imports = buildPythonPackage rec {
    pname = "lazy-imports";
    version = "1.1.0"; # nixpkgs 25.05 only has 0.3.1
    pyproject = true;

    src = fetchPypi {
      inherit version;
      pname = "lazy_imports";
      hash = "sha256-5upaHk8JqGE1fmcLeqYe/Lzm/ik2F4XdJT32b43bw2s=";
    };

    build-system = [setuptools];
  };

  arr-deps = [
    lazy-imports
    pydantic
    python-dateutil
    typing-extensions
    urllib3
  ];

  lidarr = buildPythonPackage rec {
    pname = "lidarr";
    version = "1.2.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-TycyDD/O1jdljjT8hkFtYb2OHFWWHtm2C/AHJX2YbXQ=";
    };

    build-system = [setuptools];
    dependencies = arr-deps;
  };

  prowlarr = buildPythonPackage rec {
    pname = "prowlarr";
    version = "1.1.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-PiK4ZrORMV907wX9dPeO2tE97NSu6sCPfH7aUFkyRZk=";
    };

    build-system = [setuptools];
    dependencies = arr-deps;
  };

  radarr = buildPythonPackage rec {
    pname = "radarr";
    version = "1.2.1";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-suN16BYf/6gm8G/xA5S6wdYerTUq8Dy2yflWYIKLLBQ=";
    };

    build-system = [setuptools];
    dependencies = arr-deps;
  };

  readarr = buildPythonPackage rec {
    pname = "readarr";
    version = "1.2.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-vPjZShyIOcpF9/sFuviRtmTJGxJMhQ+bwHO4UYneMOs=";
    };

    build-system = [setuptools];
    dependencies = arr-deps;
  };

  sonarr = buildPythonPackage rec {
    pname = "sonarr";
    version = "1.1.1";
    pyproject = true;

    # Only one not on PyPI (!?)
    src = fetchFromGitHub {
      owner = "devopsarr";
      repo = "sonarr-py";
      rev = "v${version}";
      hash = "sha256-cqhdsos328jtUYw2HWaoQ95EPTnu3RYPWiyT5FqfTXk=";
    };

    build-system = [setuptools];
    dependencies = arr-deps;
  };
in [
  lidarr
  prowlarr
  radarr
  readarr
  sonarr
  python3Packages.requests
]
