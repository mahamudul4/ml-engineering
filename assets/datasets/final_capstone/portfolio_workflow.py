"""Chapter40: immutable prior-capstone evidence,claim audits andmock prompts.
Default CLI/import is read-only;--write-lab explicitly regenerates references.
No training,new holdout evaluation,production measurement orhiring assessment.
"""
from pathlib import Path
import argparse,hashlib,json,math
DATA=Path(__file__).resolve().parent;ROOT=DATA.parent
FILES={'classical':'wine_quality/capstone_lab.json','deep':'wine_quality/deep_capstone_lab.json','recommendation':'movielens/recommender_capstone_lab.json','rag':'scifact_rag/capstone_lab.json'}
EXTRA=['scifact_rag/corpus.jsonl','movielens/SOURCE_README.txt','wine_quality/README.md','wine_quality/white_source_manifest.json','scifact_rag/source_manifest.json']
SLICES=('all','first5','last5');FAULTS=('none','source_mismatch','license_missing','production_claim')
CHECKS=['contract','source','baseline','validation','failure','limits']
def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def payload(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def select(rows,scope):
 if scope not in SLICES:raise ValueError('Unknown evidence slice')
 return rows if scope=='all'else rows[:5]if scope=='first5'else rows[-5:]
def summaries(project,rows,scope='all'):
 if project not in FILES:raise ValueError('Unknown project')
 rows=select(rows,scope);n=len(rows)
 if project in('classical','deep'):
  t=.3 if project=='classical'else .25;tp=sum(r['positive']==1 and r['probability']>=t for r in rows);fp=sum(r['positive']==0 and r['probability']>=t for r in rows);fn=sum(r['positive']==1 and r['probability']<t for r in rows);tn=n-tp-fp-fn
  return dict(n=n,threshold=t,tp=tp,fp=fp,tn=tn,fn=fn,accuracy=(tp+tn)/n if n else None,precision=tp/(tp+fp)if tp+fp else None,recall=tp/(tp+fn)if tp+fn else None,mean_cost=(fp+4*fn)/n if n else None)
 if project=='recommendation':
  eligible=[r for r in rows if r['eligible']];values=[];hits_total=0
  for r in eligible:
   gold=set(r['eligible']);ranked=r['rankings']['rrf_cf'][:10];hits=sum(i in gold for i in ranked);hits_total+=hits;dcg=sum(1/math.log2(j+2)for j,i in enumerate(ranked)if i in gold);idcg=sum(1/math.log2(j+2)for j in range(min(10,len(gold))));values.append((hits/10,hits/len(gold),dcg/idcg))
  return dict(n=n,eligible_users=len(eligible),excluded_users=n-len(eligible),hits=hits_total,precision=sum(v[0]for v in values)/len(values)if values else None,recall=sum(v[1]for v in values)/len(values)if values else None,ndcg=sum(v[2]for v in values)/len(values)if values else None)
 return dict(n=n,format_valid=sum(r['format_valid']for r in rows),exact_packs=sum(r['exact']for r in rows),emitted=sum(r['emitted']for r in rows),verified_answers=0,truth_accuracy=None)
def records(sources):
 corpus={str(r['doc_id']):r for r in map(json.loads,(ROOT/'scifact_rag/corpus.jsonl').read_text().splitlines())};rag=[]
 for r in sources['rag']['samples']:
  case=r['cases']['retrieved'];chunks=case['pack']['selected'];exact=bool(chunks)and all(' '.join(corpus[c['doc_id']]['abstract'][c['start']:c['end']])==c['text']for c in chunks)
  rag.append(dict(id=r['id'],role=r['role'],text=case['generation']['text'],format_valid=case['generation']['format_valid'],exact=exact,emitted=case['decision']['emitted'],reason=case['decision']['reason'],citations=[f"[{c['doc_id']}:{c['start']}-{c['end']}]"for c in chunks]))
 return dict(classical=sources['classical']['decision_predictions'],deep=sources['deep']['decision_rows'],recommendation=sources['recommendation']['roles']['audit'],rag=rag)
def audit(card,fault='none'):
 if fault not in FAULTS:raise ValueError('Unknown audit fixture')
 expected=card['contract'];loaded=dict(expected)
 if fault=='source_mismatch':loaded['source_sha256']='authored wrong source identity'
 if fault=='license_missing':loaded['license']=''
 if fault=='production_claim':loaded['production_measured']=True
 issues=[k for k in expected if loaded.get(k)!=expected[k]]
 return dict(passed=not issues,issues=issues,loaded=loaded)

def mock_cards():
 roles={
 'ml_engineer':('ML Engineer','feature/serving parity,immutable release,latency constraints'),
 'data_scientist':('Data Scientist','estimand,paired uncertainty,selection bias anddecision utility'),
 'recs_engineer':('Recommendation Engineer','eligible candidates,ranking metrics,feedback andcold start'),
 'llm_engineer':('LLM / RAG Engineer','retrieval provenance,abstention,format andscope boundaries')}
 rounds={
 'project':('Project defense','একটিcapstone-এরproblem,source/license,baseline,split,metricওlimitationsবর্ণনাকরুন।','আপনারpersonalcontributionকোনটি? Frozenreferenceআরনিজেরimplementationকীভাবেআলাদাকরবেন?'),
 'coding':('Coding & debugging','একটিcorefunctionলিখুন,contract/invariantবলুন,edgecaseওindependentoracleদিন।','Shape/denominator/tie-policyবদলালেকোনtestfailকরা উচিত? Big-Oকোনinputdimensionধরে?'),
 'statistics':('Statistics & evaluation','একটিobservedmetric-এরpopulation/denominator,selectionওuncertaintyassumptionsবলুন।','এইresultকেনonlinecausalbenefitবাfreshconfirmationনয়? কীnewdatacollectionদরকার?'),
 'systems':('System & failure defense','Requesttrace,model/source/schema/policycontract,capacityassumptionsওfallbackexplainকরুন।','Dependencylateবাunavailableহলেকীserveকরবেন? Fallbackoverloadওcacheisolationকীভাবেverifyকরবেন?')}
 role_prompts={
 'ml_engineer':{
 'project':'Red/White Wine Pipeline-এর Source, Fit Boundary, Preprocessing এবং Model ও Policy-র Version ধরে Trace করুন। কোন অংশ নিজে Implement করেছেন, আর কোনটি Reference হিসেবে দেওয়া ছিল?',
 'coding':'Frozen Classifier-এর Confusion Matrix আর Symbolic Mean Cost কোনো Helper ছাড়া Implement করুন। Empty Class, Shape ও Nonfinite Input কীভাবে সামলাবেন, তার Contract এবং একটি Independent Oracle দিন।',
 'statistics':'CV AP winner MLP-এর decision cost logistic-এর চেয়ে বেশি কেন হতে পারে? Objective, Threshold, Denominator আর Selection History আলাদা করে ব্যাখ্যা করুন।',
 'systems':'একই Release-এ Scaler, Weight, Source বা Policy না মিললে কী Block করবেন? Compatible Fallback, Rollback আর মাপা Latency-র পার্থক্য ব্যাখ্যা করুন।'},
 'data_scientist':{
 'project':'একটি wine-quality classification brief লিখুন। Proxy Label, Target Population, Candidate Selection আর Action Cost-এর Assumption কী? নিজের অবদান আলাদা করে বলুন।',
 'coding':'একই Decision Row থেকে TP/FP/FN/TN, Precision আর Recall বের করার কোড লিখুন। Denominator শূন্য হলে কী হয় এবং Paired Policy Comparison ঠিক আছে কি না, তা যাচাইয়ের জন্য ন্যূনতম Test দিন।',
 'statistics':'Development-এ দেখা Metric থেকে নতুন Population-এ লাভ হবে বলে কি ধরে নেওয়া যায়? Estimand, Dependence, Repeated Selection আর নতুন Locked Evaluation Plan-এর পক্ষে যুক্তি দিন।',
 'systems':'Label দেরিতে এলে বা কিছু ক্ষেত্রেই শুধু দেখা গেলে Quality Monitoring আর Policy Evaluation কীভাবে বদলাবে? Missing Outcome-কে Oracle-correct ধরে নেবেন না।'},
 'recs_engineer':{
 'project':'MovieLens-এর Fit Cutoff থেকে Candidate Source আর বেছে নেওয়া RRF Ranking পর্যন্ত Trace করুন। Eligible Gold আর Empty User বাদ দেওয়ার নিয়ম এবং নিজের Implementation দেখান।',
 'coding':'একজন User-এর DCG/IDCG এবং Macro NDCG-এর কোড লিখুন। Duplicate Recommendation, Empty Gold, K-এর Boundary আর Tie হলে নির্দিষ্ট নিয়ম যাচাই করুন।',
 'statistics':'Macro User Recall আর Pooled Recall-এ কোন Population কী Weight পায়? MNAR Feedback আর Exposure Selection দিয়ে কেন Online Lift বোঝা যায় না?',
 'systems':'Personalized Source পাওয়া না গেলে Popularity Fallback কীভাবে Seen Item আর Eligibility-র নিয়ম মানবে? Cache Isolation আর হঠাৎ বেশি Request এলে Fallback-এর Capacity ব্যাখ্যা করুন।'},
 'llm_engineer':{
 'project':'সংরক্ষিত ছয়টি SciFact Example-এর Tiny Decoder, Retrieved Context আর Exact Citation ব্যাখ্যা করুন। দেওয়া Weight আর যাচাইয়ে নিজের অবদান আলাদা করে বলুন।',
 'coding':'Packed Sentence Span মূল Source-এর সঙ্গে হুবহু মেলে কি না, তা যাচাইয়ের Function লিখুন। Empty Context, ভুল Span আর Format ঠিক থাকলেও Evidence নেই এমন Output-এর জন্য Test দিন।',
 'statistics':'Train আর Dev মিলিয়ে ছয়টি Sample-এ Quote ও Format যাচাইয়ে Pass করলে কি Answer Accuracy বোঝা যাবে? Representative Annotation, Entailment আর Abstention Utility যাচাইয়ের পরিকল্পনা দিন।',
 'systems':'Source পাওয়া না গেলে, Index পুরোনো হলে বা Scope ভাঙলে RAG কী Response দেবে? যে Permission Check প্রস্তাব করছেন, তা ইতিমধ্যে যাচাই করা Provenance থেকে আলাদা করে বলুন।'}}
 cards={}
 for role,(name,focus)in roles.items():
  for stage,(title,prompt,follow)in rounds.items():cards[f'{role}:{stage}']=dict(role=name,stage=title,focus=focus,prompt=role_prompts[role][stage],follow_up='মূল Assumption ভুল হলে কোন ফল বা Test বদলাবে? একটি Counterexample দিন। এরপর কীভাবে আলাদাভাবে যাচাই করবেন, তা বলুন।',review=dict(contract='Input, Output ও Unit এবং Tie বা Error কীভাবে সামলাব, তা বলেছি কি?',source='Source, License, Role, Cutoff আর নিজের অবদানের কথা বলেছি কি?',baseline='সহজ Baseline, মূল Implementation আর Invariant দেখিয়েছি কি?',validation='Independent Check, Denominator আর Assumption দেখিয়েছি কি?',failure='একটি Failure Trace বা Edge Case দেখিয়ে কীভাবে সামলেছি, তার পক্ষে যুক্তি দিয়েছি কি?',limits='কী কী জানি না আর এরপর কী যাচাই করব, তা স্পষ্ট করে লিখেছি কি?'))
 return cards
def analyse():
 sources={k:read(ROOT/p)for k,p in FILES.items()};rows=records(sources)
 descriptions={
 'classical':('Classical ML · Red Wine','Chapter14 Logistic Regression C1; quality>=6; decision-validation313; threshold.3, FP1/FN4 symbolic cost. Model/CV/policy previously selected; final-test rows absent from this lab.','UCI Wine Quality/Cortez et al., CC BY4.0','Fresh domain/test performance and real action utility unknown.'),
 'deep':('Deep Learning · White Wine','Chapter21 fixed scaled MLP,8 hidden units; quality>=6; decision-validation955; threshold.25, FP1/FN4. CV AP selected MLP, but decision cost need not beat logistic. Test968 not re-evaluated.','UCI Wine Quality/Cortez et al., CC BY4.0','Observed decision validation, not fresh confirmation; score calibration/production latency unknown.'),
 'recommendation':('Recommendation · MovieLens','Chapter34 audit74 observed users, eligible-gold filter; fit80668 events/cutoff1458635162; selected weighted RRF_CF, budget50/K10. Audit results already observed.','GroupLens MovieLens research-use terms; original notice retained','Offline positive feedback MNAR; no online causal lift, current-user or production-QPS claim.'),
 'rag':('RAG / Generative AI · SciFact','Chapter29 six saved samples/retrieved case, train/dev mixed, not188-diagnostic aggregate. Tiny5710-parameter word GRU; output unverified hypothesis. Exact quotes show provenance, not truth.','SciFact/Wadden et al., claims CC BY4.0, abstracts ODC-By1.0','No general LLM/clinical/scientific verdict or aggregate answer-accuracy claim.')}
 cards={}
 for key,(title,protocol,license,limits)in descriptions.items():cards[key]=dict(title=title,source=FILES[key],protocol=protocol,limits=limits,contract=dict(source_sha256=digest(ROOT/FILES[key]),protocol=protocol,metric_scope='Previously observed offline diagnostic;descriptive slices only',license=license,production_measured=False))
 return dict(report=dict(version='portfolio40-v1',projects=4,reserved_outcomes_newly_scored=0,new_training_runs=0,production_measured=False,hiring_outcomes_observed=False,dependencies={p:digest(ROOT/p)for p in list(FILES.values())+EXTRA},scope='Frozenpriorcapstoneevidence;notuser-authoredportfolioachievement,newblindbenchmark orproductiondeployment. Filtersall/first5/last5areordereddescriptiveslices,notdemographicgroups/randomsamples. Mockchecksmanualself-review,notvalidatedhiringrubric.'),cards=cards,records=rows,summaries={f'{k}:{s}':summaries(k,rows[k],s)for k in FILES for s in SLICES},audits={f'{k}:{f}':audit(cards[k],f)for k in FILES for f in FAULTS},mock_cards=mock_cards(),check_keys=CHECKS)
def report_markdown(lab):
 lines=['# Chapter40 · evidence review template','','Scope: frozen priorcapstone diagnostics,not personal ownership orproduction achievement. Replace placeholders withyour ownverifiedwork;retainoriginallicenses.','']
 for key in FILES:
  card=lab['cards'][key];lines += ['## '+card['title'],card['protocol'],'','Observed summary: '+json.dumps(lab['summaries'][key+':all'],sort_keys=True),'','Limitations: '+card['limits'],'','My contribution: [writeactualimplementation/changeandindependentchecks]','Next validation: [specifymissingdata/measurementandprotocol]','']
 lines+=['## Reproduction','Run portfolio_workflow.py --verify-dir <bundle> from theoriginalrepository. Expectedsourcefiles retained;bundle doesnotduplicateallpreviousdatasets.','No new training,holdout scoring,GPUorproduction timing. Hashconsistencyrequires trustedexpectedmanifest;notauthenticity/scientificvalidity.','']
 return '\n'.join(lines)
def export_bundle(out,lab):
 out=Path(out);out.mkdir(parents=True,exist_ok=True)
 for name,x in [('portfolio_lab.json',lab),('evidence_contract.json',lab['report']),('mock_prompts.json',lab['mock_cards'])]:(out/name).write_text(payload(x),encoding='utf-8',newline='\n')
 (out/'PORTFOLIO_TEMPLATE.md').write_text(report_markdown(lab),encoding='utf-8',newline='\n');(out/'ATTRIBUTION.txt').write_bytes((DATA/'ATTRIBUTION.txt').read_bytes());(out/'MOVIELENS_SOURCE.txt').write_bytes((ROOT/'movielens/SOURCE_README.txt').read_bytes());names=['portfolio_lab.json','evidence_contract.json','mock_prompts.json','PORTFOLIO_TEMPLATE.md','ATTRIBUTION.txt','MOVIELENS_SOURCE.txt'];(out/'checksums.json').write_text(payload({n:digest(out/n)for n in names}),encoding='utf-8',newline='\n')
def verify_bundle(out):
 out=Path(out);checks=read(out/'checksums.json');names={'portfolio_lab.json','evidence_contract.json','mock_prompts.json','PORTFOLIO_TEMPLATE.md','ATTRIBUTION.txt','MOVIELENS_SOURCE.txt'}
 if set(checks)!=names:raise ValueError('Incomplete portfolio bundle')
 for n,h in checks.items():
  if digest(out/n)!=h:raise ValueError('Checksum mismatch:'+n)
 lab=read(out/'portfolio_lab.json');contract=read(out/'evidence_contract.json')
 if contract!=lab['report']or contract['reserved_outcomes_newly_scored']!=0 or contract['new_training_runs']!=0 or contract['production_measured']or contract['hiring_outcomes_observed']:raise ValueError('Evidence scope mismatch')
 for p,h in contract['dependencies'].items():
  if digest(ROOT/p)!=h:raise ValueError('Dependency source mismatch:'+p)
 if lab!=analyse()or read(out/'mock_prompts.json')!=lab['mock_cards']or(out/'PORTFOLIO_TEMPLATE.md').read_text(encoding='utf-8')!=report_markdown(lab):raise ValueError('Evidence semantic mismatch')
 if (out/'MOVIELENS_SOURCE.txt').read_bytes()!=(ROOT/'movielens/SOURCE_README.txt').read_bytes()or(out/'ATTRIBUTION.txt').read_bytes()!=(DATA/'ATTRIBUTION.txt').read_bytes():raise ValueError('Notice mismatch')
 return dict(verified=True,files=6,projects=4,mock_rounds=16)
def main():
 p=argparse.ArgumentParser();p.add_argument('--write-lab',action='store_true');p.add_argument('--artifact-dir',type=Path);p.add_argument('--verify-dir',type=Path);args=p.parse_args()
 if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
 lab=analyse()
 if args.write_lab:(DATA/'portfolio_lab.json').write_text(payload(lab),encoding='utf-8',newline='\n')
 if args.artifact_dir:export_bundle(args.artifact_dir,lab)
 print(json.dumps(dict(report=lab['report'],summaries=lab['summaries']),indent=2))
if __name__=='__main__':main()
