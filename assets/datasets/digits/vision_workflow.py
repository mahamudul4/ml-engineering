"""Chapter18 offline CNN/transfer mechanics on the sklearn-packaged UCI digits.

The historical UCI test subset is repurposed for educational train/validation;
this is not the original benchmark or a writer-independent evaluation.
"""
# %% Source verification, duplicate-pixel groups and fixed class transfer roles
from pathlib import Path
import argparse,copy,hashlib,json,platform
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F
from sklearn.model_selection import StratifiedGroupKFold
DATA=Path(__file__).resolve().parent
HASH='09f66e6debdee2cd2b5ae59e0d6abbb73fc2b0e0185d2e1957e9ebb51e23aa22'

def load_source(path):
    path=Path(path)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=HASH:raise ValueError('Original bundled digits hash mismatch')
    data=np.loadtxt(path,delimiter=',');raw=data[:,:64];labels=data[:,64].astype(np.int64)
    if data.shape!=(1797,65) or not np.isfinite(data).all() or not np.equal(raw,np.round(raw)).all() or raw.min()<0 or raw.max()>16 or not np.isin(labels,np.arange(10)).all():raise ValueError('8x8 source schema')
    raw=raw.astype(np.uint8).reshape(-1,8,8)
    keys=[hashlib.sha256(x.tobytes()).hexdigest() for x in raw];groups=np.unique(keys,return_inverse=True)[1]
    train,val=next(StratifiedGroupKFold(5,shuffle=True,random_state=18).split(raw,labels,groups))
    roles={'source_train':train[labels[train]<5],'source_validation':val[labels[val]<5],
        'target_train':train[labels[train]>=5],'target_validation':val[labels[val]>=5]}
    assert set(groups[train]).isdisjoint(groups[val])
    return raw,labels,groups,roles

# %% Tiny registered CNN, fixed preprocessing and explicit transfer policy
class DigitCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.backbone=nn.Sequential(nn.Conv2d(1,4,3,padding=1,dtype=torch.float64),nn.ReLU(),nn.MaxPool2d(2),
            nn.Conv2d(4,8,3,padding=1,dtype=torch.float64),nn.ReLU(),nn.MaxPool2d(2))
        self.head=nn.Linear(32,5,dtype=torch.float64)
    def forward(self,x):
        if x.ndim!=4 or tuple(x.shape[1:])!=(1,8,8):raise ValueError('NCHW[B,1,8,8]')
        return self.head(self.backbone(x).flatten(1))

def tensor_images(raw):return torch.tensor(raw[:,None],dtype=torch.float64)/16.

def metrics(model,X,y):
    model.eval()
    with torch.no_grad():
        logits=model(X);prob=logits.softmax(-1);pred=logits.argmax(-1)
        confusion=torch.zeros(5,5,dtype=torch.int64)
        for truth,guess in zip(y,pred):confusion[truth,guess]+=1
        return {'ce':F.cross_entropy(logits,y).item(),'accuracy':(pred==y).double().mean().item(),'confusion':confusion.tolist()}

def train(model,X,y,V,vy,epochs,mode):
    freeze=mode=='frozen'
    for p in model.backbone.parameters():p.requires_grad_(not freeze)
    if mode=='source':opt=torch.optim.AdamW(model.parameters(),lr=.01,weight_decay=.001,foreach=False)
    else:opt=torch.optim.AdamW([{'params':model.head.parameters(),'lr':.01}]+([] if freeze else [{'params':model.backbone.parameters(),'lr':.001}]),weight_decay=.001,foreach=False)
    generator=torch.Generator().manual_seed(180)
    history=[]
    for epoch in range(epochs+1):
        tr=metrics(model,X,y);va=metrics(model,V,vy);history.append({'epoch':epoch,'train_ce':tr['ce'],'validation_ce':va['ce'],'validation_accuracy':va['accuracy']})
        if epoch==epochs:break
        model.train()
        if freeze:model.backbone.eval() # No BN/dropout here; deliberate policy for future extensions.
        for batch in torch.randperm(len(X),generator=generator).split(64):
            opt.zero_grad(set_to_none=True);loss=F.cross_entropy(model(X[batch]),y[batch]);loss.backward();opt.step()
    return history,metrics(model,V,vy)

def weights(model):
    return {'conv1_weight':model.backbone[0].weight.detach().tolist(),'conv1_bias':model.backbone[0].bias.detach().tolist(),
        'conv2_weight':model.backbone[3].weight.detach().tolist(),'conv2_bias':model.backbone[3].bias.detach().tolist(),
        'head_weight':model.head.weight.detach().tolist(),'head_bias':model.head.bias.detach().tolist()}

# %% Actual-image convolution/pooling references and controlled transfer branches
KERNELS={'sobel':[[-1.,0.,1.],[-2.,0.,2.],[-1.,0.,1.]],'average':[[1/9]*3 for _ in range(3)]}
def analyse_source(path,artifact_dir=None):
    raw,labels,groups,roles=load_source(path)
    def role(key,target=False):
        ids=roles[key];return tensor_images(raw[ids]),torch.tensor(labels[ids]-(5 if target else 0),dtype=torch.long)
    S,sy=role('source_train');SV,svy=role('source_validation');T,ty=role('target_train',True);TV,tvy=role('target_validation',True)
    with torch.random.fork_rng(devices=[]):
        torch.manual_seed(18);source=DigitCNN();source_history,source_result=train(source,S,sy,SV,svy,30,'source')
        base=copy.deepcopy(source.backbone.state_dict())
        torch.manual_seed(19);target=DigitCNN();target.backbone.load_state_dict(base)
        initial=copy.deepcopy(target);frozen=copy.deepcopy(target);fine=copy.deepcopy(target)
        frozen_history,frozen_result=train(frozen,T,ty,TV,tvy,20,'frozen')
        fine_history,fine_result=train(fine,T,ty,TV,tvy,20,'finetune')
    frozen_change=max((v-frozen.backbone.state_dict()[k]).abs().max().item() for k,v in base.items())
    fine_change=max((v-fine.backbone.state_dict()[k]).abs().max().item() for k,v in base.items());assert frozen_change==0 and fine_change>0
    ids=[int(next(i for i in roles['target_train'] if labels[i]==digit)) for digit in [5,6,9]]
    samples=[{'source_row_1based':i+1,'digit':int(labels[i]),'pixels':raw[i].tolist()} for i in ids]
    conv_refs=[];pool_refs=[]
    for sample in samples:
        image=tensor_images(raw[[sample['source_row_1based']-1]])
        for name,kernel in KERNELS.items():
            for stride,padding in [(1,0),(1,1),(2,1)]:
                output=F.conv2d(image,torch.tensor(kernel,dtype=torch.float64)[None,None],stride=stride,padding=padding)
                conv_refs.append({'source_row_1based':sample['source_row_1based'],'kernel':name,'stride':stride,'padding':padding,'output':output[0,0].tolist()})
        for shift in [0,1]:
            shifted=torch.zeros_like(image)
            if shift:shifted[:,:,:,1:]=image[:,:,:,:-1]
            else:shifted=image.clone()
            for mode in ['max','average']:
                out=F.max_pool2d(shifted,2) if mode=='max' else F.avg_pool2d(shifted,2)
                pool_refs.append({'source_row_1based':sample['source_row_1based'],'shift_right':shift,'mode':mode,'input':shifted[0,0].tolist(),'output':out[0,0].tolist()})
    branches=[];images=tensor_images(raw[ids])
    for name,m in [('initial',initial),('frozen',frozen),('finetune',fine)]:
        m.eval()
        with torch.no_grad():logits=m(images);features=m.backbone(images)
        branches.append({'name':name,'weights':weights(m),'logits':logits.tolist(),'probabilities':logits.softmax(-1).tolist(),'features':features.tolist()})
    provenance={'source':'UCI Optical Recognition of Handwritten Digits, Alpaydin & Kaynak (1998), CC BY 4.0; sklearn-packaged historical test subset','sha256':HASH}
    counts={k:len(v) for k,v in roles.items()}
    report={**provenance,'versions':{'python':platform.python_version(),'torch':torch.__version__,'numpy':np.__version__},'device':'cpu','dtype':'float64','roles':counts,
        'unique_pixel_groups':len(np.unique(groups)),'source_classes':[0,1,2,3,4],'target_class_to_index':{'5':0,'6':1,'7':2,'8':3,'9':4},
        'parameters':501,'backbone_parameters':336,'head_parameters':165,'source_epochs':30,'target_epochs':20,'source_validation':source_result,
        'frozen_validation':frozen_result,'finetune_validation':fine_result,'frozen_backbone_max_abs':frozen_change,'finetune_backbone_max_abs':fine_change,
        'assumptions':['Historical1797 UCI test-subset images repurposed as diagnostic train/validation, not canonical benchmark evaluation.',
            'Exact-pixel groups kept together with first StratifiedGroupKFold5 seed18; writer IDs unavailable, no writer-disjoint claim.',
            'Source digits0-4 train backbone; target digits5-9 use a fresh common head and disjoint class/task rows. No target-validation fitting.',
            'One declared source30/target20 epoch recipe; no seed/architecture/best-epoch search or independent final test.',
            'Local source-task pretraining, not ImageNet weights. Frozen/fine-tune observed comparison is not universal transfer benefit.',
            'Pixels divide by known maximum16, no fitted normalization. Main training has no augmentation, BN or dropout.',
            'Sobel/average kernels and zero-fill shift are declared mathematical operators on real images, not learned filters/validated augmentation policy.',
            'CPU float64 only; no GPU, mobile PyTorch, TorchVision weight download or production OCR guarantee.']}
    asset={**provenance,'roles':counts,'samples':samples,'kernels':KERNELS,'convolution_references':conv_refs,'pool_references':pool_refs,'branches':branches,
        'validation_metrics':{'source':source_result,'frozen':frozen_result,'finetune':fine_result},
        'source_history':source_history,'frozen_history':frozen_history,'finetune_history':fine_history,'frozen_backbone_max_abs':frozen_change,'finetune_backbone_max_abs':fine_change,
        'dtype':'float64','pixel_divisor':16,'target_labels':[5,6,7,8,9],'parameter_count':501,'torch_version':torch.__version__}
    if artifact_dir:
        folder=Path(artifact_dir);folder.mkdir(parents=True,exist_ok=True)
        for name,m in [('source',source),('frozen',frozen),('finetune',fine)]:torch.save(m.state_dict(),folder/(name+'.pt'))
        folder.joinpath('schema.json').write_text(json.dumps({'shape':['B',1,8,8],'divisor':16,'target_labels':[5,6,7,8,9],'source_sha256':HASH},indent=2)+'\n')
        folder.joinpath('checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.iterdir() if p.name in ['source.pt','frozen.pt','finetune.pt','schema.json']},indent=2)+'\n')
    return report,asset

def run_analysis(path,artifact_dir=None):
    previous=torch.get_num_threads()
    try:torch.set_num_threads(1);return analyse_source(path,artifact_dir)
    finally:torch.set_num_threads(previous)

# %% Import-safe CLI with explicit derived-asset writes
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path);parser.add_argument('--write-labs',action='store_true');parser.add_argument('--artifact-dir',type=Path)
    args=parser.parse_args(argv);report,asset=run_analysis(DATA/'digits.csv.gz',args.artifact_dir)
    if args.write_labs:(DATA/'vision_lab.json').write_text(json.dumps(asset,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    rendered=json.dumps(report,indent=2,allow_nan=False)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);temp=args.output.with_name(args.output.name+'.tmp');temp.write_text(rendered+'\n',encoding='utf-8');temp.replace(args.output)
    print(rendered);return report
if __name__=='__main__':main()
