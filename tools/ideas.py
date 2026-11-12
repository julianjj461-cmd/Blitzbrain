from icolib import *
import icolib
IC={}
def add(n,shapes): IC[n]=shapes
# --- Maskottchen ---
f='#FF8FB1'
add('mascot_A: Hirnblitz',[(E(2,8,17,28),f),(E(14,8,29,28),f),(P((18,0),(13,8),(16,8),(14,13),(22,5),(18,5),(21,0)),'#FFD23F'),(E(7,15,13,21),'#FFFFFF','f'),(E(18,15,24,21),'#FFFFFF','f'),(R(10,17,12,20),'#1a1033','f'),(R(21,17,23,20),'#1a1033','f'),(R(12,24,19,24),'#1a1033','f'),(R(11,23,11,23),'#1a1033','f'),(R(20,23,20,23),'#1a1033','f')])
add('mascot_B: Blitzkopf',[(P((14,0),(21,0),(18,9),(24,9),(11,19),(14,10),(9,10)),'#FFD23F') if False else (P((15,0),(22,0),(19,8),(25,8),(12,18),(15,10),(10,10)),'#FFD23F'),(E(3,10,28,31),'#FFD23F'),(R(9,17,12,22),'#1a1033','f'),(R(19,17,22,22),'#1a1033','f'),(R(9,17,10,18),'#FFFFFF','f'),(R(19,17,20,18),'#FFFFFF','f'),(R(11,25,20,26),'#1a1033','f'),(R(10,24,10,24),'#1a1033','f'),(R(21,24,21,24),'#1a1033','f'),(R(5,23,8,24),'#FF8FB1','f'),(R(23,23,26,24),'#FF8FB1','f')])
add('mascot_C: Zeitgeist',[(R(13,0,18,4),'#C77700'),(R(6,22,10,30),'#2EE6FF'),(R(21,22,25,30),'#2EE6FF'),(E(2,3,29,28),'#FFC93C'),(E(5,6,26,25),'#F4F4FF'),(R(10,12,12,16),'#1a1033','f'),(R(19,12,21,16),'#1a1033','f'),(R(12,20,19,20),'#1a1033','f'),(R(11,19,11,19),'#1a1033','f'),(R(20,19,20,19),'#1a1033','f'),(P((25,2),(29,2),(29,6)),'#FF4D4D')])
# --- Strafzeit ---
add('Strafzeit (+)',[(R(10,0,15,3),'#8c1d1d'),(E(1,4,26,29),'#FF4D4D'),(E(4,7,23,26),'#FFE3E3'),(L((13,16),(13,9),2),'#1a1033','f'),(L((13,16),(18,19),2),'#1a1033','f'),(E(19,0,31,12),'#FFD23F'),(R(24,3,26,9),'#1a1033','f'),(R(22,5,28,7),'#1a1033','f')])
# --- Schwierigkeit ---
def bolt(ox,oy,sc,c):
    pts=[(19,1),(7,17),(14,17),(10,31),(26,12),(18,12),(23,1)]
    return (P(*[(ox+(x-7)*sc,oy+(y-1)*sc) for x,y in pts]),c)
add('Leicht',[bolt(10,4,.8,'#3DFF8B')])
add('Normal',[bolt(2,7,.7,'#FFD23F'),bolt(16,7,.7,'#FFD23F')])
add('Hart',[bolt(1,9,.55,'#FF4D4D'),bolt(11,9,.55,'#FF4D4D'),bolt(21,9,.55,'#FF4D4D')])
# --- Ligen ---
def shield(c,emb):
    s=[(P((16,1),(29,5),(28,18),(16,31),(4,18),(3,5)),c),(P((16,5),(25,8),(24,17),(16,27),(8,17),(7,8)),icolib._mix(c,(0,0,0),.25) and '#%02x%02x%02x'%icolib._mix(c,(0,0,0),.25),'f')]
    return s+emb
bo=[(P((17,8),(11,17),(15,17),(13,24),(21,14),(17,14),(20,8)),'#FFF1A8','f')]
add('Liga Bronze',shield('#CD7F32',bo))
add('Liga Silber',shield('#C9CCE0',bo))
add('Liga Gold',shield('#FFC93C',bo))
add('Liga Diamant',shield('#2EE6FF',[(P((10,10),(22,10),(25,15),(16,26),(7,15)),'#FFFFFF','f'),(R(8,15,24,15),'#2EE6FF','f'),(L((13,15),(16,25),1),'#2EE6FF','f'),(L((19,15),(16,25),1),'#2EE6FF','f')]))
# --- Serie ---
add('Serie 1 Tag',[(E(10,15,22,30),'#FF6A2B'),(P((16,10),(20,20),(12,20)),'#FF6A2B'),(E(13,21,19,30),'#FFC93C')])
add('Serie 7 Tage',[(E(5,10,27,31)|P((16,1),(23,14),(9,14)),'#FF6A2B'),(E(10,17,22,31),'#FFC93C'),(E(13,23,19,31),'#FFF1A8')])
add('Serie 30 Tage',[(E(5,13,27,31)|P((16,6),(23,17),(9,17)),'#2F8BFF'),(E(10,18,22,31),'#2EE6FF'),(E(13,24,19,31),'#FFFFFF'),(P((9,1),(9,7),(13,4),(16,7),(19,4),(23,7),(23,1)),'#FFC93C')])
# --- Regel-Bilder ---
add('Passt nicht',[(E(2,2,13,13),'#2EE6FF'),(E(18,2,29,13),'#2EE6FF'),(E(2,18,13,29),'#2EE6FF'),(E(18,18,29,29),'#FF3FA4')])
import random
r=random.Random(4)
dots=[(6,6),(14,5),(22,7),(9,13),(18,12),(26,14),(5,21),(13,20),(22,22),(10,27),(19,27)]
add('Zähl-Profi',[(E(x-2,y-2,x+2,y+2),'#FFD23F') for x,y in dots])
add('Größer-Duell',[(L((4,5),(18,16),4)|L((18,16),(4,27),4),'#FF3FA4'),(L((28,10),(21,16),3)|L((21,16),(28,22),3),'#2EE6FF')])
add('Spiegelbild',[(R(3,5,9,11),'#2EE6FF'),(R(3,14,12,19),'#2EE6FF'),(R(3,22,7,27),'#2EE6FF'),(R(22,5,28,11),'#FF3FA4'),(R(19,14,28,19),'#FF3FA4'),(R(24,22,28,27),'#FF3FA4'),(R(15,2,16,6),'#F4F4FF','f'),(R(15,9,16,13),'#F4F4FF','f'),(R(15,16,16,20),'#F4F4FF','f'),(R(15,23,16,27),'#F4F4FF','f')])
net=[(R(11,1,18,8),'#5EC8FF'),(R(11,10,18,17),'#3A8FD9'),(R(11,19,18,26),'#5EC8FF'),(R(3,10,10,17),'#8FE0FF'),(R(19,10,26,17),'#8FE0FF'),(R(11,28,18,30),'#3A8FD9')]
add('Würfel-Netz',[(R(11,0,18,7),'#5EC8FF'),(R(11,8,18,15),'#3A8FD9'),(R(11,16,18,23),'#5EC8FF'),(R(3,8,10,15),'#8FE0FF'),(R(19,8,26,15),'#8FE0FF'),(R(11,24,18,31),'#3A8FD9'),(R(14,11,15,12),'#F4F4FF','f'),(R(5,11,6,12),'#F4F4FF','f'),(R(22,11,23,12),'#F4F4FF','f')])
# --- Sheet ---
import os
from playwright.sync_api import sync_playwright
names=list(IC)
def cell(n):
    s=svg(render(IC[n]))
    return f'<div style="width:150px;text-align:center"><div style="width:128px;height:128px;margin:0 auto;border:1px solid #2a3a66;background:#0b0b14">{s}</div><div style="margin:3px 0">{n}</div><span style="display:inline-block;width:40px;height:40px">{s}</span> <span style="display:inline-block;width:24px;height:24px">{s}</span></div>'
html='<meta charset="utf-8"><body style="margin:0;background:#0b0b14;color:#cfd3ea;font:12px monospace;padding:10px"><div style="display:flex;flex-wrap:wrap;gap:10px;width:960px">'+''.join(cell(n) for n in names)+'</div></body>'
O='/tmp/claude-0/-home-claude/8486d080-b04a-5ac8-926a-c4c09e7d274f/scratchpad/ico/'
open(O+'ideen.html','w').write(html)
with sync_playwright() as p:
    b=p.chromium.launch();pg=b.new_page(viewport={'width':990,'height':400},device_scale_factor=1)
    pg.goto('file://'+O+'ideen.html');pg.screenshot(path=O+'ideen.png',full_page=True);b.close()
