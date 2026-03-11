{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  generated,
}:
stdenvNoCC.mkDerivation rec {
  pname = "emby";
  inherit (generated.emby) version src;

  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  autoPatchelfIgnoreMissingDeps = [ "liblttng-ust.so.0" ];

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" unpacked

    mkdir -p "$out/bin" "$out/lib"
    cp -a unpacked/opt/emby-server "$out/lib/emby"

    rm -rf "$out/lib/emby/licenses"
    rm -rf unpacked/usr/lib/systemd

    while IFS= read -r script; do
      substituteInPlace "$script" \
        --replace-fail 'APP_DIR=/opt/emby-server' 'APP_DIR='"$out/lib/emby"
    done < <(grep -rlZ '^APP_DIR=/opt/emby-server$' "$out/lib/emby/bin" | tr '\0' '\n')

    sed -i "s|-updatepackage '[^']*'|-updatepackage \"\"|" "$out/lib/emby/bin/emby-server"

    makeWrapper "$out/lib/emby/bin/emby-server" "$out/bin/emby" \
      --chdir "$out/lib/emby"

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/lib/emby/lib"
    addAutoPatchelfSearchPath "$out/lib/emby/extra/lib"
    addAutoPatchelfSearchPath "$out/lib/emby/system"
  '';

  meta = {
    description = "Personal media server from Emby";
    homepage = "https://emby.media";
    license = lib.licenses.unfree;
    mainProgram = "emby";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
