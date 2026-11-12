"""Erzeugt den Icon-Block fuer index.html: python3 tools/export.py  (läuft von überall; schreibt in index.html zwischen den Markern)"""
import json,re,sys
import os;H=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,H)
import icons_a,icons_b,icons_c,icons_d
from icolib import *
def enc(img):
    pal=[];flat=[];last=None;cnt=0
    for y in range(N):
        for x in range(N):
            if img[y,x,3]==0:k=-1
            else:
                c='%02x%02x%02x'%tuple(int(v) for v in img[y,x,:3])
                if c not in pal:pal.append(c)
                k=pal.index(c)
            if k==last:cnt+=1
            else:
                if last is not None:flat+=[last,cnt]
                last=k;cnt=1
    flat+=[last,cnt]
    return [pal,flat]
S={n:enc(render(sh)) for n,sh in ICONS.items()}
M={e.replace('️',''):n for e,n in EMAP.items()}
js="""/*PIXICON-START*/
/* Pixel-Icons: ersetzt bekannte Emojis in Texten durch eigene SVG-Icons (nur Automat-Design; sonst bleibt das Emoji). Quelle: tools/icons_*.py, Export: tools/export.py. Spielfeld (#stg) bleibt unberuehrt. */
const PIX=%s,PEM=%s,PXC={};
function pxsvg(n){if(PXC[n])return PXC[n];const d=PIX[n],pal=d[0],f=d[1];let o='',p=0;for(let i=0;i<f.length;i+=2){let k=f[i],c=f[i+1];while(c>0){const x=p%%32,y=p/32|0,l=Math.min(c,32-x);if(k>=0)o+='<rect x="'+x+'" y="'+y+'" width="'+l+'" height="1" fill="#'+pal[k]+'"/>';p+=l;c-=l}}return PXC[n]='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" shape-rendering="crispEdges">'+o+'</svg>'}
{const re=new RegExp('('+Object.keys(PEM).join('|')+')\\\\uFE0F?','g');
 const st=document.createElement('style');st.textContent='.pi{display:inline-block;width:max(1.25em,18px);height:max(1.25em,18px);vertical-align:-.22em;font-style:normal;line-height:1}.pi svg{width:100%%;height:100%%;display:block}.pi .pe{display:none}html[data-d] .pi svg{display:none}html[data-d] .pi .pe{display:inline;font-size:1em}';document.head.appendChild(st);
 const skip=p=>!p||/^(SCRIPT|STYLE|TEXTAREA|INPUT|OPTION|TITLE)$/.test(p.nodeName)||(p.closest&&p.closest('.pi,#stg'));
 function pix(n){if(n.nodeType===3){const s=n.nodeValue;re.lastIndex=0;if(!re.test(s)){re.lastIndex=0;return}re.lastIndex=0;const p=n.parentNode;if(skip(p))return;
   const f=document.createDocumentFragment();let last=0,m;
   while((m=re.exec(s))){if(m.index>last)f.appendChild(document.createTextNode(s.slice(last,m.index)));const sp=document.createElement('span');sp.className='pi';sp.innerHTML='<i class="pe">'+m[1]+'</i>'+pxsvg(PEM[m[1]]);f.appendChild(sp);last=re.lastIndex}
   re.lastIndex=0;if(last<s.length)f.appendChild(document.createTextNode(s.slice(last)));p.replaceChild(f,n)}
  else if(n.nodeType===1&&!skip(n)&&n.id!=='stg'){[...n.childNodes].forEach(pix)}}
 new MutationObserver(ms=>{for(const m of ms){if(m.type==='characterData')pix(m.target);else m.addedNodes.forEach(pix)}}).observe(document.body,{childList:true,subtree:true,characterData:true});
 pix(document.body)}
/*PIXICON-END*/
"""%(json.dumps(S,ensure_ascii=False,separators=(',',':')),json.dumps(M,ensure_ascii=False,separators=(',',':')))
t=open(H+'/../index.html').read()
if '/*PIXICON-START*/' not in t: a=t.index('/* Pixel-Icons (Test)');b=t.index("const BBV=")
else: a=t.index('/*PIXICON-START*/');b=t.index('/*PIXICON-END*/')+len('/*PIXICON-END*/\n')
t=t[:a]+js+t[b:]
open(H+'/../index.html','w').write(t)
print(len(S),'Icons',len(M),'Emojis',len(js)//1024,'KB')
