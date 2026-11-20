"""Chapter22: bounded byte-level language-model mechanics on original Alice text.

Original Gutenberg source/notices retained. This small decoder is not an LLM.
"""
# %% Source chapters, byte blocks and training-only BPE demonstration
from pathlib import Path
import argparse,collections,hashlib,json,math,platform,re
import numpy as np
import torch
from torch import nn
DATA=Path(__file__).resolve().parent
HASH='01b38ea4c710a84bc18d0bd41271a5a1a92b94e97b2812f4dece97d4a694725e'
PAD,BOS,EOS,VOCAB,CONTEXT=256,257,258,259,32

def load_source(path):
    raw=Path(path).read_bytes()
    if hashlib.sha256(raw).hexdigest()!=HASH:raise ValueError('Original Gutenberg ebook11 bytes required')
    text=raw.decode('utf-8-sig').replace('\r\n','\n')
    end=text.index('*** END OF THE PROJECT GUTENBERG EBOOK')
    matches=list(re.finditer(r'^CHAPTER ([IVX]+)\.\s*$',text[:end],flags=re.MULTILINE))
    if len(matches)!=12:raise ValueError('Twelve actual source chapter headings')
    documents=[text[m.end():matches[i+1].start() if i<11 else end].strip() for i,m in enumerate(matches)]
    if any(len(d.encode('utf-8'))<4096 for d in documents):raise ValueError('Expected unabridged chapter bodies')
    return documents

def merge_pair(tokens,pair,new_id):
    out=[];i=0
    while i<len(tokens):
        if i+1<len(tokens) and (tokens[i],tokens[i+1])==tuple(pair):out.append(new_id);i+=2
        else:out.append(tokens[i]);i+=1
    return out

def train_bpe(chunks,budget=16):
    sequences=[list(s) for s in chunks];merges=[]
    for index in range(budget):
        counts=collections.Counter((a,b) for s in sequences for a,b in zip(s,s[1:]))
        if not counts:break
        pair=min(counts,key=lambda p:(-counts[p],p));new_id=259+index
        merges.append({'pair':list(pair),'id':new_id,'count':counts[pair]})
        sequences=[merge_pair(s,pair,new_id) for s in sequences]
    return merges

def bpe_encode(text,merges):
    ids=list(text.encode('utf-8'))
    for m in merges:ids=merge_pair(ids,m['pair'],m['id'])
    return ids

def vocabulary(merges):
    pieces={i:bytes([i]) for i in range(256)}
    for m in merges:pieces[m['id']]=pieces[m['pair'][0]]+pieces[m['pair'][1]]
    return pieces

def blocks(documents,chapter_ids):
    rows=[]
    for chapter in chapter_ids:
        ids=[BOS]+list(documents[chapter-1].encode('utf-8'))+[EOS]
        starts=list(range(0,len(ids)-1,32));chosen=starts[:63]+[starts[-1]]
        if len(set(chosen))!=64:raise ValueError('Declared64 distinct source blocks')
        for start in chosen:
            x=ids[start:start+32];y=ids[start+1:start+33]
            x=x+[PAD]*(32-len(x));y=y+[PAD]*(32-len(y))
            rows.append({'source_chapter':chapter,'start':start,'x':x,'y':y})
    return torch.tensor([r['x'] for r in rows]),torch.tensor([r['y'] for r in rows]),rows

# %% Tiny causal decoder, stable byte objective and explicit decoding
def positions():
    p=torch.arange(CONTEXT,dtype=torch.float64)[:,None];f=torch.exp(torch.arange(0,8,2,dtype=torch.float64)*(-math.log(10000.)/8));pe=torch.zeros(CONTEXT,8,dtype=torch.float64);pe[:,0::2]=torch.sin(p*f);pe[:,1::2]=torch.cos(p*f);return pe

class ByteDecoder(nn.Module):
    def __init__(self):
        super().__init__();self.embedding=nn.Embedding(VOCAB,8,padding_idx=PAD,dtype=torch.float64)
        self.norm1=nn.LayerNorm(8,eps=1e-5,dtype=torch.float64);self.attn=nn.MultiheadAttention(8,2,batch_first=True,dropout=0.,dtype=torch.float64)
        self.norm2=nn.LayerNorm(8,eps=1e-5,dtype=torch.float64);self.ff1=nn.Linear(8,16,dtype=torch.float64);self.ff2=nn.Linear(16,8,dtype=torch.float64)
        self.final_norm=nn.LayerNorm(8,eps=1e-5,dtype=torch.float64);self.head=nn.Linear(8,VOCAB,dtype=torch.float64);self.register_buffer('position',positions())
    def inspect(self,ids,causal=True):
        if ids.ndim!=2 or not 1<=ids.shape[1]<=CONTEXT or ids.dtype!=torch.long or ((ids<0)|(ids>=VOCAB)).any() or (ids[:,0]==PAD).any():raise ValueError('Token IDs[B,T],T1..32,nonpad first key')
        T=ids.shape[1];x=self.embedding(ids)+self.position[:T];n=self.norm1(x)
        blocked=torch.ones(T,T,dtype=torch.bool).triu(1) if causal else torch.zeros(T,T,dtype=torch.bool)
        out,w=self.attn(n,n,n,attn_mask=blocked,key_padding_mask=ids.eq(PAD),need_weights=True,average_attn_weights=False)
        r1=x+out;n2=self.norm2(r1);hidden=self.ff1(n2).relu();ff=self.ff2(hidden);state=r1+ff;normalized=self.final_norm(state);logits=self.head(normalized)
        return {'embedding':x,'norm1':n,'attention':out,'weights':w,'residual1':r1,'norm2':n2,'ff_hidden':hidden,'ff_output':ff,'state':state,'normalized':normalized,'logits':logits}
    def forward(self,ids):return self.inspect(ids)['logits']

def predict_logits(logits):
    out=logits.clone();out[...,PAD]=-torch.inf;out[...,BOS]=-torch.inf;return out

def token_loss(logits,target):
    if logits.shape[:-1]!=target.shape or logits.shape[-1]!=VOCAB or not torch.isfinite(logits).all() or target.dtype!=torch.long or target.eq(BOS).any() or ((target<0)|(target>=VOCAB)).any() or not target.ne(PAD).any():raise ValueError('Finite raw logits and aligned next-token targets with a nonempty valid mask')
    return nn.functional.cross_entropy(predict_logits(logits).reshape(-1,VOCAB),target.reshape(-1),ignore_index=PAD)

def distribution(logits,temperature=1.,top_k=0,top_p=1.):
    scores=np.asarray(logits,dtype=float)
    if scores.shape!=(VOCAB,) or not np.isfinite(scores).all() or not np.isfinite(temperature) or temperature<=0 or not isinstance(top_k,int) or isinstance(top_k,bool) or top_k not in [0,5,20] or not np.isfinite(top_p) or not 0<top_p<=1:raise ValueError('Finite259 logits,temperature>0,k0/5/20,p(0,1]')
    allowed=[i for i in range(VOCAB) if i not in [PAD,BOS]];order=sorted(allowed,key=lambda i:(-scores[i],i));keep=order[:top_k] if top_k else order
    shifted=np.array([scores[i] for i in keep]);shifted=(shifted-shifted.max())/temperature;weights=np.exp(shifted);weights/=weights.sum()
    count=len(keep)
    if top_p<1:count=min(len(keep),int(np.searchsorted(np.cumsum(weights),top_p,side='left'))+1)
    result=np.zeros(VOCAB);result[keep[:count]]=weights[:count]/weights[:count].sum();return result

def uniform_draws(seed=22,count=8):
    if not isinstance(seed,int) or isinstance(seed,bool) or not 0<=seed<=0xffffffff or not isinstance(count,int) or isinstance(count,bool) or not 1<=count<=32:raise ValueError('32-bit seed and count1..32')
    state=seed;out=[]
    for _ in range(count):state=(1664525*state+1013904223)&0xffffffff;out.append((state+.5)/4294967296.)
    return out

def choose(probability,u):
    probability=np.asarray(probability,dtype=float)
    if probability.shape!=(VOCAB,) or not np.isfinite(probability).all() or (probability<0).any() or abs(probability.sum()-1)>1e-10 or not np.isfinite(u) or not 0<=u<1:raise ValueError('Probability259 and uniform draw in[0,1)')
    total=0.
    for i,p in enumerate(probability):
        total+=p
        if u<total:return i
    return int(np.flatnonzero(np.asarray(probability)>0)[-1])

def generate(model,prefix,mode='sample',temperature=1.,top_k=0,top_p=1.):
    ids=list(prefix);new=[]
    if mode not in ['sample','greedy'] or not ids or len(ids)>24 or any(not isinstance(i,int) or i<0 or i>=VOCAB or i==PAD for i in ids):raise ValueError('Valid prefix<=24,mode sample/greedy')
    model.eval()
    with torch.no_grad():
        for u in uniform_draws():
            logits=model(torch.tensor([ids]))[0,-1].numpy();p=distribution(logits,temperature,top_k,top_p)
            token=int(np.argmax(p)) if mode=='greedy' else choose(p,u);new.append(token);ids.append(token)
            if token==EOS:break
    return new

# %% Fixed corpus roles, model fit, diagnostic held-chapter evaluation and references
def analyse_source(path,artifact_dir=None):
    documents=load_source(path);X,Y,training=blocks(documents,range(1,9));V,VY,validation=blocks(documents,[9,10]);T,TY,testing=blocks(documents,[11,12])
    torch.manual_seed(22);model=ByteDecoder();assert sum(p.numel() for p in model.parameters())==5019
    optimizer=torch.optim.AdamW(model.parameters(),lr=.01,weight_decay=.01,foreach=False);rng=torch.Generator().manual_seed(220);history=[]
    def evaluate(x,y):
        model.eval()
        with torch.no_grad():return token_loss(model(x),y).item()
    for epoch in range(11):
        history.append({'epoch':epoch,'train_nll':evaluate(X,Y),'validation_nll':evaluate(V,VY)})
        if epoch==10:break
        model.train()
        for ids in torch.randperm(len(X),generator=rng).split(64):
            optimizer.zero_grad(set_to_none=True);loss=token_loss(model(X[ids]),Y[ids]);loss.backward();nn.utils.clip_grad_norm_(model.parameters(),1.,error_if_nonfinite=True);optimizer.step()
    counts=np.ones(VOCAB);counts[PAD]=counts[BOS]=0
    for token in Y[Y.ne(PAD)].tolist():counts[token]+=1
    unigram=counts/counts.sum()
    def baseline(y):return float(-np.log(unigram[y[y.ne(PAD)].numpy()]).mean())
    test_nll=evaluate(T,TY);weights={k:v.detach().tolist() for k,v in model.state_dict().items()}
    merges=train_bpe([d.encode('utf-8')[:256] for d in documents[:8]],16)
    samples=[]
    for chapter in [1,3,9]:
        prefix_text=documents[chapter-1][:16];prefix=[BOS]+list(prefix_text.encode('utf-8'));target=documents[chapter-1][16:].encode('utf-8')[0]
        refs=[]
        for causal in [True,False]:
            with torch.no_grad():trace=model.inspect(torch.tensor([prefix]),causal)
            refs.append({'causal':causal,'trace':{k:v[0].tolist() for k,v in trace.items()}})
        cases=[]
        for temp,k,p,mode in [(1.,0,1.,'greedy'),(1.,0,1.,'sample'),(.7,20,.9,'sample')]:cases.append({'temperature':temp,'top_k':k,'top_p':p,'mode':mode,'ids':generate(model,prefix,mode,temp,k,p)})
        samples.append({'source_chapter':chapter,'role':'fit' if chapter<9 else 'validation','text':prefix_text,'ids':prefix,'targets':prefix[1:]+[target],'references':refs,'generation':cases})
    examples=[]
    for chapter in [1,3,9]:
        doc=documents[chapter-1];start=doc.find('“');start=max(0,start);text=doc[start:start+48]
        examples.append({'source_chapter':chapter,'offset_char':start,'text':text,'bytes':list(text.encode('utf-8')),'bpe_ids':bpe_encode(text,merges)})
    role_counts={name:{'chapters':list(ids),'blocks':len(rows),'targets':int(y.ne(PAD).sum()),'eos_targets':int(y.eq(EOS).sum())} for name,ids,rows,y in [('fit',range(1,9),training,Y),('validation',[9,10],validation,VY),('test',[11,12],testing,TY)]}
    report={'source':"Alice's Adventures in Wonderland, Lewis Carroll, Project Gutenberg ebook11",'sha256':HASH,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'dtype':'float64','device':'cpu','parameters':5019,'model_vocabulary':259,'allowed_output_ids':257,'context':32,'roles':role_counts,'seed':22,'updates':80,'batch_size':64,'epochs':10,'initial_train_nll':history[0]['train_nll'],'final_train_nll':history[-1]['train_nll'],'validation':{'model_nll':history[-1]['validation_nll'],'unigram_nll':baseline(VY)},'test':{'model_nll':test_nll,'unigram_nll':baseline(TY),'model_perplexity':math.exp(test_nll)},'bpe_merges':16,'assumptions':['Original full Gutenberg file retained with source notices; parser normalizes CRLF to LF and excludes header/TOC/license trailer from modeling.','Source chapters1-8 fit,9-10 diagnostic validation,11-12 terminal test; same book/author,public text,not independent-domain or contamination-proof evaluation.','Per chapter only first63 nonoverlap32-token blocks plus final block; omitted middle is never stitched; EOS retained and PAD targets ignored.','Fixed one-block d8,heads2,FF16 pre-norm decoder with final LayerNorm,unshared embedding/head,sinusoidal positions0..31,dropout0;5019 parameters,not a large language model.','Seed22,AdamW.01/decay.01,clip1,batch64,10 epochs/80 updates,shuffle generator220;no hyperparameter/seed/best-epoch search.','Model tokenizer is raw UTF8 bytes plus PAD256/BOS257/EOS258;PAD/BOS logits blocked;EOS may be predicted.','BPE demonstration separately learns16 merges from first256 bytes of each fit chapter;not the model tokenizer or a production tokenizer.','All NLL/perplexity comparisons share byte/EOS vocabulary and target mask;word/BPE perplexities are not directly comparable.','Sampling uses declared shared 32-bit LCG uniforms for reproducible Dart/Python mechanics;not cryptographic or backend-RNG equivalence.','Generated continuations may be invalid UTF8 or nonsense;replacement decoding is explicit,not English/Bangla competency or factual-answer evidence.','Final test outcomes now published;reruns are audits,not fresh confirmation;no instruction tuning,preference optimization,RAG or pretrained LLM claim.']}
    asset={'source':report['source'],'sha256':HASH,'dtype':'float64','parameters':5019,'context':32,'vocab':259,'width':8,'heads':2,'ff_width':16,'special_ids':{'pad':PAD,'bos':BOS,'eos':EOS},'weights':weights,'merges':merges,'examples':examples,'samples':samples,'history':history,'roles':role_counts,'unigram':unigram.tolist()}
    if artifact_dir:
        folder=Path(artifact_dir);folder.mkdir(parents=True,exist_ok=True);torch.save(model.state_dict(),folder/'byte_decoder.pt')
        for name,value in {'schema.json':{'vocab':259,'special_ids':asset['special_ids'],'context':32,'parameters':5019,'tokenizer':'UTF8 bytes','source_sha256':HASH},'tokenizer_demo.json':merges,'model_card.json':report,'golden.json':samples}.items():(folder/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8')
        (folder/'checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.iterdir()) if p.is_file() and p.name!='checksums.json'},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    threads=torch.get_num_threads()
    try:
        torch.set_num_threads(1)
        with torch.random.fork_rng(devices=[]):return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(threads)

# %% Import-safe CLI with explicit derived-asset writes
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path);args=parser.parse_args(argv)
    report,asset=run_analysis(DATA/'pg11.txt',args.artifact_dir)
    if args.write_labs:(DATA/'llm_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report
if __name__=='__main__':main()
