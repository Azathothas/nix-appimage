{ runCommand,
  pkgsStatic,
  system,
  fetchurl
}:
let 
  arch = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  }.${system} or (throw "Unsupported system: ${system}");
 #https://github.com/Azathothas/nix-appimage/releases/tag/bwrap
  remoteBwrap = fetchurl {
    url = "https://github.com/Azathothas/nix-appimage/releases/download/bwrap/bwrap-${arch}";
    sha256 = if arch == "x86_64" then "71806b86ef85476024a5a872de1fa997f01c321bb0ce5767352dda82ecdfcaf4"
              else if arch == "aarch64" then "fbd145a9d93f1a160c85c69ff8847885a1b2fd744ebf3a6db3f82a4faf025262"
              else throw "Unsupported architecture: ${arch}";
  };
  #Patched to allow nested bwraps for fun and profit
  remoteBwrapPatched = fetchurl {
    url = "https://github.com/Azathothas/nix-appimage/releases/download/bwrap/bwrap-patched-${arch}";
    sha256 = if arch == "x86_64" then "3c590f01008a4eaddfe7cce7e7ea7a5ff349b995f71f4563d467a92f53c1cdc0"
              else if arch == "aarch64" then "f39c5b7a2b7b967b2ad498d990ec28c922164c3844d15fe92e5fe09f7f75f4cc"
              else throw "Unsupported architecture: ${arch}";
  };
in
runCommand "AppRun" { } ''
  mkdir $out
  cp ${./AppRun.sh} $out/AppRun
  chmod +x $out/AppRun
  cp ${pkgsStatic.bubblewrap}/bin/bwrap $out/bwrap
  chmod +x $out/bwrap
  cp ${remoteBwrap} $out/bwrap-bin
  chmod +x $out/bwrap-bin
  cp ${remoteBwrapPatched} $out/bwrap-patched
  chmod +x $out/bwrap-patched
''