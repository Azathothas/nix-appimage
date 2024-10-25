{ runCommand,
  pkgsStatic
}:

runCommand "AppRun" { } ''
  mkdir $out
  cp ${./run.sh} $out/AppRun
  cp ${pkgsStatic.bubblewrap}/bin/bwrap $out/bwrap
''
