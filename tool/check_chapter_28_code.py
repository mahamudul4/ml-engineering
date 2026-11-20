"""Execute all Chapter28 walkthroughs/solutions and independent behavior checks."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,os,subprocess,sys,tempfile,unittest
import numpy as np
import torch
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/digits'
s=importlib.util.spec_from_file_location('diffusion_qa',DATA/'diffusion_workflow.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
lab=json.loads((DATA/'diffusion_lab.json').read_text());chapter=json.loads((ROOT/'assets/content/chapter_28.json').read_text(encoding='utf-8'))
def reload(cls,name):
 model=cls();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in lab['weights'][name].items()});return model
class QA(unittest.TestCase):
 def test_01_original_bytes_roles_and_real_source_pixels(self):
  raw,y,fit,diag=m.source();self.assertEqual(hashlib.sha256((DATA/'digits.csv.gz').read_bytes()).hexdigest(),lab['report']['source_sha256']);np.testing.assert_array_equal(fit+1,lab['report']['fit_rows_1based']);np.testing.assert_array_equal(diag+1,lab['report']['diagnostic_rows_1based'])
  for row in lab['samples']:
   i=row['source_row_1based']-1;self.assertIn(i,diag);self.assertEqual(y[i],row['digit']);np.testing.assert_array_equal(raw[i].reshape(64)/16,row['unit_pixels']);self.assertEqual(i,next(i for i in diag if y[i]==row['digit']))
 def test_02_independent_cosine_schedule_and_posterior_precision(self):
  t=np.arange(33)/32;f=np.cos((t+.008)/1.008*np.pi/2)**2;b=np.minimum(1-f[1:]/f[:-1],.999);bar=np.r_[1.,np.cumprod(1-b)]
  np.testing.assert_allclose(b,lab['beta'],atol=1e-14);np.testing.assert_allclose(bar,lab['alpha_bar'],atol=1e-14)
  for t in range(2,33):
   beta=b[t-1];posterior=beta*(1-bar[t-1])/(1-bar[t]);precision=(1-beta)/beta+1/(1-bar[t-1]);self.assertAlmostEqual(posterior,1/precision,places=13)
 def test_03_all_corruptions_denoisers_and_alignment_numpy_forwards(self):
  d=reload(m.Denoiser,'denoiser');a=reload(m.Alignment,'alignment');bar=np.array(lab['alpha_bar']);w=lab['weights']['alignment']
  text=np.array(w['names.weight']);text/=np.linalg.norm(text,axis=1,keepdims=True);np.testing.assert_allclose(text,lab['text_embeddings'],atol=1e-13)
  for row in lab['samples']:
   x=np.array(row['unit_pixels']);h=np.maximum(x@np.array(w['image.weight']).T+w['image.bias'],0);emb=h@np.array(w['project.weight']).T+w['project.bias'];emb/=np.linalg.norm(emb)
   np.testing.assert_allclose(emb,row['image_embedding'],atol=1e-13);np.testing.assert_allclose(text@emb,row['cosines'],atol=1e-13)
   for ref in row['references']:
    t=ref['t'];xt=np.sqrt(bar[t])*(2*x-1)+np.sqrt(1-bar[t])*np.array(row['epsilon']);np.testing.assert_allclose(xt,ref['xt'],atol=1e-13)
    with torch.no_grad():
     for c,key in [(row['digit'],'conditional'),(10,'null')]:np.testing.assert_allclose(d(torch.tensor([xt],dtype=torch.float64),torch.tensor([t]),torch.tensor([c]))[0],ref[key],atol=1e-12)
 def test_04_all_reverse_trajectories_independent_numpy_network_and_ddim(self):
  w={k:np.array(v) for k,v in lab['weights']['denoiser'].items()};bar=np.array(lab['alpha_bar'])
  def predict(x,t,label):
   angle=np.pi*t/32;c=np.zeros(11);c[label]=1;h=np.r_[x,np.sin(angle),np.cos(angle),np.sin(2*angle),np.cos(2*angle),c]
   for layer in ['first','hidden']:
    h=h@w[layer+'.weight'].T+w[layer+'.bias'];h=h/(1+np.exp(-h))
   return h@w['out.weight'].T+w['out.bias']
  for ref in lab['traces']:
   x=np.array(lab['initial']);ts=np.rint(np.linspace(32,1,ref['steps'])).astype(int).tolist()
   np.testing.assert_array_equal(x,ref['trace'][0]['pixels'])
   for i,t in enumerate(ts):
    u=predict(x,t,10);c=predict(x,t,ref['label']);eps=u+ref['guidance']*(c-u);previous=ts[i+1] if i+1<len(ts) else 0
    x0=np.clip((x-np.sqrt(1-bar[t])*eps)/np.sqrt(bar[t]),-1,1);x=np.sqrt(bar[previous])*x0+np.sqrt(1-bar[previous])*eps
    self.assertEqual(previous,ref['trace'][i+1]['t']);np.testing.assert_allclose(x,ref['trace'][i+1]['pixels'],atol=1e-9,rtol=0)
 def test_05_all359_diagnostics_identity_baselines_confusion_and_known_names(self):
  raw,y,fit,diag=m.source();x=torch.tensor(raw.reshape(-1,64),dtype=torch.float64)/16;clean=2*x-1;labels=torch.tensor(y);d=reload(m.Denoiser,'denoiser');a=reload(m.Alignment,'alignment');_,bar=m.schedule();rng=torch.Generator().manual_seed(282)
  with torch.no_grad():
   scores=a.images(x[diag])@a.texts(torch.arange(10)).T;pred=scores.argmax(-1);conf=np.zeros((10,10),dtype=int);np.add.at(conf,(y[diag],pred.numpy()),1);np.testing.assert_array_equal(conf,lab['report']['alignment_confusion']);self.assertEqual(int(conf.trace()),344);self.assertAlmostEqual((pred==labels[diag]).double().mean().item(),lab['report']['alignment_top1'],places=14)
   for ref in lab['report']['diagnostic']:
    t=ref['t'];ts=torch.full((359,),t,dtype=torch.long);eps=torch.randn(359,64,generator=rng,dtype=torch.float64);xt=m.corrupt(clean[diag],eps,ts,bar);prediction=d(xt,ts,labels[diag]);x0=((xt-(1-bar[t]).sqrt()*prediction)/bar[t].sqrt()).clamp(-1,1)
    for key,value in [('noise_mse',(prediction-eps).square().mean()),('zero_noise_baseline',eps.square().mean()),('identity_noise_baseline',(xt-eps).square().mean()),('clipped_x0_unit_mse',((x0+1)/2-x[diag]).square().mean())]:self.assertAlmostEqual(value.item(),ref[key],places=12)
 def test_06_multi_positive_gradients_temperature_and_cfg_boundaries(self):
  labels=torch.tensor([0,0,1,1]);logits=torch.zeros(4,4,dtype=torch.float64,requires_grad=True);loss=m.multipositive_loss(logits,labels);self.assertAlmostEqual(loss.item(),np.log(2),places=14);loss.backward();self.assertTrue(torch.isfinite(logits.grad).all());self.assertLess(logits.grad[0,1],0);self.assertGreater(logits.grad[0,2],0)
  self.assertEqual(m.multipositive_loss(logits,torch.zeros(4,dtype=torch.long)).item(),0)
  for temp in [.05,.1,.5,1.]:
   scores=np.array(lab['samples'][0]['cosines']);e=np.exp((scores-scores.max())/temp);p=e/e.sum();self.assertEqual(p.argmax(),scores.argmax());self.assertAlmostEqual(p.sum(),1)
  r=lab['samples'][0]['references'][0];u=np.array(r['null']);c=np.array(r['conditional']);np.testing.assert_allclose(u+0*(c-u),u);np.testing.assert_allclose(u+1*(c-u),c)
 def test_07_retrain_exact_export_rng_and_threads(self):
  state=torch.random.get_rng_state().clone();threads=torch.get_num_threads();actual=m.analyse();self.assertEqual(actual,lab);self.assertTrue(torch.equal(state,torch.random.get_rng_state()));self.assertEqual(threads,torch.get_num_threads())
 def test_08_external_cwd_cli_no_writes_and_trusted_checkpoint_reload(self):
  before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as directory:
   out=Path(directory)/'export';subprocess.run([sys.executable,str(DATA/'diffusion_workflow.py'),'--artifact-dir',str(out)],cwd=directory,stdout=subprocess.DEVNULL,check=True)
   for name,digest in json.loads((out/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((out/name).read_bytes()).hexdigest(),digest)
   for name,cls in [('denoiser',m.Denoiser),('alignment',m.Alignment)]:
    model=cls();model.load_state_dict(torch.load(out/f'{name}.pt',weights_only=True));self.assertEqual(m.weights(model),lab['weights'][name])
  self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

if __name__=='__main__':
 os.chdir(ROOT);snippets=0
 for lesson in chapter['lessons']:
  for b in lesson['blocks']:
   if b['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),{})
    snippets+=1
 for e in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(e['solution'],e['id'],'exec'),scope)
  assert abs(scope['result']-e['expected'])<1e-9,e['id']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(QA));assert result.wasSuccessful()
 report=dict(chapter=28,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True)
 (ROOT/'build/chapter-28-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
