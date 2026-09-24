import os
import re
import glob

# flutter_webrtc trae su compileSdkVersion/minSdkVersion HARDCODEADO en su
# propio android/build.gradle (no lo lee de ninguna variable ext del
# proyecto raiz). La version publicada en pub.dev para 0.12.0 todavia
# tiene ese valor en 31, aunque el repo de GitHub ya lo subio a 36.
# Por eso hay que editar directamente el archivo dentro de la cache de pub,
# una vez que "flutter pub get" ya lo descargo.

pub_cache = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))

# Estructura tipica: $PUB_CACHE/hosted/pub.dev/flutter_webrtc-X.Y.Z/android/build.gradle
pattern = os.path.join(
    pub_cache, "hosted", "*", "flutter_webrtc-*", "android", "build.gradle"
)
matches = glob.glob(pattern)

if not matches:
    print(f"[WARN] no se encontro flutter_webrtc en la cache de pub ({pub_cache})")
    print("[WARN] patrones probados:", pattern)

for path in matches:
    with open(path, "r") as f:
        content = f.read()
    original = content

    content = re.sub(r"compileSdkVersion\s+\d+", "compileSdkVersion 36", content)
    content = re.sub(r"minSdkVersion\s+\d+", "minSdkVersion 21", content)
    content = re.sub(r"targetSdkVersion\s+\d+", "targetSdkVersion 36", content)

    if content != original:
        with open(path, "w") as f:
            f.write(content)
        print(f"[OK] parcheado: {path}")
    else:
        print(f"[SKIP] sin cambios necesarios en: {path}")

print("Patch de pub cache completado.")
