"""Execute Chapter22 and independently verify bytes,causal CE and decoding."""
import contextlib,hashlib,io,json,math,os,runpy,subprocess,sys,tempfile,types,unittest
from pathlib import Path
import numpy as np
import torch
from torch import nn
ROOT=Path(__file__).resolve().parent.parent;os.chdir(ROOT);torch.set_num_threads(1)
chapter=json.loads((ROOT/'assets/content/chapter_22.json').read_text(encoding='utf-8'))
assert [len(chapter[k]) for k in ['lessons','quizzes','exercises','interviews']]==[20,24,10,10]
scopes={};snippets=0
for lesson in chapter['lessons']:
    module=types.ModuleType(lesson['id']);sys.modules[lesson['id']]=module
    for b in lesson['blocks']:
        if b['type']=='code':
            with contextlib.redirect_stdout(io.StringIO()):exec(compile(b['body'],lesson['id'],'exec'),module.__dict__)
            snippets+=1
    scopes[lesson['id']]=module.__dict__
solutions={}
for e in chapter['exercises']:
    compile(e['starter'],e['id'],'exec');scope={}
    with contextlib.redirect_stdout(io.StringIO()):exec(e['solution'],scope)
    assert math.isclose(float(scope['answer']),e['expected'],abs_tol=1e-10),e['id']
    solutions[e['id']]=scope
api=scopes['ch22_experiment'];report,asset=api['report'],api['asset'];DATA=ROOT/'assets/datasets/alice'
def fitted():
    m=api['ByteDecoder']();m.load_state_dict({k:torch.tensor(v,dtype=torch.float64) for k,v in asset['weights'].items()});return m.eval()
def manual(ids,causal=True):
    p={k:np.array(v) for k,v in asset['weights'].items()};T=len(ids)
    def linear(x,k):return x@p[k+'.weight'].T+p[k+'.bias']
    def norm(x,k):return (x-x.mean(-1,keepdims=True))/np.sqrt(x.var(-1,keepdims=True)+1e-5)*p[k+'.weight']+p[k+'.bias']
    x=p['embedding.weight'][ids]+p['position'][:T];n=norm(x,'norm1');Q,K,V=np.split(n@p['attn.in_proj_weight'].T+p['attn.in_proj_bias'],3,-1)
    q,k,v=[a.reshape(T,2,4).transpose(1,0,2) for a in [Q,K,V]];scores=q@k.transpose(0,2,1)/2
    allowed=np.broadcast_to(np.array(ids)[None]!=256,(T,T)).copy()
    if causal:allowed&=np.arange(T)[None]<=np.arange(T)[:,None]
    scores=np.where(allowed[None],scores,-np.inf);ex=np.exp(scores-scores.max(-1,keepdims=True));w=ex/ex.sum(-1,keepdims=True)
    out=linear((w@v).transpose(1,0,2).reshape(T,8),'attn.out_proj');r1=x+out;n2=norm(r1,'norm2');hidden=np.maximum(0,linear(n2,'ff1'));ff=linear(hidden,'ff2');state=r1+ff;normalized=norm(state,'final_norm');logits=linear(normalized,'head')
    return {'embedding':x,'norm1':n,'attention':out,'weights':w,'residual1':r1,'norm2':n2,'ff_hidden':hidden,'ff_output':ff,'state':state,'normalized':normalized,'logits':logits}
class LLMBehaviorTests(unittest.TestCase):
    def test_source_original_bytes_normalization_document_roles_and_exact_blocks(self):
        original=(DATA/'pg11.txt').read_bytes();manifest=json.loads((DATA/'source_manifest.json').read_text());self.assertEqual(hashlib.sha256(original).hexdigest(),manifest['sha256']);self.assertEqual(manifest['sha256'],report['sha256']);self.assertIn(b'Project Gutenberg License',original)
        docs=api['load_source'](DATA/'pg11.txt');self.assertEqual(len(docs),12);self.assertNotIn('*** END OF',docs[-1]);self.assertNotIn('Contents',docs[0][:50])
        for role,chapters in [('fit',range(1,9)),('validation',[9,10]),('test',[11,12])]:
            X,Y,rows=api['blocks'](docs,chapters);self.assertEqual(len(rows),report['roles'][role]['blocks']);self.assertEqual(int(Y.ne(256).sum()),report['roles'][role]['targets']);self.assertEqual(int(Y.eq(258).sum()),len(chapters))
            for r in rows:
                source=[257]+list(docs[r['source_chapter']-1].encode('utf-8'))+[258];start=r['start'];x=source[start:start+32];y=source[start+1:start+33];self.assertEqual(r['x'],x+[256]*(32-len(x)));self.assertEqual(r['y'],y+[256]*(32-len(y)))
        for s in asset['samples']:
            self.assertNotIn(s['source_chapter'],[11,12]);doc=docs[s['source_chapter']-1];self.assertEqual(s['text'],doc[:16]);self.assertEqual(s['targets'],s['ids'][1:]+[doc[16:].encode('utf-8')[0]])
    def test_fit_only_bpe_rank_ties_overlaps_and_unicode_round_trip(self):
        docs=api['load_source'](DATA/'pg11.txt');merges=api['train_bpe']([d.encode('utf-8')[:256] for d in docs[:8]]);self.assertEqual(merges,asset['merges']);pieces=api['vocabulary'](merges)
        for text in ['',*[e['text'] for e in asset['examples']],'বাংলা ’','é','e\u0301','😀']:
            ids=api['bpe_encode'](text,merges);self.assertEqual(b''.join(pieces[i] for i in ids).decode('utf-8'),text)
        self.assertEqual(api['train_bpe']([b'ab',b'cd'],1)[0]['pair'],[97,98]);first=api['train_bpe']([b'aaaa'],1)[0];self.assertEqual(first['count'],3);self.assertEqual(api['merge_pair']([97]*4,[97,97],259),[259,259])
        for e in asset['examples']:
            doc=docs[e['source_chapter']-1];self.assertEqual(e['text'],doc[e['offset_char']:e['offset_char']+48]);self.assertEqual(e['bytes'],list(e['text'].encode('utf-8')));self.assertEqual(e['bpe_ids'],api['bpe_encode'](e['text'],merges))
    def test_all_actual_decoder_intermediates_match_independent_numpy(self):
        m=fitted();self.assertEqual(sum(p.numel() for p in m.parameters()),5019);self.assertEqual(m.position.numel(),256);self.assertEqual(m.embedding.padding_idx,256)
        for s in asset['samples']:
            for ref in s['references']:
                own=manual(s['ids'],ref['causal'])
                with torch.no_grad():actual=m.inspect(torch.tensor([s['ids']]),ref['causal'])
                for key,v in own.items():np.testing.assert_allclose(v,ref['trace'][key],atol=1e-10,rtol=1e-10);np.testing.assert_allclose(v,actual[key][0],atol=1e-10,rtol=1e-10)
    def test_causal_padding_shifted_loss_active_gradient_and_class_suppression(self):
        m=fitted();s=asset['samples'][0];ids=torch.tensor([s['ids']]);targets=torch.tensor([s['targets']]);changed=ids.clone();changed[:,5:]=changed[:,5:].flip(1)
        with torch.no_grad():base=m(ids);other=m(changed);full=m.inspect(ids,False)['logits'];padded=m(torch.cat([ids,torch.full((1,2),256)],1))
        torch.testing.assert_close(base[:,:5],other[:,:5]);torch.testing.assert_close(base[:,-1],full[:,-1]);self.assertGreater((base[:,0]-full[:,0]).abs().max().item(),1e-5);torch.testing.assert_close(base,padded[:,:ids.shape[1]])
        loss=api['token_loss'](m(ids),targets);p=api['distribution'](base[0,-1].numpy());self.assertEqual(p[256]+p[257],0)
        extended=api['token_loss'](padded,torch.cat([targets,torch.full((1,2),256)],1));torch.testing.assert_close(loss.detach(),extended)
        loss.backward();self.assertTrue(torch.equal(m.head.weight.grad[256:258],torch.zeros_like(m.head.weight.grad[256:258])));self.assertGreater(m.head.weight.grad[258].norm().item(),0)
        param=m.attn.in_proj_weight;index=np.unravel_index(param.grad.abs().argmax().item(),param.shape);old=param[index].item();analytic=param.grad[index].item();self.assertGreater(abs(analytic),1e-7);eps=1e-6
        with torch.no_grad():param[index]=old+eps;hi=api['token_loss'](m(ids),targets).item();param[index]=old-eps;lo=api['token_loss'](m(ids),targets).item();param[index]=old
        self.assertAlmostEqual(analytic,(hi-lo)/(2*eps),places=6)
        for bad in [torch.full_like(targets,256),torch.full_like(targets,257)]:
            with self.assertRaises(ValueError):api['token_loss'](base,bad)
    def test_distribution_filters_cdf_generation_parity_and_eos_stop(self):
        m=fitted();equal=np.full(259,1000.);equal[256:258]=1e9;p=api['distribution'](equal);self.assertEqual(p[256]+p[257],0);self.assertAlmostEqual(p.sum(),1);np.testing.assert_allclose(p[:256],1/257)
        k=api['distribution'](equal,top_k=5);self.assertEqual(np.flatnonzero(k).tolist(),[0,1,2,3,4]);self.assertEqual(np.count_nonzero(api['distribution'](equal,top_k=5,top_p=.6)),3)
        example=np.zeros(259);example[:3]=[.2,.3,.5];self.assertEqual([api['choose'](example,u) for u in [0,.2,.5,.999]],[0,1,2,2])
        for s in asset['samples']:
            for r in s['generation']:self.assertEqual(api['generate'](m,s['ids'],r['mode'],r['temperature'],r['top_k'],r['top_p']),r['ids'])
            self.assertEqual(api['generate'](m,s['ids'],'greedy',.7,20,.9),api['generate'](m,s['ids'],'greedy'))
        with torch.no_grad():m.head.bias.fill_(-10000);m.head.bias[258]=10000
        self.assertEqual(api['generate'](m,asset['samples'][0]['ids']),[258])
        for kwargs in [{'temperature':0},{'top_k':1},{'top_p':float('nan')}]:
            with self.assertRaises(ValueError):api['distribution'](equal,**kwargs)
        with self.assertRaises(ValueError):api['choose'](np.zeros(259),.3)
    def test_token_weighted_losses_fit_only_unigram_and_perplexity_units(self):
        m=fitted();docs=api['load_source'](DATA/'pg11.txt');_,fitY,_=api['blocks'](docs,range(1,9));counts=np.ones(259);counts[256:258]=0
        for token in fitY[fitY.ne(256)].tolist():counts[token]+=1
        unigram=counts/counts.sum();np.testing.assert_array_equal(unigram,asset['unigram'])
        for role,chapters in [('validation',[9,10]),('test',[11,12])]:
            X,Y,_=api['blocks'](docs,chapters)
            with torch.no_grad():logits=api['predict_logits'](m(X));loss=api['token_loss'](m(X),Y).item();logp=logits.log_softmax(-1);valid=Y.ne(256);manual_loss=-logp.gather(-1,Y[...,None]).squeeze(-1)[valid].mean().item()
            self.assertAlmostEqual(loss,manual_loss,places=12);self.assertAlmostEqual(loss,report[role]['model_nll'],places=12);self.assertAlmostEqual(-np.log(unigram[Y[valid].numpy()]).mean(),report[role]['unigram_nll'],places=12)
        self.assertAlmostEqual(math.exp(report['test']['model_nll']),report['test']['model_perplexity'],places=12);self.assertLess(report['test']['model_nll'],report['test']['unigram_nll'])
    def test_reproducible_artifacts_schema_model_card_and_trusted_reload(self):
        self.assertEqual(asset,json.loads((DATA/'llm_lab.json').read_text()));self.assertEqual(len(asset['history']),11);self.assertLess(report['final_train_nll'],report['initial_train_nll'])
        with tempfile.TemporaryDirectory() as temp:
            own,own_asset=api['run_analysis'](DATA/'pg11.txt',Path(temp));self.assertEqual(own,report);self.assertEqual(own_asset,asset)
            for name,digest in json.loads((Path(temp)/'checksums.json').read_text()).items():self.assertEqual(hashlib.sha256((Path(temp)/name).read_bytes()).hexdigest(),digest)
            m=api['ByteDecoder']();m.load_state_dict(torch.load(Path(temp)/'byte_decoder.pt',weights_only=True,map_location='cpu'));self.assertEqual({k:v.detach().tolist() for k,v in m.state_dict().items()},asset['weights']);self.assertEqual(json.loads((Path(temp)/'schema.json').read_text())['tokenizer'],'UTF8 bytes');self.assertEqual(json.loads((Path(temp)/'model_card.json').read_text()),report)
    def test_import_safe_external_cli_rng_threads_and_unchanged_assets(self):
        script=DATA/'llm_workflow.py';before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()};out=io.StringIO()
        with contextlib.redirect_stdout(out):module=runpy.run_path(str(script))
        self.assertEqual(out.getvalue(),'');rng=torch.get_rng_state().clone();torch.set_num_threads(2)
        try:own,own_asset=module['run_analysis'](DATA/'pg11.txt');self.assertEqual(torch.get_num_threads(),2)
        finally:torch.set_num_threads(1)
        torch.testing.assert_close(rng,torch.get_rng_state());self.assertEqual(own,report);self.assertEqual(own_asset,asset)
        with tempfile.TemporaryDirectory() as temp:
            dest=Path(temp)/'report.json';r=subprocess.run([sys.executable,str(script),'--output',str(dest)],cwd=temp,capture_output=True,text=True,check=True,timeout=180)
            self.assertEqual(json.loads(r.stdout),report);self.assertEqual(json.loads(dest.read_text()),report);self.assertFalse(dest.with_name(dest.name+'.tmp').exists())
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})
if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2,stream=sys.stdout).run(unittest.defaultTestLoader.loadTestsFromTestCase(LLMBehaviorTests))
    if not result.wasSuccessful():raise SystemExit(1)
    (ROOT/'build/chapter-22-python-verification.json').write_text(json.dumps({'snippets':snippets,'solutions':len(solutions),'behavior_tests':result.testsRun,'report':report},indent=2,allow_nan=False)+'\n',encoding='utf-8')
    print(f'PASS: {snippets} snippets, {len(solutions)} solutions, {result.testsRun} behavior tests; Unicode,causal decoder and exact sampling verified.')
