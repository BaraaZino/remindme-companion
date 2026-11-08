from concurrent.futures import ThreadPoolExecutor
import urllib.request, pathlib, zipfile
import os
os.chdir(pathlib.Path(__file__).resolve().parents[1])
root=pathlib.Path('.tools');root.mkdir(exist_ok=True)
items=[('platform','https://dl.google.com/android/repository/platform-35_r02.zip',64273788),('buildtools','https://dl.google.com/android/repository/build-tools_r35_macosx.zip',76857898)]
def part(job):
 name,url,start,end=job
 req=urllib.request.Request(url,headers={'Range':f'bytes={start}-{end}'})
 for attempt in range(3):
  try:
   with urllib.request.urlopen(req,timeout=90) as r: data=r.read()
   if len(data)!=end-start+1: raise RuntimeError(f'Bad length {len(data)}')
   (root/f'{name}.{start}').write_bytes(data); return
  except Exception:
   if attempt==2:raise
jobs=[]
for name,url,size in items:
 step=4*1024*1024
 jobs += [(name,url,start,min(start+step,size)-1) for start in range(0,size,step)]
with ThreadPoolExecutor(max_workers=12) as pool:list(pool.map(part,jobs))
for name,url,size in items:
 with (root/f'{name}.zip').open('wb') as out:
  for job in jobs:
   if job[0]==name:
    p=root/f'{name}.{job[2]}';out.write(p.read_bytes());p.unlink()
 with zipfile.ZipFile(root/f'{name}.zip') as z:z.extractall(root/name)
 print(name,'downloaded and extracted',flush=True)
