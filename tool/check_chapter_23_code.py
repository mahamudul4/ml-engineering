"""Execute chapter code and independently audit SciFact retrieval evidence offline."""
from pathlib import Path
from collections import Counter
import contextlib,csv,hashlib,importlib.util,io,json,math,re,subprocess,sys,tempfile,unittest
import numpy as np
from scipy.sparse import csr_matrix
import torch
import torch.nn.functional as F
from threadpoolctl import threadpool_limits,threadpool_info

ROOT=Path(__file__).resolve().parent.parent
DATA=ROOT/'assets/datasets/scifact'
spec=importlib.util.spec_from_file_location('retrieval_qa',DATA/'retrieval_workflow.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
chapter=json.loads((ROOT/'assets/content/chapter_23.json').read_text(encoding='utf-8'))
bundle=json.loads((DATA/'retrieval_index.json').read_text())
lab=json.loads((DATA/'retrieval_lab.json').read_text())
docs,queries,roles=m.read_data()
vocab={t:i for i,t in enumerate(bundle['vocabulary'])}
idf=np.array(bundle['idf']);components=np.array(bundle['components'])
ids=[d['id'] for d in bundle['documents']];numeric=np.array(list(map(int,ids)))
dense=np.array([d['dense'] for d in bundle['documents']])
rows=[];columns=[];values=[]
for i,d in enumerate(bundle['documents']):
    rows.extend([i]*len(d['indices']));columns.extend(d['indices']);values.extend(d['values'])
sparse=csr_matrix((values,(rows,columns)),shape=(5183,4096))

def normalized(x):
    norm=np.linalg.norm(x)
    return x/norm if norm else x.copy()
def encode(text):
    counts=Counter(t.lower() for t in re.findall(r'[A-Za-z0-9]+',text))
    x=np.zeros(4096)
    for term,count in counts.items():
        if term in vocab:x[vocab[term]]=(1+math.log(count))*idf[vocab[term]]
    x=normalized(x);raw=x@components.T
    return x,raw,normalized(raw)
def top(scores,k=100,positive=False):
    order=np.lexsort((numeric,-scores))
    if positive:order=order[scores[order]>0]
    return [(ids[i],float(scores[i])) for i in order[:k]]
def fusion(a,b):
    sums={}
    for hits in [a,b]:
        for rank,(doc,_) in enumerate(hits,1):sums[doc]=sums.get(doc,0)+1/(60+rank)
    return sorted(sums.items(),key=lambda p:(-p[1],int(p[0])))
def metric(hits,relevant,k):
    ranks=[i for i,(d,_) in enumerate(hits[:k],1) if d in relevant]
    ideal=sum(1/math.log2(i+1) for i in range(1,min(k,len(relevant))+1))
    return {'recall':len(ranks)/len(relevant),'mrr':1/min(ranks) if ranks else 0.,
            'ndcg':sum(1/math.log2(i+1) for i in ranks)/ideal}

class RetrievalQA(unittest.TestCase):
    def test_01_source_roles_and_full_corpus_tfidf(self):
        self.assertEqual([len(docs),len(queries),len(roles['train']),len(roles['test'])],[5183,1109,809,300])
        self.assertFalse(roles['train'].keys()&roles['test'].keys())
        manifest=json.loads((DATA/'source_manifest.json').read_text())
        self.assertEqual(hashlib.sha256((DATA/'source_manifest.json').read_bytes()).hexdigest(),lab['source_manifest_sha256'])
        for name,meta in manifest['files'].items():
            self.assertEqual(hashlib.sha256((DATA/name).read_bytes()).hexdigest(),meta['sha256'])
        counts=[Counter(t.lower() for t in re.findall(r'[A-Za-z0-9]+',d['title']+' '+d['text'])) for d in docs]
        df=Counter(t for c in counts for t in c)
        expected_idf=np.array([1+math.log(5184/(df[t]+1)) for t in bundle['vocabulary']])
        np.testing.assert_allclose(idf,expected_idf,atol=1e-14,rtol=0)
        self.assertTrue(all(df[t]>=2 for t in vocab))
        for counts,row in zip(counts,bundle['documents']):
            expected={vocab[t]:(1+math.log(c))*idf[vocab[t]] for t,c in counts.items() if t in vocab}
            norm=math.sqrt(sum(v*v for v in expected.values()))
            self.assertEqual(set(row['indices']),set(expected))
            np.testing.assert_allclose(row['values'],[expected[i]/norm for i in row['indices']],atol=2e-14,rtol=0)
        raw=sparse@components.T
        norms=np.linalg.norm(raw,axis=1,keepdims=True)
        np.testing.assert_allclose(raw/norms,dense,atol=1e-12,rtol=0)

    def test_02_all_query_intermediates_and_complete_rankings(self):
        with threadpool_limits(1):
            for sample in lab['samples']:
                x,raw,unit=encode(sample['text'])
                expected=np.zeros(4096);expected[sample['sparse']['indices']]=sample['sparse']['values']
                np.testing.assert_allclose(x,expected,atol=1e-12)
                np.testing.assert_allclose(raw,sample['raw'],atol=1e-12)
                np.testing.assert_allclose(unit,sample['unit'],atol=1e-12)
                lexical=top(np.asarray(sparse@x).ravel(),positive=True)
                latent=top(dense@unit)
                for method,hits in [('tfidf',lexical),('lsa',latent),('hybrid',fusion(lexical,latent))]:
                    self.assertEqual([d for d,_ in hits[:10]],[d for d,_ in sample['rankings'][method]])
                    np.testing.assert_allclose([s for _,s in hits[:10]],[s for _,s in sample['rankings'][method]],atol=1e-12)
                self.assertEqual([d for d,_ in fusion(lexical[:5],latent[:5])[:10]],[d for d,_ in sample['depth5_hybrid']])

    def test_03_independent_all_1109_query_macro_metrics(self):
        with threadpool_limits(1):
            for role,labels in roles.items():
                qids=sorted(labels,key=int)
                encoded=[encode(queries[q]) for q in qids]
                lexical_scores=sparse@np.array([x[0] for x in encoded]).T
                dense_scores=dense@np.array([x[2] for x in encoded]).T
                collected={method:{k:[] for k in [5,10]} for method in ['tfidf','lsa','hybrid']}
                for i,qid in enumerate(qids):
                    lexical=top(lexical_scores[:,i],positive=True)
                    latent=top(dense_scores[:,i])
                    for name,hits in [('tfidf',lexical),('lsa',latent),('hybrid',fusion(lexical,latent))]:
                        for k in [5,10]:collected[name][k].append(metric(hits,labels[qid],k))
                for name,cutoffs in collected.items():
                    for k,results in cutoffs.items():
                        expected=lab['report']['evaluation'][role]['methods'][name][str(k)]
                        for key in ['recall','mrr','ndcg']:
                            self.assertAlmostEqual(np.mean([r[key] for r in results]),expected[key],places=13)

    def test_04_neural_math_padding_and_nonzero_gradient(self):
        h=torch.tensor([[1.,2.],[3.,4.],[99.,99.]],dtype=torch.float64)
        mask=torch.tensor([1.,1.,0.],dtype=torch.float64)
        pooled=(h*mask[:,None]).sum(0)/mask.sum()
        torch.testing.assert_close(pooled,torch.tensor([2.,3.],dtype=torch.float64))
        q=torch.tensor([[1.,.2],[.1,.8]],dtype=torch.float64,requires_grad=True)
        d=torch.eye(2,dtype=torch.float64)
        def objective(x):return F.cross_entropy(F.normalize(x,dim=1)@d.T/.2,torch.arange(2))
        loss=objective(q);loss.backward();analytic=q.grad[0,1].item()
        plus=q.detach().clone();minus=plus.clone();plus[0,1]+=1e-6;minus[0,1]-=1e-6
        numerical=(objective(plus)-objective(minus)).item()/2e-6
        self.assertGreater(abs(analytic),1e-6);self.assertAlmostEqual(analytic,numerical,places=8)

    def test_05_rank_fusion_filters_zero_and_invalid_contracts(self):
        self.assertEqual(m.tokens('Cell-β বাংলা PrP 42'),['cell','prp','42'])
        self.assertAlmostEqual(m.cosine([3,4],[4,3]),.96)
        self.assertEqual(m.cosine([0,0],[4,3]),0)
        self.assertEqual(m.rank(['10','2'],[1,1],2),[('2',1.),('10',1.)])
        self.assertEqual(m.fuse([[('7',1.)],[('7',.2)]])[0],('7',2/61))
        for vector in [[],[float('nan')],[float('inf')]]:
            with self.assertRaises(ValueError):m.unit(vector)
        for k in [0,-1,True]:
            with self.assertRaises(ValueError):m.metrics(['1'],{'1'},k)
            with self.assertRaises(ValueError):m.fuse([],k)
        with self.assertRaises(ValueError):m.metrics(['1','1'],{'1'},1)
        with self.assertRaises(ValueError):m.metrics([],set(),1)
        with self.assertRaises(ValueError):m.fuse([[('1',1),('1',2)]])
        self.assertEqual(m.metrics([],{'1'},10),dict(recall=0,mrr=0,ndcg=0))

    def test_06_deterministic_fit_query_metadata_exclusion_and_filters(self):
        state=np.random.get_state()
        threads={(x['internal_api'],x['prefix']):x['num_threads'] for x in threadpool_info()}
        index=m.fit_index(docs)
        np.testing.assert_array_equal(np.random.get_state()[1],state[1])
        self.assertEqual({(x['internal_api'],x['prefix']):x['num_threads'] for x in threadpool_info()},threads)
        np.testing.assert_allclose(index.svd.components_,components,atol=1e-12,rtol=0)
        np.testing.assert_allclose(index.dense,dense,atol=1e-12,rtol=0)
        allowed={d['_id'] for d in docs if 'cell' in m.tokens(d['title'])}
        for method in ['tfidf','lsa','hybrid']:
            hits=index.search(queries['4'],method,allowed=allowed)
            self.assertTrue(all(d in allowed for d,_ in hits))
            self.assertEqual(index.search(queries['4'],method,allowed=set()),[])
            for query in ['', 'বাংলা', 'zzzzzzzzzzzzzzzzzzzzzzzz']:
                self.assertEqual(index.search(query,method),[])
        for args in [dict(k=0),dict(depth=0),dict(method='neural'),dict(allowed={'missing'})]:
            with self.assertRaises(ValueError):index.search(queries['0'],**args)

    def test_07_import_safe_external_cli_artifacts_and_no_asset_rewrite(self):
        before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()}
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder)
            script=DATA/'retrieval_workflow.py'
            run=subprocess.run([sys.executable,str(script),'--output',str(folder/'report.json'),'--artifact-dir',str(folder/'artifacts')],cwd=folder,capture_output=True,text=True,check=True)
            report=json.loads((folder/'report.json').read_text())
            self.assertEqual(report,lab['report'])
            checksums=json.loads((folder/'artifacts/checksums.json').read_text())
            for name,digest in checksums.items():self.assertEqual(hashlib.sha256((folder/'artifacts'/name).read_bytes()).hexdigest(),digest)
            exported=json.loads((folder/'artifacts/index.json').read_text())
            self.assertEqual(exported,bundle)
            with np.load(folder/'artifacts/weights.npz',allow_pickle=False) as weights:
                np.testing.assert_allclose(weights['components'],components,atol=1e-12)
                np.testing.assert_allclose(weights['dense'],dense,atol=1e-12)
            import_run=subprocess.run([sys.executable,'-c',"import importlib.util; s=importlib.util.spec_from_file_location('safe',"+repr(str(script))+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print('imported')"],cwd=folder,capture_output=True,text=True,check=True)
            self.assertEqual(import_run.stdout.strip(),'imported')
            self.assertEqual({p.name for p in folder.iterdir()},{'report.json','artifacts'})
        self.assertEqual(before,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DATA.iterdir() if p.is_file()})

    def test_08_artifact_integrity_metric_boundaries_and_report_limits(self):
        artifact=ROOT/'build/chapter-23-artifacts'
        hashes=json.loads((artifact/'checksums.json').read_text())
        for name,digest in hashes.items():self.assertEqual(hashlib.sha256((artifact/name).read_bytes()).hexdigest(),digest)
        self.assertEqual(json.loads((artifact/'index.json').read_text()),bundle)
        self.assertEqual(json.loads((artifact/'model_card.json').read_text()),lab['report'])
        self.assertEqual(m.metrics(['1','2','3','4'],{'2','4'},4)['mrr'],.5)
        self.assertEqual(m.metrics(['1','2'],{'2','4'},1),dict(recall=0,mrr=0,ndcg=0))
        scores=lab['report']['evaluation']['test']['methods']
        self.assertGreater(scores['tfidf']['10']['recall'],scores['hybrid']['10']['recall'])
        self.assertGreater(scores['hybrid']['10']['recall'],scores['lsa']['10']['recall'])
        self.assertIn('not a pretrained neural semantic encoder',' '.join(lab['report']['limits']))


if __name__=='__main__':
    import os
    os.chdir(ROOT)
    snippets=[b['body'] for lesson in chapter['lessons'] for b in lesson['blocks'] if b['type']=='code']
    for i,code in enumerate(snippets,1):
        with contextlib.redirect_stdout(io.StringIO()):exec(compile(code,f'chapter23_walkthrough_{i}','exec'),{})
    for exercise in chapter['exercises']:
        namespace={}
        with contextlib.redirect_stdout(io.StringIO()):exec(compile(exercise['solution'],exercise['id'],'exec'),namespace)
        np.testing.assert_allclose(namespace['answer'],exercise['expected'],atol=1e-12,rtol=1e-10)
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(RetrievalQA))
    if not result.wasSuccessful():sys.exit(1)
    report={'snippets':len(snippets),'solutions':len(chapter['exercises']),'behavior_tests':result.testsRun,'report':lab['report']}
    (ROOT/'build/chapter-23-python-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:',len(snippets),'walkthroughs,',len(chapter['exercises']),'solutions,',result.testsRun,'behavior tests')
