"""Execute all Chapter27 code plus independent source/gradient/artifact checks."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,os,subprocess,sys,tempfile,unittest
import numpy as np
import torch
ROOT=Path(__file__).resolve().parent.parent;DATA=ROOT/'assets/datasets/digits'
spec=importlib.util.spec_from_file_location('generative_qa',DATA/'generative_workflow.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
lab=json.loads((DATA/'generative_lab.json').read_text());chapter=json.loads((ROOT/'assets/content/chapter_27.json').read_text(encoding='utf-8'))
def reload_model(cls,name):
 model=cls();model.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in lab['weights'][name].items()});return model
class QA(unittest.TestCase):
 def test_01_original_bytes_roles_and_real_images(self):
  raw,y,train,diag=m.source();self.assertEqual(hashlib.sha256((DATA/'digits.csv.gz').read_bytes()).hexdigest(),lab['report']['source_sha256']);np.testing.assert_array_equal(train+1,lab['report']['train_rows_1based']);np.testing.assert_array_equal(diag+1,lab['report']['diagnostic_rows_1based'])
  for row in lab['images']:
   i=row['source_row_1based']-1;self.assertIn(i,diag);self.assertEqual(y[i],row['digit']);np.testing.assert_array_equal(raw[i].reshape(64)/16,row['pixels']);self.assertEqual(i,next(i for i in diag if y[i]==row['digit']))
 def test_02_all_frozen_forwards_independent_kl_and_bce(self):
  v=reload_model(m.VAE,'vae');g=reload_model(m.Generator,'generator');d=reload_model(m.Discriminator,'discriminator')
  with torch.no_grad():
   for row in lab['images']:
    x=torch.tensor([row['pixels']],dtype=torch.float64);mu,lv=v.encode(x);logits=v.decode(mu)
    np.testing.assert_allclose(mu[0],row['mu'],atol=1e-13);np.testing.assert_allclose(lv[0],row['logvar'],atol=1e-13);np.testing.assert_allclose(logits[0].sigmoid(),row['reconstruction'],atol=1e-13)
    kl=torch.distributions.kl_divergence(torch.distributions.Normal(mu,(lv/2).exp()),torch.distributions.Normal(torch.zeros_like(mu),torch.ones_like(mu))).sum()
    self.assertAlmostEqual(kl.item(),row['kl'],places=12)
    a=logits.numpy();target=x.numpy();bce=(np.logaddexp(0,a)-target*a).sum();self.assertAlmostEqual(bce,row['bce'],places=12)
   z=torch.tensor([s['z'] for s in lab['samples']],dtype=torch.float64);fake=g(z)
   np.testing.assert_allclose(fake,[s['gan'] for s in lab['samples']],atol=1e-13);np.testing.assert_allclose(v.decode(z).sigmoid(),[s['vae'] for s in lab['samples']],atol=1e-13);np.testing.assert_allclose(d(fake).sigmoid(),[s['d_fake'] for s in lab['samples']],atol=1e-13)
 def test_03_all_diagnostic_metrics_baseline_nearest_and_sample_seed(self):
  raw,y,train,diag=m.source();x=raw.reshape(-1,64)/16;v=reload_model(m.VAE,'vae');g=reload_model(m.Generator,'generator')
  result=m.evaluate(v,torch.tensor(x[diag],dtype=torch.float64));np.testing.assert_allclose(list(result.values()),list(lab['report']['vae_diagnostic'].values()),atol=1e-13)
  self.assertAlmostEqual(((x[diag]-x[train].mean(0))**2).mean(),lab['report']['train_mean_baseline_mse'],places=14)
  z=torch.randn(16,2,generator=torch.Generator().manual_seed(271),dtype=torch.float64);np.testing.assert_array_equal(z,[s['z'] for s in lab['samples']])
  for sample in lab['samples']:
   dist=((x[train]-sample['gan'])**2).mean(1);idx=dist.argmin();self.assertEqual(int(train[idx])+1,sample['nearest_train_row_1based']);self.assertAlmostEqual(dist[idx],sample['nearest_mse'],places=14)
 def test_04_autograd_phase_isolation_and_logit_derivatives(self):
  with torch.random.fork_rng():
   torch.manual_seed(27);g=m.Generator();d=m.Discriminator();z=torch.ones(3,2,dtype=torch.float64)
   torch.nn.functional.softplus(d(g(z).detach())).mean().backward();self.assertTrue(all(p.grad is None for p in g.parameters()));d.zero_grad(set_to_none=True)
   for p in d.parameters():p.requires_grad_(False)
   torch.nn.functional.softplus(-d(g(z))).mean().backward();self.assertTrue(all(p.grad is not None and p.grad.abs().sum()>0 for p in g.parameters()));self.assertTrue(all(p.grad is None for p in d.parameters()))
  for a in [-1000.,-8.,0.,8.,1000.]:
   logit=torch.tensor(a,dtype=torch.float64,requires_grad=True);non=torch.nn.functional.softplus(-logit);mini=-torch.nn.functional.softplus(logit)
   self.assertTrue(torch.isfinite(non));self.assertAlmostEqual(torch.autograd.grad(non,logit,retain_graph=True)[0].item(),logit.sigmoid().item()-1,places=13);self.assertAlmostEqual(torch.autograd.grad(mini,logit)[0].item(),-logit.sigmoid().item(),places=13)
 def test_05_retrain_reproduces_export_and_preserves_rng_threads(self):
  state=torch.random.get_rng_state().clone();threads=torch.get_num_threads()
  actual=m.analyse()
  self.assertTrue(torch.equal(state,torch.random.get_rng_state()));self.assertEqual(threads,torch.get_num_threads());self.assertEqual(actual,lab)
 def test_06_cli_external_cwd_no_mutation_and_trusted_artifact_reload(self):
  before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()}
  with tempfile.TemporaryDirectory() as folder:
   out=Path(folder)/'export';subprocess.run([sys.executable,str(DATA/'generative_workflow.py'),'--artifact-dir',str(out)],cwd=folder,stdout=subprocess.DEVNULL,check=True)
   checks=json.loads((out/'checksums.json').read_text())
   for name,digest in checks.items():self.assertEqual(hashlib.sha256((out/name).read_bytes()).hexdigest(),digest)
   for name,cls in [('vae',m.VAE),('generator',m.Generator),('discriminator',m.Discriminator)]:
    model=cls();model.load_state_dict(torch.load(out/f'{name}.pt',weights_only=True));self.assertEqual(m.weights(model),lab['weights'][name])
  after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};self.assertEqual(before,after)

if __name__=='__main__':
 os.chdir(ROOT)
 snippets=0
 for lesson in chapter['lessons']:
  for block in lesson['blocks']:
   if block['type']=='code':
    with contextlib.redirect_stdout(io.StringIO()):exec(compile(block['body'],lesson['id'],'exec'),{})
    snippets+=1
 for exercise in chapter['exercises']:
  scope={}
  with contextlib.redirect_stdout(io.StringIO()):exec(compile(exercise['solution'],exercise['id'],'exec'),scope)
  assert abs(scope['result']-exercise['expected'])<1e-9,exercise['id']
 suite=unittest.defaultTestLoader.loadTestsFromTestCase(QA);result=unittest.TextTestRunner(verbosity=2).run(suite)
 assert result.wasSuccessful()
 report=dict(chapter=27,walkthroughs=snippets,solutions=len(chapter['exercises']),behavior_checks=result.testsRun,passed=True)
 (ROOT/'build/chapter-27-code-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
