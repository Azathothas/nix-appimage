{ runCommand,
  pkgsStatic,
  system
}:
let 
  arch = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  }.${system} or (throw "Unsupported system: ${system}");
  
  remoteBwrap = builtins.fetchurl "https://bin.ajam.dev/${arch}/bwrap";
in
runCommand "AppRun" { } ''
  mkdir $out
  cp ${./run.sh} $out/AppRun
  cp ${pkgsStatic.bubblewrap}/bin/bwrap $out/bwrap
  cp ${remoteBwrap} $out/bwrap-bin
  chmod +x $out/bwrap-bin
''