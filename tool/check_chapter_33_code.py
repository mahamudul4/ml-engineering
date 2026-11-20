"""Run Chapter33 code and audit frozen ranking/uncertainty without training."""
from pathlib import Path
import contextlib, hashlib, importlib.util, io, json, math, os, subprocess, sys, tempfile, unittest
from collections import Counter
import numpy as np

ROOT=Path(__file__).resolve().parent.parent
DATA=ROOT/'assets/datasets/movielens'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
m=load('evaluation33',DATA/'recommendation_evaluation_workflow.py')
prior=load('independent32',ROOT/'tool/check_chapter_32_code.py')
lab=json.loads((DATA/'recommendation_evaluation_lab.json').read_text())
base=json.loads((DATA/'recommendation_lab.json').read_text(encoding='utf-8'))
deep=json.loads((DATA/'deep_recommendation_lab.json').read_text())
chapter=json.loads((ROOT/'assets/content/chapter_33.json').read_text(encoding='utf-8'))

def independent_metrics(ranked,gold):
 gold=set(gold);top=ranked[:10];hits=len(gold.intersection(top))
 dcg=sum(1/math.log2(j+2) for j,i in enumerate(top) if i in gold)
 return np.array([hits/10,hits/len(gold),dcg/sum(1/math.log2(j+2)for j in range(min(10,len(gold)))),next((1/(j+1)for j,i in enumerate(top)if i in gold),0.)])

class QA(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  prior.QA.setUpClass();cls.p=prior.QA
  cls.genres={i:cls.p.genres[j]for j,i in enumerate(deep['items'])}
  cls.pop=Counter(i for u,i,r,t in base['train']if r>=4)
 def test_01_original_hashes_rows_and_frozen_predictions(self):
  for name,h in lab['report']['source_hashes'].items():self.assertEqual(m.digest(DATA/name),h)
  self.assertEqual(lab['report']['warm_users'],28);self.assertEqual(lab['report']['broad_users'],116);self.assertEqual(lab['report']['cold_users'],88)
  for row,original in zip(lab['rows'],deep['rows']):
   for key in ['user','train_count','positive','eligible']:self.assertEqual(row[key],original[key])
   for method in ['neural50','neural100','hybrid50','user_cf','popularity']:self.assertEqual(row['rankings'][method],original['rankings'][method])
   self.assertEqual(row['rankings']['mmr1'],original['rankings']['neural100'])
 def test_02_independent_macro_metrics_all_methods_cohorts_and_windows(self):
  for container in [lab,*lab['windows'].values()]:
   for method,cards in container['scorecards'].items():
    scopes=cards if container is lab else {'warm':cards}
    for scope,ref in scopes.items():
     selected=[r for r in container['rows']if (r['train_count']>0 and r['eligible'])]if scope=='warm'else[r for r in container['rows']if r['positive']and(scope!='cold'or r['train_count']==0)]
     self.assertEqual(len(selected),ref['users']);values=[independent_metrics(r['rankings'][method],r['eligible'if scope=='warm'else'positive'])for r in selected]
     np.testing.assert_allclose(np.mean(values,axis=0),[ref[k]for k in ['precision','recall','ndcg','mrr']],atol=1e-12)
 def test_03_independent_paired_differences_5000_draws_and_linear_quantiles(self):
  selected=[r for r in lab['rows']if r['train_count']and r['eligible']]
  for key,value in lab['paired'].items():
   treatment,control,metric=key.split(':');column={'recall':1,'ndcg':2}[metric]
   x=np.array([independent_metrics(r['rankings'][treatment],r['eligible'])[column]-independent_metrics(r['rankings'][control],r['eligible'])[column]for r in selected])
   self.assertEqual([r['user']for r in selected],[r['user']for r in value['rows']]);b=value['bootstrap'];draws=x[np.random.default_rng(33).integers(28,size=(5000,28))].mean(1)
   np.testing.assert_allclose(draws,b['replicates'],atol=1e-15);np.testing.assert_allclose(np.quantile(draws,[.025,.975],method='linear'),[b['low'],b['high']],atol=1e-15);self.assertAlmostEqual(x.mean(),b['mean'])
  b=lab['paired']['neural50:user_cf:recall']['bootstrap'];self.assertGreater(b['mean'],0);self.assertLess(b['low'],0);self.assertGreater(b['high'],0)
 def test_04_independent_all348_mmr_lists_saved_logits_and_case_traces(self):
  examples={s['user']:s for s in lab['samples']};p=self.p
  for row,original in zip(lab['rows'],deep['rows']):
   pool=original['pipelines']['neural100']['candidates'];cold=original['pipelines']['neural100']['fallback']
   raw=np.array([self.pop[i]for i in pool],dtype=float)if cold else np.array([float(p.rank(p.features(p.um[row['user']],p.im[i])))for i in pool])
   relevance=(raw-raw.min())/np.ptp(raw)if np.ptp(raw)>0 else raw*0
   for strength in [1.,.75,.5]:
    chosen=[];trace=[]
    for step in range(10):
     left=[j for j in range(len(pool))if j not in chosen];redundancy={j:max([float(self.genres[pool[j]]@self.genres[pool[s]])for s in chosen],default=0.)for j in left};utility={j:strength*relevance[j]-(1-strength)*redundancy[j]for j in left};best=sorted(left,key=lambda j:(-round(utility[j],12),pool[j]))[0];chosen.append(best);trace.append([raw[best],relevance[best],redundancy[best],utility[best]])
    key=f'mmr{strength:g}';self.assertEqual([pool[j]for j in chosen],row['rankings'][key])
    if row['user']in examples:
     sample=examples[row['user']];self.assertEqual(sample['fallback'],cold);np.testing.assert_allclose(raw,sample['scores'],atol=1e-11);ref=sample['results'][key];self.assertEqual(ref['ranked'],row['rankings'][key]);np.testing.assert_allclose(trace,[[v[k]for k in ['raw','relevance','redundancy','utility']]for v in ref['trace']],atol=1e-11)
 def test_05_independent_genre_ild_rarity_coverage_and_slot_entropy(self):
  warm=[r for r in lab['rows']if r['train_count']and r['eligible']]
  for method,ref in lab['diversity'].items():
   lists=[r['rankings'][method]for r in warm];counts=Counter(i for ids in lists for i in ids)
   ild=np.mean([np.mean([1-float(self.genres[a]@self.genres[b])for j,a in enumerate(ids)for b in ids[j+1:]])for ids in lists]);novelty=np.mean([-math.log2((self.pop[i]+1)/(39254+7867))for ids in lists for i in ids]);entropy=-sum((n/280)*math.log2(n/280)for n in counts.values())
   np.testing.assert_allclose([ild,novelty,len(counts)/7867,entropy],[ref[k]for k in ['ild','novelty_bits','catalog_coverage','recommendation_entropy_bits']],atol=1e-12);self.assertEqual(len(counts),ref['distinct_recommended'])
  self.assertGreater(lab['diversity']['mmr0.5']['ild'],lab['diversity']['mmr1']['ild']);self.assertLess(lab['scorecards']['mmr0.5']['warm']['recall'],lab['scorecards']['mmr1']['warm']['recall'])
 def test_06_independent_window_gold_and_split_timestamp_only_audit(self):
  future=base['future'];boundary=sorted(r[3]for r in future)[len(future)//2];self.assertEqual(boundary,1498029450)
  for name,window in lab['windows'].items():
   events=[r for r in future if (r[3]<=boundary)==(name=='early')];self.assertEqual(len(events),window['events'])
   for row,original in zip(window['rows'],lab['rows']):
    gold={i for u,i,r,t in events if u==row['user']and r>=4};seen={i for u,i,r,t in base['train']if u==row['user']};self.assertEqual(row['positive'],sorted(gold));self.assertEqual(row['eligible'],sorted(gold.intersection(self.genres)-seen));self.assertEqual(row['rankings'],original['rankings'])
  allrows=np.array(base['train']+future);order=np.random.default_rng(330).permutation(len(allrows));fit=allrows[order[:int(.8*len(allrows))]];test=allrows[order[int(.8*len(allrows)):]];audit=lab['split_audit'];self.assertEqual(audit['random_fit_max'],int(fit[:,3].max()));self.assertEqual(audit['random_test_min'],int(test[:,3].min()));self.assertEqual(audit['random_fit_after_global_cutoff'],int((fit[:,3]>audit['global_cutoff']).sum()));self.assertEqual(audit['random_test_before_or_equal_global_cutoff'],int((test[:,3]<=audit['global_cutoff']).sum()));pf=[];pt=[]
  for uid in np.unique(allrows[:,0]):
   rows=allrows[allrows[:,0]==uid];cut=np.sort(rows[:,3])[int(.8*len(rows))-1];pf.extend(rows[rows[:,3]<=cut].tolist());pt.extend(rows[rows[:,3]>cut].tolist())
  self.assertEqual([len(pf),len(pt),max(r[3]for r in pf),min(r[3]for r in pt)],[audit[k]for k in ['per_user_fit_rows','per_user_test_rows','per_user_fit_max','per_user_test_min']])
 def test_07_declared_algebra_fixture_and_planner_no_empirical_online_claim(self):
  for name,weights in [('fixture',[1.25,5,0,0]),('fixture_clipped',[1.25,2,0,0])]:
   ref=lab[name];self.assertEqual(ref['weights'],weights);self.assertEqual(ref['ips'],sum(weights)/4);self.assertEqual(ref['snips'],1);self.assertAlmostEqual(ref['ess'],sum(weights)**2/sum(w*w for w in weights));self.assertEqual(len(ref['rows']),4)
  self.assertEqual(m.propensity_fixture(0)['snips'],None);self.assertEqual(m.sample_size(),14112);self.assertEqual(m.sample_size(mde=.005),56448);self.assertEqual(lab['planner']['per_arm'],14112)
 def test_08_full_reproduction_external_cwd_checksums_rng_and_asset_preservation(self):
  before={p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()};state=np.random.get_state();self.assertEqual(m.analyse(),lab);after=np.random.get_state();self.assertEqual(state[0],after[0]);np.testing.assert_array_equal(state[1],after[1]);self.assertEqual(state[2:],after[2:])
  with tempfile.TemporaryDirectory()as td:
   out=Path(td)/'artifacts';subprocess.run([sys.executable,str(DATA/'recommendation_evaluation_workflow.py'),'--artifact-dir',str(out)],cwd=td,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,check=True);self.assertEqual(json.loads((out/'recommendation_evaluation_lab.json').read_text()),lab);self.assertEqual(json.loads((out/'checksums.json').read_text())['recommendation_evaluation_lab.json'],m.digest(out/'recommendation_evaluation_lab.json'))
  self.assertEqual(before,{p.name:m.digest(p)for p in DATA.iterdir()if p.is_file()})

if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for b in lesson['blocks']:
   if b['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),{})
    snippets+=1
 for exercise in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(exercise['solution'],exercise['id'],'exec'),scope)
  assert abs(scope['result']-exercise['expected'])<1e-9,exercise['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful()
 report=dict(chapter=33,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True)
 (ROOT/'build/chapter-33-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
