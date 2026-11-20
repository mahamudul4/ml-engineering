"""Verify every Chapter 4 Python block, reference solution and local data hash.

Run in a dev environment with pandas, numpy and scikit-learn, from repo root.
The Flutter app does not execute these scripts or fetch any data at runtime.
"""
import contextlib
import hashlib
import io
import json
import math
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parent.parent
assert Path.cwd().resolve()==ROOT, 'Run from the repository root'
data=ROOT/'assets/datasets/adult'
expected={
 'adult.data':'5b00264637dbfec36bdeaab5676b0b309ff9eb788d63554ca0a249491c86603d',
 'adult.test':'a2a9044bc167a35b2361efbabec64e89d69ce82d9790d2980119aac5fd7e9c05',
 'adult.names':'c248284c0b5de30c9e1958d6cdd168a34a654758b620e68f46aefa83fc0a576a',
}
for name,digest in expected.items():
    assert hashlib.sha256((data/name).read_bytes()).hexdigest()==digest,name
chapter=json.loads((ROOT/'assets/content/chapter_04.json').read_text(encoding='utf-8'))
assert len(chapter['lessons'])==12
workflow_scope=None
for lesson in chapter['lessons']:
    scope={}
    with contextlib.redirect_stdout(io.StringIO()):
        for block in lesson['blocks']:
            if block.get('type')=='code':
                compile(block['body'],lesson['id'],'exec')
                exec(block['body'],scope)
    if lesson['id']=='ch04_pipeline': workflow_scope=scope
    if lesson['id']=='ch04_imputation':
        assert scope['Z_new'].shape[1]==3
    if lesson['id']=='ch04_encoding':
        assert scope['oof_means'](['A','A','B','B'],[1,0,1,0],[0,1,0,1])==[0.,1.,0.,1.]
    if lesson['id']=='ch04_scaling':
        assert float(scope['recipe'][0].statistics_[0])==20
        assert float(scope['recipe'][1].mean_[0])==35
        assert float(scope['recipe'][1].var_[0])==1025
report=workflow_scope['report']
assert report['source_development_rows']==32561
assert report['source_test_rows']==16281
assert report['train_rows']+report['validation_rows']==32561
assert report['excluded_test_profile_overlap']==26
assert report['evaluated_test_rows']==16255
assert report['development_missing']['occupation']==1843
for name in ['test_f1_fixed_threshold','test_average_precision','test_log_loss']:
    assert math.isfinite(report[name])
for exercise in chapter['exercises']:
    compile(exercise['starter'],exercise['id'],'exec')
    output=io.StringIO()
    with contextlib.redirect_stdout(output): exec(exercise['solution'],{})
    assert math.isclose(float(output.getvalue().strip()),exercise['expected'],abs_tol=1e-8),exercise['id']
# Verify the standalone downloadable workflow is the same runnable recipe.
with contextlib.redirect_stdout(io.StringIO()):
    standalone=runpy.run_path(str(data/'workflow.py'))
assert standalone['report']==report
(ROOT/'build/chapter-04-python-verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS: Chapter 4 blocks, six solutions, source hashes and complete real-data workflow verified.')
print('Rows:',report['train_rows'],report['validation_rows'],report['evaluated_test_rows'])
print('Fitted features:',report['transformed_features'],'Test F1:',round(report['test_f1_fixed_threshold'],4))
