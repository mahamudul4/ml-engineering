"""Run all Chapter37 teaching code and independent source/statistical/artifact audits."""
from pathlib import Path
import contextlib,copy,hashlib,importlib.util,io,json,math,os,random,sqlite3,subprocess,sys,tempfile,unittest
import numpy as np
from scipy import stats
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/nsw'
spec=importlib.util.spec_from_file_location('experiment37qa',DATA/'experiment_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'experiment_lab.json').read_text(encoding='utf-8'));chapter=json.loads((ROOT/'assets/content/chapter_37.json').read_text(encoding='utf-8'))
class QA(unittest.TestCase):
 def test_01_original_hashes_exact_records_roles_and_source_license(self):
  manifest=m.source_manifest()
  for file,ref in manifest['files'].items():self.assertEqual(hashlib.sha256((DATA/file).read_bytes()).hexdigest(),ref['sha256'])
  self.assertEqual(manifest['license'],'CC BY-NC 2.0');self.assertIn('by-nc/2.0',(DATA/'LICENSE.txt').read_text());self.assertEqual(lab['report']['experimental_units'],445)
  for file,cohort,count,arm in [('nswre74_treated.txt','treated',185,1),('nswre74_control.txt','experimental',260,0),('psid_controls.txt','psid',2490,0)]:
   raw=np.loadtxt(DATA/file);self.assertEqual(raw.shape,(count,10));self.assertEqual(len(lab['cohorts'][cohort]),count)
   for j,row in enumerate(lab['cohorts'][cohort]):
    self.assertEqual(row['key'],cohort+':'+str(j+1));self.assertEqual(row['treat'],arm)
    for name,col in [('age',1),('education',2),('re74',7),('re75',8),('re78',9)]:self.assertEqual(row[name],raw[j,col])
    self.assertNotIn('y0',row);self.assertNotIn('y1',row)
 def test_02_independent_numpy_sql_means_welch_and_all_six_intervals(self):
  db=sqlite3.connect(':memory:');db.execute('CREATE TABLE units(treat INTEGER,re78 REAL)');db.executemany('INSERT INTO units VALUES(?,?)',[(r['treat'],r['re78'])for r in lab['cohorts']['treated']+lab['cohorts']['experimental']]);sql=dict(db.execute('SELECT treat,AVG(re78) FROM units GROUP BY treat'));db.close()
  for outcome in m.OUTCOMES:
   t=np.array(m.values(lab['cohorts']['treated'],outcome));c=np.array(m.values(lab['cohorts']['experimental'],outcome));ref=stats.ttest_ind(t,c,equal_var=False)
   for conf in m.CONFIDENCES:
    r=lab['trial'][outcome][str(conf)];ci=ref.confidence_interval(conf);self.assertAlmostEqual(r['delta'],t.mean()-c.mean(),9);self.assertAlmostEqual(r['se'],np.sqrt(t.var(ddof=1)/len(t)+c.var(ddof=1)/len(c)),9);self.assertAlmostEqual(r['df'],ref.df,9);self.assertAlmostEqual(r['p_value'],ref.pvalue,12);self.assertAlmostEqual(r['lower'],ci.low,8);self.assertAlmostEqual(r['upper'],ci.high,8)
  self.assertAlmostEqual(sql[1]-sql[0],lab['trial']['earnings']['0.95']['delta'],8);self.assertEqual(sum(r['re78']>0 for r in lab['cohorts']['treated']),140);self.assertEqual(sum(r['re78']>0 for r in lab['cohorts']['experimental']),168)
 def test_03_all1000_actual_allocations_seed_uniqueness_complements_and_null_statistics(self):
  rows=lab['cohorts']['treated']+lab['cohorts']['experimental'];ys={k:np.array(m.values(rows,k))for k in m.OUTCOMES}
  for j,r in enumerate(lab['permutation_bank']):
   ids=r['treated_indices'];self.assertEqual(len(ids),185);self.assertEqual(len(set(ids)),185);self.assertTrue(all(type(i)is int and 0<=i<445 for i in ids));self.assertEqual(ids,np.random.default_rng(37000+j).permutation(445)[:185].tolist());mask=np.zeros(445,dtype=bool);mask[ids]=True
   for k,y in ys.items():self.assertAlmostEqual(r[k],y[mask].mean()-y[~mask].mean(),8);self.assertAlmostEqual(y[mask].sum()+y[~mask].sum(),y.sum(),7)
 def test_04_independent_absolute_tails_plus_one_histograms_and_mc_prefixes(self):
  for k in m.OUTCOMES:
   observed=lab['trial'][k]['0.95']['delta']
   for n in [100,500,1000]:
    null=np.array([r[k]for r in lab['permutation_bank'][:n]]);extreme=int(np.count_nonzero(np.abs(null)>=abs(observed)-1e-10*max(1,abs(observed))));r=lab['randomization'][k][str(n)];self.assertEqual(r['extreme'],extreme);self.assertEqual(r['p_value'],(extreme+1)/(n+1));self.assertEqual(sum(r['bins']),n);self.assertGreater(r['p_value'],0);self.assertEqual(m.randomization(null.tolist(),observed,n),r)
  self.assertEqual(m.randomization([0,0],10,2)['p_value'],1/3)
 def test_05_all108_designs_normal_power_scaling_de_rounding_and_srm_rehearsal(self):
  for r in lab['planning'].values():
   za=stats.norm.isf(r['alpha']/2);zb=stats.norm.ppf(r['power_target']);n=r['sigma']**2*(za+zb)**2/(r['delta']**2*r['allocation']*(1-r['allocation']));self.assertAlmostEqual(r['unrounded_total'],n,8);self.assertEqual(r['treated'],math.ceil(n*r['allocation']));self.assertEqual(r['control'],math.ceil(n*(1-r['allocation'])));mu=r['delta']/(r['sigma']*np.sqrt(1/r['treated']+1/r['control']));self.assertAlmostEqual(r['achieved_normal_power'],stats.norm.sf(za-mu)+stats.norm.cdf(-za-mu),12);self.assertEqual(r['adjusted_units'],math.ceil(r['total']*(1+(r['cluster_size']-1)*r['icc'])))
  def hash32(key):
   h=0x811c9dc5
   for b in key.encode():h=((h^b)*0x1000193)%2**32
   return h%10000
  rows=lab['cohorts']['treated']+lab['cohorts']['experimental']
  for loss in [False,True]:
   counts=[0,0];dropped=0
   for j,row in enumerate(rows):
    arm=int(hash32('ch37-assignment:'+row['key'])<5000)
    if loss and arm==1 and j%3==0:dropped+=1
    else:counts[arm]+=1
   ref=lab['logging'][str(loss)];self.assertEqual([ref['control'],ref['treated'],ref['dropped']],counts+[dropped]);self.assertAlmostEqual(ref['p_value'],stats.chisquare(counts).pvalue,12)
  self.assertEqual(lab['logging']['True']['dropped'],77)
 def test_06_independent_all_observational_strata_smd_and_missing_overlap_guard(self):
  for comp in ['experimental','psid']:
   t=lab['cohorts']['treated'];c=lab['cohorts'][comp]
   for outcome in m.OUTCOMES:
    get=lambda r:r['re78']if outcome=='earnings'else float(r['re78']>0)
    raw=np.mean([get(r)for r in t])-np.mean([get(r)for r in c]);weighted=0
    for positive in [False,True]:
     tr=[get(r)for r in t if (r['re74']>0)==positive];cr=[get(r)for r in c if (r['re74']>0)==positive];weighted+=len(tr)/185*(np.mean(tr)-np.mean(cr))
    for adjusted in [False,True]:
     r=lab['observational'][comp][outcome][str(adjusted)];self.assertAlmostEqual(r['raw_gap'],raw,8);self.assertAlmostEqual(r['adjusted_gap'],weighted,8);self.assertAlmostEqual(r['shown_gap'],weighted if adjusted else raw,8)
     for key in ['age','education','re74','re75']:
      a=np.array([r[key]for r in t]);b=np.array([r[key]for r in c]);smd=(a.mean()-b.mean())/np.sqrt((a.var(ddof=1)+b.var(ddof=1))/2);self.assertAlmostEqual(r['smd'][key],smd,10)
  cohorts=copy.deepcopy(lab['cohorts']);cohorts['psid']=[r for r in cohorts['psid']if r['re74']>0];r=m.observational(cohorts,adjust=True);self.assertFalse(r['empirical_overlap']);self.assertIsNone(r['shown_gap'])
 def test_07_interacted_ols_hc2_and_holm_crosscheck_boundaries(self):
  rows=lab['cohorts']['treated']+lab['cohorts']['experimental'];t=np.array([r['treat']for r in rows]);x=np.array([r['re75']for r in rows]);x=(x-x.mean())/x.std();y=np.array([r['re78']for r in rows]);z=np.column_stack([np.ones(445),t,x,t*x]);q,upper=np.linalg.qr(z);beta=np.linalg.solve(upper,q.T@y);res=y-z@beta;inv=np.linalg.solve(z.T@z,np.eye(4));cov=np.zeros((4,4))
  for row,e,h in zip(z,res,(q*q).sum(1)):cov+=np.outer(inv@row,inv@row)*e*e/(1-h)
  np.testing.assert_allclose(beta,lab['ancova']['coefficients'],atol=1e-8);self.assertAlmostEqual(np.sqrt(cov[1,1]),lab['ancova']['hc2_se'],8);self.assertEqual(m.holm([.5,.01,.01]),[.5,.03,.03]);self.assertEqual(m.holm([]),[]);self.assertEqual(m.holm(lab['multiplicity']['raw']),lab['multiplicity']['holm'])
  for bad in [[float('nan')],[-.1],[1.1]]:
   with self.assertRaises(ValueError):m.holm(bad)
  with self.assertRaises(ValueError):m.plan(1,delta=0)
  with self.assertRaises(ValueError):m.welch([1,1],[1,1])
 def test_08_exact_reproduction_rng_default_cli_and_portable_bundle_tampering(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()};rng=random.getstate();npstate=np.random.get_state();self.assertEqual(m.analyse(),lab);self.assertEqual(random.getstate(),rng);self.assertTrue(np.array_equal(np.random.get_state()[1],npstate[1]))
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'bundle';subprocess.run([sys.executable,str(DATA/'experiment_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(m.verify_bundle(out),dict(verified=True,files=5,experimental_units=445,external_controls=2490));self.assertEqual((out/'LICENSE.txt').read_bytes(),(DATA/'LICENSE.txt').read_bytes());self.assertIn('LaLonde',(out/'ATTRIBUTION.txt').read_text());self.assertEqual(json.loads(subprocess.check_output([sys.executable,str(DATA/'experiment_workflow.py'),'--verify-dir',str(out)],cwd=td,text=True))['files'],5)
   file=out/'analysis_contract.json';file.write_bytes(file.read_bytes()+b' ')
   with self.assertRaisesRegex(ValueError,'Checksum mismatch'):m.verify_bundle(out)
   contract=json.loads(file.read_text());contract['individual_counterfactuals_observed']=True;file.write_text(json.dumps(contract));checks=json.loads((out/'checksums.json').read_text());checks[file.name]=m.digest(file);(out/'checksums.json').write_text(json.dumps(checks))
   with self.assertRaisesRegex(ValueError,'Analysis contract mismatch'):m.verify_bundle(out)
  self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})
if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for exercise in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(exercise['solution'],exercise['id'],'exec'),scope)
  assert abs(scope['result']-exercise['expected'])<=max(1e-8,abs(exercise['expected'])*1e-12),exercise['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful();report=dict(chapter=37,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,experimental_source_units=445,external_controls=2490,live_experiment_conducted=False,passed=True);(ROOT/'build/chapter-37-code-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report)
