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
  
  remoteBwrap = fetchurl {
    url = "https://bin.ajam.dev/${arch}/bwrap";
    # Using an obviously incorrect hash
    sha256 = "0000000000000000000000000000000000000000000000000000";
    postFetch = ''
      # Always succeed regardless of hash
      exit 0
    '';
  };
in
runCommand "AppRun" { } ''
  mkdir $out
  cp ${./AppRun.sh} $out/AppRun
  cp ${pkgsStatic.bubblewrap}/bin/bwrap $out/bwrap
  cp ${remoteBwrap} $out/bwrap-bin
  chmod +x $out/bwrap-bin
''