import os
import re

# 1. Definir compileSdkVersion/targetSdkVersion/minSdkVersion como variable
#    ext del proyecto raiz, ANTES de que los subproyectos (incluido
#    flutter_webrtc) se evaluen. La mayoria de los plugins nativos leen
#    esta variable ext con un fallback (ej: safeExtGet('compileSdkVersion', 31)),
#    por eso hay que definirla al PRINCIPIO del archivo raiz, no al final.
root_gradle = (
    "android/build.gradle.kts"
    if os.path.exists("android/build.gradle.kts")
    else "android/build.gradle"
)

if os.path.exists(root_gradle):
    with open(root_gradle, "r") as f:
        r_content = f.read()

    if "MARKER_EXT_SDK" not in r_content:
        if root_gradle.endswith(".kts"):
            ext_patch = (
                "// MARKER_EXT_SDK\n"
                'extra["compileSdkVersion"] = 36\n'
                'extra["targetSdkVersion"] = 36\n'
                'extra["minSdkVersion"] = 21\n'
            )
        else:
            ext_patch = (
                "// MARKER_EXT_SDK\n"
                "ext {\n"
                "    compileSdkVersion = 36\n"
                "    targetSdkVersion = 36\n"
                "    minSdkVersion = 21\n"
                "}\n"
            )
        with open(root_gradle, "w") as f:
            f.write(ext_patch + "\n" + r_content)
        print(f"[OK] {root_gradle} parcheado con variables ext de SDK")
    else:
        print(f"[SKIP] {root_gradle} ya tenia el marcador ext")
else:
    print(f"[WARN] no se encontro {root_gradle}")

# 2. Patch de android/app/build.gradle(.kts): fija compileSdk/minSdk/targetSdk
#    y ndkVersion explicitamente en el modulo app tambien.
gradle_file = (
    "android/app/build.gradle.kts"
    if os.path.exists("android/app/build.gradle.kts")
    else "android/app/build.gradle"
)

if os.path.exists(gradle_file):
    with open(gradle_file, "r") as f:
        content = f.read()

    # Sintaxis Kotlin DSL (compileSdk = X)
    content = re.sub(r"compileSdk\s*=.*", "compileSdk = 36", content)
    content = re.sub(r"minSdk\s*=.*", "minSdk = 21", content)
    content = re.sub(r"targetSdk\s*=.*", "targetSdk = 36", content)
    content = re.sub(
        r"ndkVersion\s*=.*", 'ndkVersion = "27.0.12077973"', content
    )

    # Sintaxis Groovy (compileSdkVersion X)
    content = re.sub(r"compileSdkVersion\s+\d+", "compileSdkVersion 36", content)
    content = re.sub(r"minSdkVersion\s+\d+", "minSdkVersion 21", content)
    content = re.sub(r"targetSdkVersion\s+\d+", "targetSdkVersion 36", content)

    with open(gradle_file, "w") as f:
        f.write(content)
    print(f"[OK] {gradle_file} parcheado (compileSdk/minSdk/targetSdk/ndk)")
else:
    print(f"[WARN] no se encontro {gradle_file}")

# 3. Inyectar permisos en AndroidManifest.xml (solo si no estan ya).
manifest_file = "android/app/src/main/AndroidManifest.xml"

if os.path.exists(manifest_file):
    with open(manifest_file, "r") as f:
        m_content = f.read()

    permissions = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
    <uses-feature android:name="android.hardware.camera" android:required="true"/>
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
"""

    if "android.permission.CAMERA" not in m_content:
        m_content = re.sub(
            r"(<manifest[^>]*>)", r"\1" + permissions, m_content, count=1
        )
        with open(manifest_file, "w") as f:
            f.write(m_content)
        print(f"[OK] {manifest_file} parcheado con permisos")
    else:
        print(f"[SKIP] {manifest_file} ya tenia los permisos")
else:
    print(f"[WARN] no se encontro {manifest_file}")

print("Patch de Android completado.")

# 4. Reglas de ProGuard/R8 para mobile_scanner + ML Kit + CameraX.
#    R8 en modo release puede eliminar clases de ML Kit que la propia
#    libreria carga por reflexion, provocando el crash:
#    "Attempt to invoke virtual method 'java.lang.Class
#    java.lang.Object.getClass()' on a null object reference"
#    al intentar iniciar la camara del escaner de QR.
proguard_file = "android/app/proguard-rules.pro"
proguard_rules = """# ML Kit (usado por mobile_scanner para leer codigos QR)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# mobile_scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
"""
with open(proguard_file, "w") as f:
    f.write(proguard_rules)
print(f"[OK] creado {proguard_file} con reglas de ProGuard/R8")

if os.path.exists(gradle_file):
    with open(gradle_file, "r") as f:
        g_content = f.read()

    if "proguard-rules.pro" not in g_content:
        if gradle_file.endswith(".kts"):
            g_content = re.sub(
                r"(release\s*\{)",
                r"""\1
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )""",
                g_content,
                count=1,
            )
        else:
            g_content = re.sub(
                r"(release\s*\{)",
                r"""\1
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'""",
                g_content,
                count=1,
            )
        with open(gradle_file, "w") as f:
            f.write(g_content)
        print(f"[OK] {gradle_file}: minificacion + proguard-rules.pro conectados")
    else:
        print(f"[SKIP] {gradle_file} ya referenciaba proguard-rules.pro")
else:
    print(f"[WARN] no se encontro {gradle_file} para conectar proguard-rules.pro")
