{ pkgs ? import <nixpkgs> { } }:

let
  libheif-new = pkgs.libheif.overrideAttrs (old: rec {
    version = "1.17.6";
    src = pkgs.fetchFromGitHub {
      owner = "strukturag";
      repo = "libheif";
      rev = "v${version}";
      sha256 = "sha256-pp+PjV/pfExLqzFE61mxliOtVAYOePh1+i1pwZxDLAM=";
    };
    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
  });

  libjxl-new = pkgs.libjxl.overrideAttrs (old: rec {
    version = "0.9.2";
    src = pkgs.fetchFromGitHub {
      owner = "libjxl";
      repo = "libjxl";
      rev = "v${version}";
      sha256 = "sha256-t5cuuvqGC3os49lhV8hixCn6xqCoDppPC7nwf3f8Rkw=";
      fetchSubmodules = true;
    };
    patches = [ ];
  });


  python = pkgs.python3.override {
    packageOverrides = self: super: {
      imagecodecs =
        super.buildPythonPackage rec {
          pname = "imagecodecs";
          version = "2024.1.1";
          format = "setuptools";
          src = super.fetchPypi {
            inherit pname version;
            hash = "sha256-/eRr1pjQCCVd7vVBHFmzXA6HUpXoNb9geffiqyLyFus=";
          };
          patches = [ ./imagecodecs-deps-nix.patch ];
          patchFlags = [ "--binary" ];
          doCheck = false;
          nativeBuildInputs = [
            pkgs.pkg-config
            super.cython
            super.pip
          ];
          buildInputs = with pkgs; [
            brotli
            brunsli
            bzip2
            c-blosc
            charls
            giflib
            jxrlib
            lcms
            libaec
            libdeflate
            libheif-new
            libjxl-new
            libpng
            libtiff
            libwebp
            lz4
            snappy
            xz
            zlib
            zopfli
            zstd
          ];
          propagatedBuildInputs = with super; [
            py
            setuptools
            numpy
            numcodecs
          ];
        };

   };
  };

in
python.withPackages (p: with p; [
  imagecodecs
  numcodecs
  zarr
  pylzma
  pathos
  
  # dev
  python-lsp-ruff
])
