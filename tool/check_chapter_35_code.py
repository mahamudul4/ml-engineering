"""Run all Chapter35 teaching code plus independent SQLite/PIT/fault audits."""
from pathlib import Path
from datetime import date,timedelta
import contextlib,csv,hashlib,importlib.util,io,itertools,json,os,sqlite3,subprocess,sys,tempfile,unittest
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/bike_sharing'
spec=importlib.util.spec_from_file_location('pipeline35qa',DATA/'pipeline_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'pipeline_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_35.json').read_text(encoding='utf-8'))
def independent(events,t,asof=None,latest=False):
 asof=t if asof is None else asof
 byday={r['event_day']:r for r in events};days=[d for d in range(t)if d in byday and(latest or byday[d]['available_day']<=asof)];known={d:byday[d]['cnt']for d in days};window=[known[d]for d in range(max(0,t-7),t)if d in known]
 return dict(lag1=known.get(t-1),lag7=known.get(t-7),mean7=sum(window)/len(window)if window else None,observed7=len(window),age_days=t-1-max(days)if days else None)
class QA(unittest.TestCase):
 def test_01_original_hashes_exact_first547_calendar_counts_and_reserved_scope(self):
  for name,h in m.SOURCE_HASHES.items():self.assertEqual(m.digest(DATA/name),h)
  with (DATA/'day.csv').open(encoding='utf-8',newline='')as f:raw=list(itertools.islice(csv.DictReader(f),547))
  self.assertEqual(len(raw),547);self.assertEqual(lab['report']['reserved_outcomes_used'],0)
  for scenario,events in lab['events'].items():
   self.assertEqual(len(events),547)
   for d,(original,row)in enumerate(zip(raw,events)):
    self.assertEqual(row['date'],original['dteday']);self.assertEqual(row['cnt'],int(original['cnt']));self.assertEqual(row['cnt'],int(original['casual'])+int(original['registered']));self.assertEqual(row['event_key'],'bike-global:'+original['dteday']);self.assertEqual(row['date'],(date(2011,1,1)+timedelta(days=d)).isoformat());self.assertEqual(row['available_day'],d+1+(3 if scenario=='late_fixture'and d%17==0 else 0));self.assertFalse(m.validate(row))
  self.assertEqual(raw[-1]['dteday'],'2012-06-30')
 def test_02_all1092_independent_point_in_time_and_retrospective_vectors(self):
  for scenario,events in lab['events'].items():
   mismatches=0;missing=0
   for ref in lab['statistics'][scenario]['snapshots_data']:
    t=ref['target'];actual=independent(events,t);latest=independent(events,t,latest=True);self.assertEqual(actual,ref['features']);self.assertEqual(latest,ref['latest']);self.assertEqual(actual,m.features(events,t));self.assertEqual(m.difference(actual,latest),ref['different']);mismatches+=bool(m.difference(actual,latest));missing+=actual['lag1']is None
   self.assertEqual([mismatches,missing], [98,33]if scenario=='late_fixture'else[0,0])
 def test_03_actual_sqlite_queries_and_incremental_arrival_prefix_match_all_cutoffs(self):
  for scenario,events in lab['events'].items():
   db=m.connect();arrivals=sorted(events,key=lambda r:(r['available_day'],r['event_day']));cursor=0;known=[]
   for target in range(1,547):
    batch=[]
    while cursor<len(arrivals)and arrivals[cursor]['available_day']<=target:batch.append(arrivals[cursor]);known.append(arrivals[cursor]);cursor+=1
    m.ingest(db,batch,scenario=scenario);ref=independent(events,target);self.assertEqual(m.sql_features(db,target,scenario),ref);self.assertEqual(m.features(known,target),ref)
   db.close()
 def test_04_duplicates_invalid_and_conflicting_payloads_chunking_and_order(self):
  events=lab['events']['late_fixture']
  for name,dup,bad in [('normal',False,False),('duplicates',True,False),('invalid',True,True)]:self.assertEqual(m.replay(events,dup,bad),lab['replays'][name])
  for chunk in [1,32,128]:
   db=m.connect();rows=list(reversed(events))+events+[dict(events[0],cnt=-1),dict(events[1],cnt=events[1]['cnt']+1)];r=m.ingest(db,rows,'late_fixture',chunk);self.assertEqual([r[k]for k in ['inserted','duplicates','rejected']],[547,547,2]);self.assertEqual(db.execute('SELECT COUNT(*) FROM events').fetchone()[0],547);self.assertEqual(m.sql_features(db,375,'late_fixture'),independent(events,375));db.close()
  self.assertEqual(m.replay([])['stored'],0)
 def test_05_atomic_batch_failure_retry_and_quality_boundaries(self):
  events=lab['events']['on_time'];db=m.connect()
  with self.assertRaises(RuntimeError):m.ingest(db,events[:64],chunk=32,fail_batch=1)
  self.assertEqual(db.execute('SELECT COUNT(*) FROM events').fetchone()[0],32);r=m.ingest(db,events[:64]);self.assertEqual([r['inserted'],r['duplicates']],[32,32]);db.close()
  row=events[0]
  for bad,reason in [(dict(row,cnt=-1),'negative_count'),(dict(row,cnt=True),'type:cnt'),(dict(row,date=None),'type:date'),(dict(row,available_day=0),'availability_before_day_close'),(dict(row,event_key='bad'),'entity_key')]:self.assertIn(reason,m.validate(bad))
 def test_06_window_endpoints_empty_nulls_asof_backfill_and_guard_before_compute(self):
  events=lab['events']['late_fixture'];pit=m.features(events,375);self.assertIsNone(pit['lag1']);self.assertEqual(pit['observed7'],6);self.assertEqual(pit['age_days'],1);self.assertIsNone(m.features(events,375,asof=377)['lag1']);self.assertEqual(m.features(events,375,asof=378)['lag1'],events[374]['cnt'])
  self.assertEqual(m.features(events,1),dict(lag1=None,lag7=None,mean7=None,observed7=0,age_days=None));mutated=[dict(r,cnt=999999)if r['event_day']>=375 else r for r in events];self.assertEqual(m.features(mutated,375),pit)
  expected=m.manifest('late_fixture')
  for key in expected:
   wrong=dict(expected,**{key:'declared fault'});self.assertEqual(m.contract_errors(expected,wrong),[key]);self.assertIsNone(m.guarded_features([],375,expected,wrong));wrong=dict(expected);wrong.pop(key);self.assertEqual(m.contract_errors(expected,wrong),[key])
  self.assertEqual(m.guarded_features(events,375,expected,dict(expected)),pit)
 def test_07_portable_sqlite_export_actual_checksums_notice_and_tamper_rejection(self):
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'bundle';subprocess.run([sys.executable,str(DATA/'pipeline_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);result=m.verify_bundle(out);self.assertEqual(result,dict(verified=True,files=5,event_rows=1094,snapshots=1092));self.assertEqual((out/'SOURCE_README.txt').read_bytes(),(DATA/'Readme.txt').read_bytes());self.assertIn('CC BY4.0',(out/'ATTRIBUTION.txt').read_text());self.assertEqual(json.loads(subprocess.check_output([sys.executable,str(DATA/'pipeline_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True)),result)
   with sqlite3.connect(out/'feature_store.sqlite')as db:
    for scenario,events in lab['events'].items():
     self.assertEqual(db.execute('SELECT event_day,available_day,cnt FROM events WHERE scenario=? ORDER BY event_day',(scenario,)).fetchall(),[(r['event_day'],r['available_day'],r['cnt'])for r in events])
     for t,body in db.execute('SELECT target_day,body FROM snapshots WHERE scenario=?',(scenario,)):self.assertEqual(json.loads(body),independent(events,t))
   db.close();file=out/'feature_definition.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   checks=json.loads((out/'checksums.json').read_text());checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Definition manifest mismatch'):m.verify_bundle(out)
 def test_08_exact_reproduction_and_source_asset_preserving_default_cli(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()};self.assertEqual(m.analyse(),lab)
  with tempfile.TemporaryDirectory()as td:subprocess.run([sys.executable,str(DATA/'pipeline_workflow.py')],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
  self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})
if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for l in chapter['lessons']:
  for b in l['blocks']:
   if b['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],l['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<1e-9,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=35,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True);(ROOT/'build/chapter-35-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
