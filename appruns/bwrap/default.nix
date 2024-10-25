{ runCommand,
  pkgsStatic,
  system
}:
let 
  arch = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  }.${system} or (throw "Unsupported system: ${system}");
in
runCommand "AppRun" { 
  __impure = true;
} ''
  mkdir $out
  cp ${./AppRun.sh} $out/AppRun
  cp ${pkgsStatic.bubblewrap}/bin/bwrap $out/bwrap
  curl -fSL "https://bin.ajam.dev/${arch}/bwrap" -o $out/bwrap-bin
  chmod +x $out/bwrap-bin
''