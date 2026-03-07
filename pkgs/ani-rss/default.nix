{
  lib,
  stdenvNoCC,
  makeWrapper,
  jre_headless,
  generated,
}:
stdenvNoCC.mkDerivation rec {
  pname = "ani-rss";
  inherit (generated.ani-rss) version src;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/ani-rss
    install -Dm644 $src $out/share/ani-rss/ani-rss.jar

    makeWrapper ${jre_headless}/bin/java $out/bin/ani-rss \
      --add-flags "-Xms60m" \
      --add-flags "-Xmx1g" \
      --add-flags "-Xss256k" \
      --add-flags "-Dfile.encoding=UTF-8" \
      --add-flags "-Xgcpolicy:gencon" \
      --add-flags "-Xshareclasses:none" \
      --add-flags "-Xquickstart" \
      --add-flags "-Xcompressedrefs" \
      --add-flags "-Xtune:virtualized" \
      --add-flags "-XX:+UseStringDeduplication" \
      --add-flags "-XX:-ShrinkHeapInSteps" \
      --add-flags "-XX:TieredStopAtLevel=1" \
      --add-flags "-XX:+IgnoreUnrecognizedVMOptions" \
      --add-flags "-XX:+UseCompactObjectHeaders" \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "--add-opens=java.base/java.net=ALL-UNNAMED" \
      --add-flags "--add-opens=java.base/sun.net.www.protocol.https=ALL-UNNAMED" \
      --add-flags "-jar $out/share/ani-rss/ani-rss.jar"

    runHook postInstall
  '';

  meta = {
    description = "RSS-based anime auto-subscription and download service";
    homepage = "https://docs.wushuo.top";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "ani-rss";
  };
}
