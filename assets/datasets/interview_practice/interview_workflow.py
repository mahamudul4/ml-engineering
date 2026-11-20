"""Chapter39: source-backed coding/SQLite/debugging practice, fully offline.

Frozen Chapter34 fit-only MovieLens rows and Chapter38 development predictions.
No new training/holdout scoring, production timing or real interview-pass claims.
Default CLI preserves assets; --write-lab explicitly builds the derived database.
"""
from pathlib import Path
from collections import defaultdict
import argparse,hashlib,json,math,sqlite3,tempfile

DATA=Path(__file__).resolve().parent;ROOT=DATA.parent
DEPENDENCIES=['movielens/recommender_capstone_lab.json','system_design/design_lab.json']
def payload(x):return json.dumps(x,sort_keys=True,ensure_ascii=False,separators=(',',':'))+'\n'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def sources():return read(ROOT/DEPENDENCIES[0]),read(ROOT/DEPENDENCIES[1])

SCHEMA='''PRAGMA foreign_keys=ON;
CREATE TABLE movies(movie_id INTEGER PRIMARY KEY,title TEXT NOT NULL);
CREATE TABLE ratings(user_id INTEGER NOT NULL,movie_id INTEGER NOT NULL REFERENCES movies(movie_id),rating REAL NOT NULL CHECK(rating>=.5 AND rating<=5),ts INTEGER NOT NULL,PRIMARY KEY(user_id,movie_id));
CREATE TABLE movie_genres(movie_id INTEGER NOT NULL REFERENCES movies(movie_id),genre TEXT NOT NULL,PRIMARY KEY(movie_id,genre));
CREATE INDEX ratings_movie ON ratings(movie_id);
CREATE INDEX ratings_user_time ON ratings(user_id,ts DESC,movie_id DESC);
CREATE INDEX genres_name_movie ON movie_genres(genre,movie_id);
'''
def build_database(path):
    rec,_=sources();path=Path(path)
    if path.exists():raise ValueError('Build into a new path')
    db=sqlite3.connect(path);db.executescript(SCHEMA)
    with db:
        db.executemany('INSERT INTO movies VALUES(?,?)',[(r[0],r[1])for r in rec['model']['movies']])
        db.executemany('INSERT INTO ratings VALUES(?,?,?,?)',rec['model']['train'])
        db.executemany('INSERT INTO movie_genres VALUES(?,?)',[(r[0],g)for r in rec['model']['movies']for g in sorted(r[2])])
    db.execute('VACUUM');db.close()

def connect(path=None):
    db=sqlite3.connect((path or DATA/'interview.sqlite').resolve().as_uri()+'?mode=ro',uri=True);db.row_factory=sqlite3.Row;db.execute('PRAGMA query_only=ON');return db
def sql_query(task='summary',variant='fixed',genre='All',minimum=10,k=10):
    if task not in('summary','top_movies','latest_user')or variant not in('fixed','fanout')or genre not in('All','Comedy','Drama','Action')or type(minimum)is not int or minimum<1 or type(k)is not int or k<0:raise ValueError('Invalid SQL practice selection')
    eligible=('SELECT r.* FROM ratings r WHERE (?=\'All\' OR EXISTS(SELECT 1 FROM movie_genres g WHERE g.movie_id=r.movie_id AND g.genre=?))'if variant=='fixed'else'SELECT r.* FROM ratings r JOIN movie_genres g ON g.movie_id=r.movie_id WHERE (?=\'All\' OR g.genre=?)')
    prefix='WITH eligible AS ('+eligible+') '
    if task=='summary':return prefix+'SELECT COUNT(*) AS n,COUNT(DISTINCT user_id) AS users,COUNT(DISTINCT movie_id) AS movies,AVG(rating) AS mean FROM eligible',[genre,genre]
    if task=='top_movies':return prefix+'SELECT movie_id,COUNT(*) AS n,AVG(rating) AS mean FROM eligible GROUP BY movie_id HAVING COUNT(*)>=? ORDER BY ROUND(AVG(rating),12) DESC,movie_id ASC LIMIT ?',[genre,genre,minimum,k]
    return prefix+', ranked AS (SELECT user_id,movie_id,rating,ts,ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY ts DESC,movie_id DESC) AS rn FROM eligible) SELECT user_id,movie_id,rating,ts FROM ranked WHERE rn=1 ORDER BY user_id ASC LIMIT ?',[genre,genre,k]
def run_sql(db,**kw):
    sql,params=sql_query(**kw);return [dict(r)for r in db.execute(sql,params)]

def rank_key(row):return(math.floor(row['total']/row['n']*1e12+.5),-row['id'])
def top_k(catalog,k=10,minimum=10,method='heap'):
    if type(k)is not int or k<0 or type(minimum)is not int or minimum<1 or method not in('heap','merge'):raise ValueError('Invalid Top-K request')
    n=sum(r['n']>=minimum for r in catalog);comparisons=0
    def eligible():return (r for r in catalog if r['n']>=minimum)
    def better(a,b):
        nonlocal comparisons
        comparisons+=1;return rank_key(a)>rank_key(b)
    def merge_sort(xs):
        if len(xs)<2:return xs[:]
        at=len(xs)//2;a,b=merge_sort(xs[:at]),merge_sort(xs[at:]);out=[];i=j=0
        while i<len(a)and j<len(b):
            if better(a[i],b[j]):out.append(a[i]);i+=1
            else:out.append(b[j]);j+=1
        return out+a[i:]+b[j:]
    if not k:return dict(ids=[],eligible=n,comparisons=0,selection_slots=0)
    if method=='merge':selected=merge_sort(list(eligible()))[:k];slots=n
    else:
        heap=[]
        for row in eligible():
            if len(heap)<k:
                heap.append(row);i=len(heap)-1
                while i:
                    p=(i-1)//2
                    if not better(heap[p],heap[i]):break
                    heap[i],heap[p]=heap[p],heap[i];i=p
            elif better(row,heap[0]):
                heap[0]=row;i=0
                while 2*i+1<len(heap):
                    child=2*i+1
                    if child+1<len(heap)and better(heap[child],heap[child+1]):child+=1
                    if not better(heap[i],heap[child]):break
                    heap[i],heap[child]=heap[child],heap[i];i=child
        selected=merge_sort(heap);slots=len(heap)
    return dict(ids=[r['id']for r in selected],eligible=n,comparisons=comparisons,selection_slots=slots)

def metrics(rows,threshold=.5,bug='none',fp_cost=10):
    if not math.isfinite(threshold)or not 0<=threshold<=1 or bug not in('none','precision_swap','logit_threshold')or fp_cost<0:raise ValueError('Invalid diagnostic request')
    tp=fp=tn=fn=0;loss=0.
    for r in rows:
        p=r['logit']>=threshold if bug=='logit_threshold'else r['score']>=threshold;y=r['label']
        if p and y:tp+=1
        elif p:fp+=1
        elif y:fn+=1
        else:tn+=1
        z=r['logit'];loss+=max(z,0)-z*y+math.log1p(math.exp(-abs(z)))
    precision=tp/(tp+fp)if tp+fp else None;recall=tp/(tp+fn)if tp+fn else None
    return dict(n=len(rows),threshold=threshold,bug=bug,fp_cost=fp_cost,tp=tp,fp=fp,tn=tn,fn=fn,precision=precision,recall=recall,reported_precision=recall if bug=='precision_swap'else precision,accuracy=(tp+tn)/len(rows)if rows else None,fpr=fp/(fp+tn)if fp+tn else None,symbolic_cost=fp_cost*fp+fn,bce=loss/len(rows)if rows else None)

def analyse():
    rec,design=sources();counts=defaultdict(lambda:[0,0.])
    for user,item,rating,ts in rec['model']['train']:counts[item][0]+=1;counts[item][1]+=rating
    titles={r[0]:r[1]for r in rec['model']['movies']};catalog=[dict(id=i,title=titles[i],n=v[0],total=v[1])for i,v in sorted(counts.items())];model=design['spam']['model'];rows=[]
    for r in design['spam']['validation']:
        z=model['intercept']+sum(w*(x-mu)/s for x,mu,s,w in zip(r['features'],model['mean'],model['scale'],model['weights']));p=1/(1+math.exp(-z))if z>=0 else math.exp(z)/(1+math.exp(z));rows.append(dict(index=r['index'],label=r['label'],score=p,logit=z))
    db=connect();sql={}
    for task in ('summary','top_movies','latest_user'):
        for variant in ('fixed','fanout'):
            for genre in ('All','Comedy','Drama','Action'):
                for minimum in ((1,10,50)if task=='top_movies'else(10,)):
                    for k in ((5,10,20)if task!='summary'else(10,)):
                        key=':'.join(map(str,[task,variant,genre,minimum,k]));sql[key]=run_sql(db,task=task,variant=variant,genre=genre,minimum=minimum,k=k)
    schema=[dict(r)for r in db.execute("SELECT name,sql FROM sqlite_master WHERE type IN('table','index') AND sql IS NOT NULL ORDER BY name")];fk=[dict(r)for r in db.execute('PRAGMA foreign_key_check')];db.close();assert not fk
    return dict(report=dict(protocol='Frozen Chapter34 fit-only MovieLens ratings;Chapter38 development validation predictions. No new fit,tuning,holdout scoring,production timings or observed interview-pass evidence.',fit_rows=len(rec['model']['train']),fit_users=len({r[0]for r in rec['model']['train']}),fit_items=len(catalog),fit_cutoff=rec['report']['fit_cutoff'],validation_rows=len(rows),reserved_outcomes_scored=0,database_sha256=digest(DATA/'interview.sqlite'),dependencies={p:digest(ROOT/p)for p in DEPENDENCIES},comparison_definition='Ranking comparator calls only;authored merge/heap implementations,not wall-clock timings. Selection slots exclude input/output/object/stack overhead.',sql_scope='Immutable local SQLite snapshot;fanout and precision/logit bugs explicitly authored fixtures,not observed defects in original sources.'),catalog=catalog,diagnostics=rows,schema=schema,sql=sql,algorithms={':'.join(map(str,[minimum,k,method])):top_k(catalog,k,minimum,method)for minimum in(1,10,50)for k in(5,10,20)for method in('heap','merge')},metrics={':'.join(map(str,[t,b,c])):metrics(rows,t,b,c)for t in(.2,.5,.8)for b in('none','precision_swap','logit_threshold')for c in(1,10,100)})

def export_bundle(out,lab):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    (out/'interview_lab.json').write_text(payload(lab),encoding='utf-8',newline='\n');(out/'interview.sqlite').write_bytes((DATA/'interview.sqlite').read_bytes());(out/'source_contract.json').write_text(payload(lab['report']),encoding='utf-8',newline='\n');(out/'MOVIELENS_SOURCE.txt').write_bytes((ROOT/'movielens/SOURCE_README.txt').read_bytes());(out/'SPAM_ATTRIBUTION.txt').write_bytes((ROOT/'spambase/source_manifest.json').read_bytes());(out/'ATTRIBUTION.txt').write_bytes((DATA/'ATTRIBUTION.txt').read_bytes());names=['interview_lab.json','interview.sqlite','source_contract.json','MOVIELENS_SOURCE.txt','SPAM_ATTRIBUTION.txt','ATTRIBUTION.txt'];(out/'checksums.json').write_text(payload({n:digest(out/n)for n in names}),encoding='utf-8',newline='\n')
def verify_bundle(out):
    out=Path(out);checks=read(out/'checksums.json');names={'interview_lab.json','interview.sqlite','source_contract.json','MOVIELENS_SOURCE.txt','SPAM_ATTRIBUTION.txt','ATTRIBUTION.txt'}
    if set(checks)!=names:raise ValueError('Incomplete practice bundle')
    for n,h in checks.items():
        if digest(out/n)!=h:raise ValueError('Checksum mismatch:'+n)
    lab=read(out/'interview_lab.json');contract=read(out/'source_contract.json')
    if contract!=lab['report']or contract['reserved_outcomes_scored']!=0 or digest(out/'interview.sqlite')!=contract['database_sha256']:raise ValueError('Practice contract mismatch')
    for name,h in contract['dependencies'].items():
        if digest(ROOT/name)!=h:raise ValueError('Dependency source mismatch:'+name)
    for name,source in [('MOVIELENS_SOURCE.txt',ROOT/'movielens/SOURCE_README.txt'),('SPAM_ATTRIBUTION.txt',ROOT/'spambase/source_manifest.json'),('ATTRIBUTION.txt',DATA/'ATTRIBUTION.txt')]:
        if digest(out/name)!=digest(source):raise ValueError('Source notice mismatch')
    db=connect(out/'interview.sqlite')
    if db.execute('PRAGMA integrity_check').fetchone()[0]!='ok'or db.execute('SELECT COUNT(*) FROM ratings').fetchone()[0]!=80668:raise ValueError('Snapshot integrity mismatch')
    for key,expected in lab['sql'].items():
        task,variant,genre,minimum,k=key.split(':')
        if run_sql(db,task=task,variant=variant,genre=genre,minimum=int(minimum),k=int(k))!=expected:raise ValueError('SQL reference mismatch')
    db.close();return dict(verified=True,files=6,fit_rows=80668,validation_rows=738)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);args=parser.parse_args()
    if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
    if args.write_lab:
        with tempfile.TemporaryDirectory()as td:
            path=Path(td)/'interview.sqlite';build_database(path);(DATA/'interview.sqlite').write_bytes(path.read_bytes())
    lab=analyse()
    if args.write_lab:(DATA/'interview_lab.json').write_text(payload(lab),encoding='utf-8',newline='\n')
    if args.artifact_dir:export_bundle(args.artifact_dir,lab)
    print(json.dumps(dict(report=lab['report'],sql_presets=len(lab['sql']),algorithm_presets=len(lab['algorithms']),metric_presets=len(lab['metrics']),default_topk=top_k(lab['catalog']),default_metrics=metrics(lab['diagnostics']),correct_summary=lab['sql']['summary:fixed:All:10:10'],fanout_summary=lab['sql']['summary:fanout:All:10:10']),indent=2))
if __name__=='__main__':main()
