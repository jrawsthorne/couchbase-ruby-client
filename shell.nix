{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    cmake
    ruby
    rubyPackages.rake
    openssl
    ccache
  ];

  MAKEFLAGS = "-j16";
  TEST_CONNECTION_STRING = "couchbase://10.4.122.60";
  TEST_SERVER_VERSION = "7.1.0";
  CB_PRESERVE_BUILD_DIR = "true";
}
