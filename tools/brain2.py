from icolib import *
IC={}
def brain_shapes(face=False):
    f='#FF8FB1';d='#D9507F'
    body=E(2,6,16,20)|E(9,3,24,17)|E(15,7,30,22)|E(4,12,21,26)|E(11,11,27,26)
    s=[(R(13,24,17,30),'#E8798F'),(E(19,20,29,28),'#E8798F'),(body,f)]
    for pts in [[(5,16),(8,12),(12,13),(15,9),(19,10)],[(8,22),(11,18),(15,19),(18,15),(23,13),(27,15)],[(20,21),(23,19),(27,20)],[(7,9),(11,7),(15,6)]]:
        m=np.zeros((N,N),bool)
        for a,b in zip(pts,pts[1:]): m|=L(a,b,1)
        s.append((m,d,'f'))
    if face:
        s+=[(E(20,10,25,16),'#FFFFFF','f'),(R(23,12,24,15),'#1a1033','f'),(R(19,20,26,20),'#1a1033','f')]
        s.append((P((9,0),(5,8),(8,8),(6,14),(13,6),(10,6),(12,0)),'#FFD23F'))
    return s
IC['Gehirn (Seitenansicht)']=brain_shapes()
IC['Maskottchen Hirnblitz neu']=brain_shapes(True)
import os
from playwright.sync_api import sync_playwright
O='/tmp/claude-0/-home-claude/8486d080-b04a-5ac8-926a-c4c09e7d274f/scratchpad/ico/'
def cell(n):
    s=svg(render(IC[n]))
    return f'<div style="width:170px;text-align:center"><div style="width:160px;height:160px;margin:0 auto;border:1px solid #2a3a66;background:#0b0b14">{s}</div><div style="margin:3px 0">{n}</div><span style="display:inline-block;width:40px;height:40px">{s}</span> <span style="display:inline-block;width:24px;height:24px">{s}</span></div>'
open(O+'brain2.html','w').write('<meta charset="utf-8"><body style="margin:0;background:#0b0b14;color:#cfd3ea;font:12px monospace;padding:10px"><div style="display:flex;gap:12px">'+''.join(cell(n) for n in IC)+'</div></body>')
with sync_playwright() as p:
    b=p.chromium.launch();pg=b.new_page(viewport={'width':400,'height':290});pg.goto('file://'+O+'brain2.html');pg.screenshot(path=O+'brain2.png',full_page=True);b.close()
