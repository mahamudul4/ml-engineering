"""Chapter35: local SQLite feature pipeline over original first547 Bike days.

Arrival times are DECLARED SOFTWARE FIXTURES, not source ingestion timestamps.
No invented demand observations, external services, models or training/GPU.
Default import/CLI preserves assets; --write-lab explicitly regenerates JSON.
"""
from pathlib import Path
from datetime import date,timedelta
import argparse,csv,hashlib,itertools,json,math,sqlite3

DATA=Path(__file__).resolve().parent
SOURCE_HASHES={'day.csv':'a6bcf826782d3c0fbfdcbeead17cd0884185a0dafe8ff10cd48a874ee7ba18be','Readme.txt':'b92c8628622948bf0828c43a1b315d1517c3d7fd63654730d0dea379b8e88175'}
SCENARIOS={'on_time':'event_day+1','late_fixture':'event_day+1+(3 if event_day%17==0 else 0)'}
FIELDS=['lag1','lag7','mean7','observed7','age_days']
START=date(2011,1,1)
def payload(value):return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n'
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def day_string(day):return (START+timedelta(days=day)).isoformat()
def load():
    for name,h in SOURCE_HASHES.items():
        if digest(DATA/name)!=h:raise ValueError(f'Source hash mismatch: {name}')
    events=[]
    with (DATA/'day.csv').open(encoding='utf-8',newline='')as f:
        for index,row in enumerate(itertools.islice(csv.DictReader(f),547)):
            if row['dteday']!=day_string(index):raise ValueError('Calendar gap')
            count=int(row['cnt']);weekday=int(row['weekday'])
            if count!=int(row['casual'])+int(row['registered'])or count<0 or weekday!=(START+timedelta(days=index)).isoweekday()%7:raise ValueError('Source contract failed')
            events.append(dict(event_day=index,date=row['dteday'],cnt=count,weekday=weekday,event_key='bike-global:'+row['dteday']))
    if len(events)!=547:raise ValueError('Incomplete source prefix')
    return events
def scheduled(events,scenario='on_time'):
    if scenario not in SCENARIOS:raise ValueError('Unknown schedule')
    return [dict(r,available_day=r['event_day']+1+(3 if scenario=='late_fixture'and r['event_day']%17==0 else 0))for r in events]
def validate(row):
    errors=[]
    for key in ['event_day','available_day','cnt','weekday']:
        if type(row.get(key))is not int:errors.append('type:'+key)
    for key in ['date','event_key']:
        if not isinstance(row.get(key),str):errors.append('type:'+key)
    if errors:return errors
    if row['cnt']<0:errors.append('negative_count')
    if row['available_day']<row['event_day']+1:errors.append('availability_before_day_close')
    if row.get('date')!=day_string(row['event_day']):errors.append('calendar_date')
    if row.get('event_key')!='bike-global:'+row.get('date',''):errors.append('entity_key')
    if row['weekday']!=(START+timedelta(days=row['event_day'])).isoweekday()%7:errors.append('weekday')
    return errors
def features(events,target,asof=None,latest=False):
    asof=target if asof is None else asof
    known=[r for r in events if r['event_day']<target and(latest or r['available_day']<=asof)]
    lookup={r['event_day']:r['cnt']for r in known};window=[r['cnt']for r in known if target-7<=r['event_day']<target]
    newest=max((r['event_day']for r in known),default=None)
    return dict(lag1=lookup.get(target-1),lag7=lookup.get(target-7),mean7=sum(window)/len(window)if window else None,observed7=len(window),age_days=target-1-newest if newest is not None else None)
def difference(a,b):
    return [key for key in FIELDS if (a[key]is None)!=(b[key]is None)or(a[key]is not None and b[key]is not None and abs(a[key]-b[key])>1e-10)]
def connect(path=':memory:'):
    db=sqlite3.connect(path);db.execute('PRAGMA foreign_keys=ON')
    db.executescript('''CREATE TABLE IF NOT EXISTS events(
      scenario TEXT NOT NULL,event_key TEXT NOT NULL,event_day INTEGER NOT NULL,
      available_day INTEGER NOT NULL,cnt INTEGER NOT NULL CHECK(cnt>=0),weekday INTEGER NOT NULL,
      date TEXT NOT NULL,PRIMARY KEY(scenario,event_key),CHECK(available_day>=event_day+1));
    CREATE INDEX IF NOT EXISTS available_idx ON events(scenario,available_day,event_day);
    CREATE TABLE IF NOT EXISTS snapshots(scenario TEXT NOT NULL,target_day INTEGER NOT NULL,
      asof_day INTEGER NOT NULL,feature_version TEXT NOT NULL,body TEXT NOT NULL,
      PRIMARY KEY(scenario,target_day,asof_day,feature_version));''')
    return db
def ingest(db,rows,scenario='on_time',chunk=32,fail_batch=None):
    if scenario not in SCENARIOS or chunk<1:raise ValueError('Invalid ingest configuration')
    totals=dict(deliveries=len(rows),inserted=0,duplicates=0,rejected=0,batches=math.ceil(len(rows)/chunk))
    for batch,start in enumerate(range(0,len(rows),chunk)):
        local=dict(inserted=0,duplicates=0,rejected=0)
        with db:
            for row in rows[start:start+chunk]:
                if validate(row):local['rejected']+=1;continue
                old=db.execute('SELECT event_day,available_day,cnt,weekday,date FROM events WHERE scenario=? AND event_key=?',(scenario,row['event_key'])).fetchone()
                values=(row['event_day'],row['available_day'],row['cnt'],row['weekday'],row['date'])
                if old is not None:
                    local['duplicates'if old==values else'rejected']+=1;continue
                db.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?) ON CONFLICT(scenario,event_key) DO NOTHING',(scenario,row['event_key'],*values));local['inserted']+=1
            if fail_batch==batch:raise RuntimeError('Declared crash fixture before commit')
        for key in local:totals[key]+=local[key]
    return totals
def sql_features(db,target,scenario='on_time',asof=None):
    asof=target if asof is None else asof
    row=db.execute('''SELECT MAX(CASE WHEN event_day=? THEN cnt END),
      MAX(CASE WHEN event_day=? THEN cnt END),AVG(CASE WHEN event_day>=? THEN cnt END),
      COUNT(CASE WHEN event_day>=? THEN 1 END),MAX(event_day)
      FROM events WHERE scenario=? AND event_day<? AND available_day<=?''',
      (target-1,target-7,target-7,target-7,scenario,target,asof)).fetchone()
    return dict(lag1=row[0],lag7=row[1],mean7=row[2],observed7=row[3],age_days=target-1-row[4]if row[4]is not None else None)
def replay(events,duplicates=False,invalid=False,chunk=32,scenario='late_fixture'):
    rows=sorted(events,key=lambda r:(r['available_day'],r['event_day']))
    if duplicates:rows=rows+rows
    if invalid:rows=rows+[dict(rows[0],cnt=-1)]
    with connect()as db:
        report=ingest(db,rows,scenario=scenario,chunk=chunk);report['stored']=db.execute('SELECT COUNT(*) FROM events').fetchone()[0]
    db.close()
    return report
def definition():
    return dict(feature_version='bike-features35-v1',schema_id='daily-bike-count-v1',entity_key='bike-global',source_sha256=SOURCE_HASHES['day.csv'],fields=FIELDS,window='event_day in [target-7,target);available_day<=asof',null_policy='No known lag/empty rolling window -> null;observed7=0,never zero-impute demand',scenarios=SCENARIOS,calendar='Nominal date indices,not UTC ingestion timestamps',excluded_features=['target_cnt','casual','registered','realized_target_weather'])
def manifest(scenario):
    d=definition();return dict(feature_version=d['feature_version'],definition_sha256=hashlib.sha256(payload(d).encode()).hexdigest(),source_sha256=SOURCE_HASHES['day.csv'],availability_rule=SCENARIOS[scenario],entity_key='bike-global')
def contract_errors(expected,loaded):return [key for key in ['feature_version','definition_sha256','source_sha256','availability_rule','entity_key']if expected.get(key)!=loaded.get(key)]
def guarded_features(events,target,expected,loaded,latest=False):
    if contract_errors(expected,loaded):return None
    return features(events,target,latest=latest)
def analyse():
    original=load();scenarios={};cases=[];stats={}
    for scenario in SCENARIOS:
        events=scheduled(original,scenario);rows=[];available=sorted(events,key=lambda r:(r['available_day'],r['event_day']));cursor=0;incremental=[]
        with connect()as db:
            ingest(db,events,scenario)
            for target in range(1,547):
                while cursor<len(available)and available[cursor]['available_day']<=target:incremental.append(available[cursor]);cursor+=1
                batch=features(events,target);stream=features(incremental,target);sql=sql_features(db,target,scenario)
                if difference(batch,stream)or difference(batch,sql):raise AssertionError('Feature parity failed')
                latest=features(events,target,latest=True);rows.append(dict(target=target,features=batch,latest=latest,different=difference(batch,latest)))
                if target in [365,375,409,545]:cases.append(dict(scenario=scenario,target=target,date=day_string(target),outcome=original[target]['cnt'],features=batch,latest=latest,window=[r for r in events if target-7<=r['event_day']<target]))
        db.close()
        scenarios[scenario]=events;stats[scenario]=dict(snapshots=len(rows),parity_failures=0,retrospective_mismatch_snapshots=sum(bool(r['different'])for r in rows),missing_lag1=sum(r['features']['lag1']is None for r in rows),snapshots_data=rows)
    return dict(report=dict(source_hashes=SOURCE_HASHES,source='UCI Bike Sharing,Fanaee-T(2013),CC BY4.0,https://doi.org/10.24432/C5W894',used_rows=547,first_date=original[0]['date'],last_date=original[-1]['date'],reserved_outcomes_used=0,availability_scope='SOFTWARE FIXTURES:day-close available at event_day+1;late_fixture adds3 calendar days every17th source event. No source ingestion clocks/timezone/latency/traffic claims. Original counts/dates unchanged. First547 historical days only;last184 outcomes excluded. No model training/accuracy or online benefit experiment.'),definition=definition(),manifests={s:manifest(s)for s in SCENARIOS},events=scenarios,statistics=stats,cases=cases,replays={name:replay(scenarios['late_fixture'],duplicates=dup,invalid=bad)for name,dup,bad in [('normal',False,False),('duplicates',True,False),('invalid',True,True)]})
def export_bundle(directory,lab):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True);database=directory/'feature_store.sqlite'
    # Explicit export may replace ONLY this named derived database,never source data.
    if database.exists():database.unlink()
    with connect(database)as db:
        for scenario,events in lab['events'].items():
            ingest(db,events,scenario)
            with db:
                for row in lab['statistics'][scenario]['snapshots_data']:
                    db.execute('INSERT INTO snapshots VALUES(?,?,?,?,?)',(scenario,row['target'],row['target'],lab['definition']['feature_version'],payload(row['features'])))
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    db.close()
    files={'feature_definition.json':lab['definition'],'pipeline_lab.json':lab}
    for name,value in files.items():(directory/name).write_text(payload(value),encoding='utf-8',newline='\n')
    (directory/'SOURCE_README.txt').write_bytes((DATA/'Readme.txt').read_bytes())
    (directory/'ATTRIBUTION.txt').write_text('Bike Sharing,Hadi Fanaee-T(2013),UCI Machine Learning Repository.\nhttps://doi.org/10.24432/C5W894\nCC BY4.0 https://creativecommons.org/licenses/by/4.0/\nDerived features use first547 original daily counts/dates;arrival times explicitly authored software fixtures. Last184 outcomes excluded.\n',encoding='utf-8',newline='\n')
    names=['feature_store.sqlite',*files,'SOURCE_README.txt','ATTRIBUTION.txt'];(directory/'checksums.json').write_text(payload({name:digest(directory/name)for name in names}),encoding='utf-8')
def verify_bundle(directory):
    directory=Path(directory);checks=json.loads((directory/'checksums.json').read_text());expected={'feature_store.sqlite','feature_definition.json','pipeline_lab.json','SOURCE_README.txt','ATTRIBUTION.txt'}
    if set(checks)!=expected:raise ValueError('Incomplete artifact set')
    for name,h in checks.items():
        if digest(directory/name)!=h:raise ValueError('Checksum mismatch:'+name)
    if digest(directory/'SOURCE_README.txt')!=SOURCE_HASHES['Readme.txt']:raise ValueError('Source notice mismatch')
    spec=json.loads((directory/'feature_definition.json').read_text(encoding='utf-8'));lab=json.loads((directory/'pipeline_lab.json').read_text(encoding='utf-8'))
    if spec!=lab['definition']or any(lab['manifests'][s]['definition_sha256']!=digest(directory/'feature_definition.json')for s in SCENARIOS):raise ValueError('Definition manifest mismatch')
    with sqlite3.connect(f'file:{(directory/"feature_store.sqlite").resolve().as_posix()}?mode=ro',uri=True)as db:
        if db.execute('PRAGMA integrity_check').fetchone()[0]!='ok':raise ValueError('SQLite integrity failed')
        counts=[db.execute(f'SELECT COUNT(*) FROM {name}').fetchone()[0]for name in ['events','snapshots']]
        versions=[r[0]for r in db.execute('SELECT DISTINCT feature_version FROM snapshots')]
    db.close()
    if versions!=[spec['feature_version']]:raise ValueError('Snapshot version mismatch')
    if counts!=[1094,1092]:raise ValueError('Incomplete materialization')
    return dict(verified=True,files=len(checks),event_rows=counts[0],snapshots=counts[1])
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--write-lab',action='store_true');parser.add_argument('--artifact-dir',type=Path);parser.add_argument('--verify-dir',type=Path);args=parser.parse_args()
    if args.verify_dir:print(json.dumps(verify_bundle(args.verify_dir)));return
    lab=analyse()
    if args.write_lab:(DATA/'pipeline_lab.json').write_text(payload(lab),encoding='utf-8')
    if args.artifact_dir:export_bundle(args.artifact_dir,lab)
    print(json.dumps(dict(report=lab['report'],statistics={s:{k:v for k,v in r.items()if k!='snapshots_data'}for s,r in lab['statistics'].items()},replays=lab['replays'],cases=[{k:v for k,v in c.items()if k!='window'}for c in lab['cases']]),indent=2))
if __name__=='__main__':main()
