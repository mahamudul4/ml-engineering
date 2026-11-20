"""Execute Chapter36 code and independently audit fit, routing, monitoring, bundles and HTTP."""
from pathlib import Path
import contextlib,copy,csv,hashlib,importlib.util,io,itertools,json,math,os,random,subprocess,sys,tempfile,threading,unittest,urllib.request,urllib.error
from unittest.mock import patch
import numpy as np
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/bike_sharing'
spec=importlib.util.spec_from_file_location('serving36qa',DATA/'serving_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'serving_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_36.json').read_text(encoding='utf-8'))
def independent_features(events,t):
 known={r['event_day']:r['cnt']for r in events if r['event_day']<t and r['available_day']<=t};window=[known[d]for d in range(t-7,t)if d in known]
 return dict(lag1=known.get(t-1),lag7=known.get(t-7),mean7=sum(window)/len(window)if window else None,observed7=len(window),age_days=t-1-max(known)if known else None)
def fnv(key):
 h=0x811c9dc5
 for v in key.encode('utf-8'):h=((h^v)*0x1000193)%2**32
 return h%10000
class QA(unittest.TestCase):
 def test_01_original_prefix_calendar_source_hash_and_all_feature_boundaries(self):
  for file,h in lab['report']['source_hashes'].items():self.assertEqual(m.digest(DATA/file),h)
  with (DATA/'day.csv').open(encoding='utf-8',newline='')as f:raw=list(itertools.islice(csv.DictReader(f),547))
  self.assertEqual(raw[-1]['dteday'],'2012-06-30');self.assertEqual(lab['report']['reserved_outcomes_used'],0)
  for scenario,events in lab['events'].items():
   self.assertEqual(len(events),547)
   for d,(r,e)in enumerate(zip(raw,events)):
    self.assertEqual((e['date'],e['cnt'],e['event_day']),(r['dteday'],int(r['cnt']),d));self.assertEqual(e['available_day'],d+1+(3 if scenario=='late_fixture'and d%17==0 else 0))
   for t in range(365,547):self.assertEqual(independent_features(events,t),m.source().features(events,t))
  for r in lab['training']+lab['rows']:self.assertEqual(r['features'],independent_features(lab['events']['on_time'],r['target']))
  self.assertEqual([r['target']for r in lab['training']],list(range(7,365)));self.assertEqual([r['target']for r in lab['rows']],list(range(365,547)))
 def test_02_independent_ridge_scaler_normal_equation_and_all_predictions(self):
  train=lab['training'];x=np.array([[r['features'][k]for k in m.FIELDS]for r in train]);y=np.array([r['outcome']for r in train]);mu=x.mean(0);sd=x.std(0);z=(x-mu)/sd;intercept=y.mean();w=np.linalg.lstsq(np.vstack([z,np.sqrt(10)*np.eye(3)]),np.r_[y-intercept,np.zeros(3)],rcond=None)[0];model=lab['models']['candidate']
  np.testing.assert_allclose(model['mean'],mu,atol=1e-10);np.testing.assert_allclose(model['scale'],sd,atol=1e-10);np.testing.assert_allclose(model['weights'],w,rtol=1e-12);self.assertAlmostEqual(model['intercept'],intercept,10);np.testing.assert_allclose(z.T@(z@w-(y-intercept))+10*w,0,atol=1e-8)
  for r in lab['rows']:
   predicted=max(0,intercept+((np.array([r['features'][k]for k in m.FIELDS])-mu)/sd)@w);self.assertAlmostEqual(predicted,r['candidate'],9);self.assertEqual(r['baseline'],r['features']['lag7']);self.assertEqual(r['naive1'],r['features']['lag1'])
  for changes in [dict(scale=[1,0,1]),dict(weights=[1,2]),dict(intercept=float('nan')),dict(model_version=''),dict(mean=[1,float('inf'),3])]:self.assertIsNone(m.predict(dict(model,**changes),lab['rows'][0]['features']))
  self.assertIsNone(m.predict(model,dict(lag1=True,lag7=1,mean7=1)));self.assertEqual(m.predict(dict(model,intercept=-1e9),lab['rows'][0]['features']),0)
 def test_03_independent_all_routes_fallbacks_rollbacks_and_precompute_guard(self):
  self.assertEqual(fnv('hello'),0x4f9f2cab%10000)
  for key in ['','a','hello','বাংলা']+['bike-global:'+r['date']for r in lab['rows']]:self.assertEqual(fnv(key),m.route_bucket(key))
  for scenario in lab['events']:
   for bp in [0,1000,5000,10000]:
    counts=dict(requests=182,candidate=0,baseline=0,fallback=0,blocked=0)
    for r in lab['rows']:
     f=independent_features(lab['events'][scenario],r['target']);chosen=fnv('bike-global:'+r['date'])<bp;name='baseline'if not chosen else'fallback'if any(f[k]is None for k in m.FIELDS)else'candidate';counts[name]+=1;actual=m.serve(lab,r['target'],scenario,bp);self.assertEqual(actual['served'],name);self.assertNotIn('outcome',actual)
    self.assertEqual(counts,lab['rollouts'][scenario][str(bp)]);self.assertEqual(m.replay(lab,scenario,bp),counts)
   self.assertEqual(m.replay(lab,scenario,rollback=True)['baseline'],182);self.assertEqual(m.replay(lab,scenario,candidate_fault=True)['fallback'],182)
  with patch.object(m.source(),'features',side_effect=AssertionError('must not compute')):self.assertEqual(m.serve(lab,375,baseline_fault=True)['status'],'BLOCKED')
  for target in [True,364,547,'375']:
   with self.assertRaises(ValueError):m.serve(lab,target)
  for key in lab['manifests']['candidate']:
   bad=copy.deepcopy(lab);bad['manifests']['candidate'][key]='wrong';self.assertEqual(m.serve(bad,375)['served'],'fallback');bad=copy.deepcopy(lab);bad['manifests']['baseline'].pop(key);self.assertEqual(m.serve(bad,375)['status'],'BLOCKED')
 def test_04_independent_all_psi_edges_right_bins_smoothing_masses(self):
  for period,(start,end)in m.PERIODS.items():
   for field in m.FIELDS:
    x=np.array([r['features'][field]for r in lab['training']]);y=np.array([r['features'][field]for r in lab['rows']if start<=r['target']<=end]);edges=np.unique(np.quantile(x,[.2,.4,.6,.8],method='linear'));rc=np.bincount(np.searchsorted(edges,x,side='right'),minlength=len(edges)+1);oc=np.bincount(np.searchsorted(edges,y,side='right'),minlength=len(edges)+1);p=(rc+.5)/(len(x)+.5*len(rc));q=(oc+.5)/(len(y)+.5*len(oc));value=np.sum((q-p)*np.log(q/p));ref=lab['monitoring'][period][field]
    np.testing.assert_allclose(ref['edges'],edges);self.assertEqual(ref['reference_bins'],rc.tolist());self.assertEqual(ref['observed_bins'],oc.tolist());np.testing.assert_allclose(ref['reference_mass'],p);np.testing.assert_allclose(ref['observed_mass'],q);self.assertAlmostEqual(ref['psi'],value,12);self.assertAlmostEqual(sum(p),1,12);self.assertEqual(m.psi(x.tolist(),y.tolist(),edges.tolist()),ref)
 def test_05_independent_label_maturity_and_paired_quality_all_windows(self):
  for period,(start,end)in m.PERIODS.items():
   for delay in [0,2,7]:
    selected=[r for r in lab['rows']if start<=r['target']<=end and r['target']+1+delay<=end+1];ref=lab['quality'][period][str(delay)];self.assertEqual(ref['mature_labels'],(182 if period=='full'else 91)-delay)
    for model in ['candidate','baseline','naive1']:
     errors=np.array([r[model]-r['outcome']for r in selected]);actual=ref['models'][model];self.assertEqual(actual['labels'],len(errors));self.assertAlmostEqual(actual['mae'],np.abs(errors).mean(),9);self.assertAlmostEqual(actual['rmse'],np.sqrt((errors**2).mean()),9);self.assertAlmostEqual(actual['bias'],errors.mean(),9)
    self.assertEqual(m.quality(lab['rows'],period,delay),ref)
 def test_06_slo_composite_histograms_quantile_and_budget_arithmetic(self):
  rows=lab['slo']['rows'];d=np.array([18,22,25,40,35,60,80,95,110,25,70,130,45,20,200,30,85,90,150,15]);self.assertEqual([r['duration_ms']for r in rows],d.tolist());self.assertEqual([j for j,r in enumerate(rows)if not r['ok']],[8,14]);self.assertAlmostEqual(np.quantile(d,.95),152.5,10)
  for threshold in [50,100,200]:
   for target in [.95,.99,.999]:
    s=m.slo_fixture(threshold,target);good=sum(r['ok']and r['duration_ms']<=threshold for r in rows);self.assertEqual(s['good'],good);self.assertEqual(s['composite_sli'],good/20);self.assertEqual(s['availability'],.9);self.assertAlmostEqual(s['allowed_bad'],20*(1-target),12);self.assertAlmostEqual(s['burn_rate'],((20-good)/20)/(1-target),10);self.assertEqual([b['count']for b in s['histogram']],[6,10,16,20])
  self.assertAlmostEqual(m.slo_fixture()['p95_success'],133,10);self.assertIsNone(m.quantile([],.95));self.assertEqual(m.slo_fixture(),lab['slo'])
 def test_07_external_cwd_bundle_bytes_tamper_crosslinks_and_source_preservation(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()};rng=random.getstate();npstate=np.random.get_state();self.assertEqual(m.analyse(),lab);self.assertEqual(random.getstate(),rng);self.assertTrue(np.array_equal(np.random.get_state()[1],npstate[1]))
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'release';subprocess.run([sys.executable,str(DATA/'serving_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(m.verify_bundle(out)['files'],6);self.assertEqual((out/'SOURCE_README.txt').read_bytes(),(DATA/'Readme.txt').read_bytes())
   subprocess.run([sys.executable,str(DATA/'serving_workflow.py'),'--bundle',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True)
   for name,h in json.loads((out/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((out/name).read_bytes()).hexdigest(),h)
   file=out/'ridge_model.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   checks=json.loads((out/'checksums.json').read_text());checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Release manifest mismatch'):m.verify_bundle(out)
   m.export_bundle(out,lab);bad=copy.deepcopy(lab);bad['manifests']['baseline']['source_sha256']='wrong';m.export_bundle(out,bad)
   with self.assertRaisesRegex(ValueError,'Release metadata mismatch'):m.verify_bundle(out)
  self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})
 def test_08_actual_loopback_http_requests_readiness_errors_fallbacks_and_metrics(self):
  actual=copy.deepcopy(lab);server=m.make_http_server(actual,0);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start();base='http://127.0.0.1:'+str(server.server_address[1])
  def request(path,body=None):
   data=None if body is None else json.dumps(body).encode();req=urllib.request.Request(base+path,data=data,headers={'Content-Type':'application/json'})
   try:
    with urllib.request.urlopen(req,timeout=5)as response:return response.status,response.read()
   except urllib.error.HTTPError as e:return e.code,e.read()
  try:
   self.assertEqual(server.server_address[0],'127.0.0.1');self.assertEqual(request('/healthz')[0],200);self.assertEqual(request('/readyz')[0],200)
   for body in [dict(target=375),dict(target=375,scenario='late_fixture'),dict(target=545,rollback=True)]:
    status,data=request('/predict',body);self.assertEqual(status,200);response=json.loads(data);self.assertEqual(response,m.serve(lab,**body));self.assertNotIn('outcome',response);self.assertEqual(response['model_version'],'ridge36-v1'if response['served']=='candidate'else'seasonal7-v1');self.assertEqual(response['feature_version'],'bike-features35-v1')
   for body in [dict(target=547),dict(target=True),dict(target=375,canary_bp=False),dict(target=375,rollback='yes'),dict(target=375,outcome=2177),{}]:self.assertEqual(request('/predict',body)[0],400)
   self.assertEqual(request('/unknown')[0],404);metrics=request('/metrics')[1].decode();self.assertIn('mlops_predict_requests_total 9',metrics);self.assertIn('mlops_predict_errors_total 6',metrics);self.assertIn('mlops_predict_fallbacks_total 1',metrics)
   actual['models']['candidate']['scale']=[1,0,1];self.assertEqual(request('/readyz')[0],503);status,data=request('/predict',dict(target=375));self.assertEqual(status,200);self.assertEqual(json.loads(data)['served'],'fallback')
   actual['manifests']['baseline']['model_sha256']='wrong';self.assertEqual(request('/predict',dict(target=375))[0],503);self.assertEqual(request('/healthz')[0],200)
  finally:server.shutdown();server.server_close();thread.join(timeout=5)
  self.assertFalse(thread.is_alive())
if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<1e-8,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=36,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,actual_http_functional_test=True,production_latency_measured=False,passed=True);(ROOT/'build/chapter-36-code-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report)
