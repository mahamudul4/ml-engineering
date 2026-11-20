"""Verify the release version and all bundled curriculum/data/font source bytes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
apk = ROOT/'build/app/outputs/flutter-apk/app-release.apk'
sdk = Path(os.environ.get('ANDROID_HOME',os.environ.get('ANDROID_SDK_ROOT','')))
aapt = sorted((sdk/'build-tools').glob('*/aapt.exe'))[-1]
badging = subprocess.check_output([str(aapt),'dump','badging',str(apk)],text=True)
assert "name='dev.mlpath.ml_path'" in badging
assert "versionCode='16'" in badging and "versionName='1.15.0'" in badging
permissions = subprocess.check_output([str(aapt),'dump','permissions',str(apk)],text=True)
assert 'android.permission.INTERNET' not in permissions
with zipfile.ZipFile(apk) as package:
    prefix='assets/flutter_assets/'
    catalog=json.loads(package.read(prefix+'assets/content/catalog.json'))
    assert len(catalog['chapters'])==16
    source_paths=[ROOT/'assets/content/catalog.json']+[ROOT/name for name in catalog['chapters']]
    source_paths += [p for folder in ['assets/datasets/adult','assets/datasets/bike_sharing','assets/datasets/wine_quality','assets/fonts'] for p in (ROOT/folder).iterdir() if p.is_file()]
    for path in source_paths:
        relative=path.relative_to(ROOT).as_posix()
        assert package.read(prefix+relative)==path.read_bytes(),relative
    chapter=json.loads(package.read(prefix+'assets/content/chapter_16.json'))
    assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
    manifest=json.loads(package.read(prefix+'FontManifest.json'))
    families={f['family'] for f in manifest}
    assert {'Manrope','NotoSansBengali','NotoSansMath','NotoSans'} <= families
report={'version':'1.15.0+16','application_id':'dev.mlpath.ml_path','chapters':16,
        'chapter_16_counts':{'lessons':20,'quizzes':24,'exercises':10,'interviews':10},
        'source_files_byte_matched':len(source_paths),'internet_permission':False,
        'apk_bytes':apk.stat().st_size,'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest()}
destination=ROOT/'build/chapter-16-release-verification.json'
destination.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
