from icolib import *
import icolib
from brain2 import brain_shapes
IC={}
# Maskottchen
f='#FF8FB1'
IC['A Hirnblitz']=brain_shapes(True)
IC['B Blitzkopf']=[(P((13,0),(20,0),(17,7),(23,7),(11,16),(15,9),(9,9)),'#FFD23F'),(E(3,9,28,31),'#FFD23F'),(E(8,15,14,23),'#1a1033','f'),(E(18,15,24,23),'#1a1033','f'),(R(10,16,11,18),'#FFFFFF','f'),(R(20,16,21,18),'#FFFFFF','f'),(R(10,26,21,27),'#1a1033','f'),(R(9,25,9,25),'#1a1033','f'),(R(22,25,22,25),'#1a1033','f'),(R(4,23,7,25),'#FF8FB1','f'),(R(24,23,27,25),'#FF8FB1','f')]
IC['C Zeitgeist']=[(R(13,0,18,4),'#C77700'),(R(6,24,10,31),'#2EE6FF'),(R(21,24,25,31),'#2EE6FF'),(E(2,3,29,29),'#FFC93C'),(E(5,6,26,26),'#F4F4FF'),(R(9,12,12,17),'#1a1033','f'),(R(19,12,22,17),'#1a1033','f'),(R(10,12,10,13),'#FFFFFF','f'),(R(20,12,20,13),'#FFFFFF','f'),(R(12,21,19,21),'#1a1033','f'),(R(11,20,11,20),'#1a1033','f'),(R(20,20,20,20),'#1a1033','f'),(P((12,-1),(17,-1),(15,4)),'#FFD23F') if False else (R(24,1,27,3),'#C77700')]
# Strafzeit
IC['Strafzeit']=[(R(9,0,14,3),'#8c1d1d'),(E(0,4,25,29),'#FF4D4D'),(E(3,7,22,26),'#FFE3E3'),(L((12,16),(12,9),2),'#1a1033','f'),(L((12,16),(17,19),2),'#1a1033','f'),(E(17,-1,31,13),'#FFD23F'),(R(23,2,25,10),'#1a1033','f'),(R(20,5,28,7),'#1a1033','f')]
# Schwierigkeit: Blitz + Pips
def bolt(ox,oy,sc,c):
    pts=[(19,1),(7,17),(14,17),(10,31),(26,12),(18,12),(23,1)]
    return (P(*[(ox+(x-7)*sc,oy+(y-1)*sc) for x,y in pts]),c)
def diff(n,c):
    s=[bolt(6,1,.78,c)]
    xs={1:[14],2:[10,18],3:[6,14,22]}[n]
    for x in xs: s.append((R(x,26,x+4,30),c))
    return s
IC['Leicht']=diff(1,'#3DFF8B');IC['Normal']=diff(2,'#FFD23F');IC['Hart']=diff(3,'#FF4D4D')
import os
from playwright.sync_api import sync_playwright
O='/tmp/claude-0/-home-claude/8486d080-b04a-5ac8-926a-c4c09e7d274f/scratchpad/ico/'
def cell(n):
    s=svg(render(IC[n]))
    return f'<div style="width:150px;text-align:center"><div style="width:128px;height:128px;margin:0 auto;border:1px solid #2a3a66;background:#0b0b14">{s}</div><div style="margin:3px 0">{n}</div><span style="display:inline-block;width:48px;height:48px">{s}</span> <span style="display:inline-block;width:32px;height:32px">{s}</span> <span style="display:inline-block;width:20px;height:20px">{s}</span></div>'
open(O+'ideen2.html','w').write('<meta charset="utf-8"><body style="margin:0;background:#0b0b14;color:#cfd3ea;font:12px monospace;padding:10px"><div style="display:flex;flex-wrap:wrap;gap:10px;width:640px">'+''.join(cell(n) for n in IC)+'</div></body>')
with sync_playwright() as p:
    b=p.chromium.launch();pg=b.new_page(viewport={'width':670,'height':400});pg.goto('file://'+O+'ideen2.html');pg.screenshot(path=O+'ideen2.png',full_page=True);b.close()
