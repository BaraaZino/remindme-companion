#!/usr/bin/env python3
"""Build a locally signed APK using Android SDK 35 and a JDK (no Gradle download)."""
import os, pathlib, shutil, subprocess, zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
BUILD=ROOT/'build/apk'
if BUILD.exists():shutil.rmtree(BUILD)
BUILD.mkdir(parents=True)
SDK=os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
if SDK:
 sdk=pathlib.Path(SDK); android=sdk/'platforms/android-35/android.jar'; tools=sdk/'build-tools/35.0.0'
else:
 android=next((ROOT/'.tools/platform').rglob('android.jar'),None)
 aapt=next((ROOT/'.tools/buildtools').rglob('aapt2'),None)
 if not android or not aapt:raise SystemExit('Install SDK platform 35 and build-tools 35.0.0; set ANDROID_HOME, or run scripts/bootstrap_android.py.')
 tools=aapt.parent
for name in ('aapt2','zipalign','apksigner','d8'):
 p=tools/name
 if not p.exists():raise SystemExit(f'Missing {p}')
 p.chmod(p.stat().st_mode|0o111)
def run(*args):subprocess.run([str(a) for a in args],check=True)
generated=BUILD/'generated';generated.mkdir()
classes=BUILD/'classes';classes.mkdir()
dex=BUILD/'dex';dex.mkdir()
run(tools/'aapt2','compile','--dir',ROOT/'app/src/main/res','-o',BUILD/'resources.zip')
manifest=BUILD/'AndroidManifest.xml'
manifest.write_text((ROOT/'app/src/main/AndroidManifest.xml').read_text().replace('<manifest ', '<manifest package="com.remindme.companion" ', 1))
run(tools/'aapt2','link','-o',BUILD/'base.apk','-I',android,'--manifest',manifest,'--java',generated,'--min-sdk-version','26','--target-sdk-version','35','--version-code','1','--version-name','0.1.0','--auto-add-overlay',BUILD/'resources.zip')
sources=list((ROOT/'native-core/src/main/java').rglob('*.java'))+list((ROOT/'app/src/main/java').rglob('*.java'))+list(generated.rglob('*.java'))
run('javac','--release','17','-classpath',android,'-d',classes,*sources)
run(tools/'d8','--lib',android,'--min-api','26','--output',dex,*classes.rglob('*.class'))
with zipfile.ZipFile(BUILD/'base.apk','a',compression=zipfile.ZIP_DEFLATED) as apk:
 for p in dex.glob('*.dex'):apk.write(p,p.name)
run(tools/'zipalign','-f','4',BUILD/'base.apk',BUILD/'aligned.apk')
key=ROOT/'.tools/debug.keystore';key.parent.mkdir(exist_ok=True)
if not key.exists():run('keytool','-genkeypair','-keystore',key,'-storepass','android','-keypass','android','-alias','androiddebugkey','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=RemindMe Local Build,O=Development,C=US')
out=ROOT/'dist/RemindMe-Companion.apk';out.parent.mkdir(exist_ok=True)
run(tools/'apksigner','sign','--ks',key,'--ks-key-alias','androiddebugkey','--ks-pass','pass:android','--key-pass','pass:android','--out',out,BUILD/'aligned.apk')
run(tools/'apksigner','verify','--verbose',out)
print(f'\nBuilt: {out} ({out.stat().st_size:,} bytes)')
