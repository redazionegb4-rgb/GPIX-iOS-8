"""Run against a local copy of GPIX Backend 2.24, never against production.
Usage: python QA/backend_contract.py /path/to/GPIX/Backend
"""
import asyncio,base64,io,os,sys,tempfile,time
from pathlib import Path
backend=Path(sys.argv[1]).resolve()
sys.path.insert(0,str(backend));os.environ['GPIX_DATA']=tempfile.mkdtemp(prefix='gpix-native55-')
import httpx
from PIL import Image
import server
checks=0
async def main():
 global checks
 async with httpx.AsyncClient(transport=httpx.ASGITransport(app=server.app),base_url='https://test') as client:
  async def send(path,payload,headers=None,status=200):
   global checks
   response=await client.post(path,json=payload,headers=headers)
   assert response.status_code==status,(path,response.status_code,response.text);checks+=1
   return response
  async def register(name):
   r=(await send('/auth/register',{'name':name,'username':name,'email':name+'@test.invalid','password':'StrongPassword123','device':'iPhone','platform':'ios'})).json()
   return {'Authorization':'Bearer '+r['token']},r['state']['me']['id']
  async def act(h,name,payload):return (await send('/actions',{'action':name,'payload':payload},h)).json()['state']
  async def state(h):return (await client.get('/state',headers=h)).json()['state']
  a,aid=await register('native55a');b,bid=await register('native55b')
  await act(b,'profile',{'private':True});s=await act(a,'follow',{'user':bid,'enabled':True});assert bid in s['pending'] and bid not in s['following']
  await act(b,'accept',{'user':aid,'enabled':True});s=await state(a);assert bid in s['following'] and bid not in s['pending']
  await act(b,'follow',{'user':aid,'enabled':True})
  for key,value in [('hideInstantBubble',True),('activityStatus',True),('imageProtection',True),('messagePreviews',False),('allowMessages','following'),('storyReplies','all'),('allowMentions','all'),('pushEnabled',False)]:await act(a,'preferences',{'key':key,'value':value})
  await act(a,'profileLinks',{'links':[{'type':'instagram','value':'demix.87','title':'Instagram'},{'type':'website','value':'https://example.org','title':'Sito web'},{'type':'whatsapp','value':'+39 333 1234567','title':'WhatsApp'}]})
  image=io.BytesIO();Image.new('RGB',(80,120),'purple').save(image,format='JPEG')
  async def upload():return (await send('/media',{'mime':'image/jpeg','data':base64.b64encode(image.getvalue()).decode()},a)).json()['id']
  media=await upload();s=await act(a,'post',{'kind':'post','media':media,'mediaItems':[media],'text':'Nuovo post','style':{'aspect':.8},'idempotencyKey':'native55post'});post=s['posts'][0]['id']
  await act(b,'like',{'id':post,'enabled':True});s=await act(b,'comment',{'id':post,'text':'Commento'});comment=next(p for p in s['posts'] if p['id']==post)['comments'][0]['id']
  await act(a,'hideComment',{'id':comment,'enabled':True});await act(a,'hideComment',{'id':comment,'enabled':False});await act(b,'deleteComment',{'id':comment})
  s=await act(a,'thread',{'user':bid});tid=next(t['id'] for t in s['threads'] if bid in t['members'])
  await act(a,'messageExpiry',{'id':tid,'seconds':-1});s=await act(a,'message',{'id':tid,'text':'Ciao','reply':''});mid=next(t for t in s['threads'] if t['id']==tid)['messages'][-1]['id']
  await act(b,'react',{'id':mid,'emoji':'❤️'});s=await state(a);assert any(n['type']=='messageReaction' and n['ref']==mid for n in s['notifications'])
  await act(b,'read',{'id':mid});await act(a,'messageExpiry',{'id':tid,'seconds':0})
  await act(a,'note',{'text':'Nuovo giorno','audience':'mutual'});n=(await state(b))['notes'][0];await act(b,'noteReact',{'user':aid,'created':n['created'],'enabled':True})
  media=await upload();instant=(await send('/instants/send',{'media':media,'caption':'Un momento','audience':'friends','requestKey':'native55instant'},a)).json();iid=instant['id'];assert instant['expires']>time.time()+86390
  response=await client.get('/instants/'+iid+'/preview',headers=b);assert response.status_code==200
  await send('/instants/'+iid+'/open',{},b)
  archive=(await client.get('/instants/archive',headers=a)).json();assert archive['items'][0]['viewsCount']==1
  viewers=(await client.get('/instants/'+iid+'/viewers',headers=a)).json();assert viewers['total']==1 and viewers['items'][0]['user']==bid
  await send('/instants/'+iid+'/feedback',{'text':'❤️','kind':'reaction','requestKey':'native55feedback'},b)
  await send('/instants/'+iid+'/delete',{},a)
 print(f'PASS: {checks} richieste native al backend locale, più riscontri su pending, notifiche chat, scadenze e visualizzazioni')
asyncio.run(main())
