"""Erzeugt den Icon-Block fuer index.html: python3 tools/export.py  (läuft von überall; schreibt in index.html zwischen den Markern)"""
import json,re,sys
import os;H=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,H)
import icons_a,icons_b,icons_c,icons_d,icons_e,icons_f
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
FB={'mascot':'⚡','mascot_win':'👑','mascot_sad':'😢','pen':'⏱','d1':'😌','d2':'😐','d3':'🔥'}
js="""/*PIXICON-START*/
/* Pixel-Icons: ersetzt bekannte Emojis in Texten durch eigene SVG-Icons (Automat: bunt, Synthwave: Neon-Linien, Terminal: Amber; zur Laufzeit aus denselben Pixeln berechnet). Quelle: tools/icons_*.py, Export: tools/export.py. Spielfeld (#stg) bleibt unberuehrt. */
const PIX=%s,PEM=%s,PFB=%s,PXC={};
function pxcol(n,ds){const d=PIX[n],pal=d[0],f=d[1],g=[];for(let i=0;i<f.length;i+=2)for(let c=0;c<f[i+1];c++)g.push(f[i]);
 if(!ds)return g.map(k=>k<0?null:'#'+pal[k]);
 const rgb=h=>[parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)],hex=a=>'#'+a.map(v=>Math.round(v).toString(16).padStart(2,'0')).join(''),mx=(a,b,t)=>a.map((v,i)=>v*(1-t)+b[i]*t);
 const info=pal.map(h=>{const [r,gg,b]=rgb(h),M=Math.max(r,gg,b),m=Math.min(r,gg,b),l=(M+m)/510,D=M-m;let s=D===0?0:D/255/(1-Math.abs(2*l-1)),hh=0;if(D){hh=M===r?((gg-b)/D%%6):M===gg?(b-r)/D+2:(r-gg)/D+4;hh=(hh*60+360)%%360}return{h:hh,s,l,lum:(.3*r+.59*gg+.11*b)/255,x:h==='160e30'}});
 const SY={m:'#ff2bd6',y:'#ffe600',c:'#00f0ff',v:'#a56bff',n0:'#6a4c9c',n1:'#c9b6ff',n2:'#ffffff'};
 const cl=g.map(k=>{if(k<0)return null;const q=info[k];if(q.x)return null;if(ds==='term')return 't';if(q.s<.18)return q.l<.25?'n0':q.l<.6?'n1':'n2';const h=q.h;return(h<20||h>=320)?'m':h<70?'y':h<210?'c':h<290?'v':'m'});
 const at=(x,y)=>x<0||y<0||x>31||y>31?null:cl[y*32+x];
 return cl.map((c,i)=>{if(!c)return null;const x=i%%32,y=i/32|0,nb=[at(x-1,y),at(x+1,y),at(x,y-1),at(x,y+1)];
  if(ds==='term'){if(nb.some(v=>!v))return'#ffb000';const L=info[g[i]].lum;return L<.25?'#3a2600':L<.5?'#8a5a00':L<.75?'#ffb000':'#ffe9a6'}
  return nb.some(v=>v!==c)?SY[c]:hex(mx(rgb(SY[c].slice(1)),[18,0,43],.82))})}
function pxsvg(n,ds){ds=ds===undefined?(document.documentElement.dataset.d||''):ds;const key=n+'|'+ds;if(PXC[key])return PXC[key];const col=pxcol(n,ds);let o='';for(let y=0;y<32;y++){let x=0;while(x<32){const c=col[y*32+x];if(!c){x++;continue}let x2=x;while(x2+1<32&&col[y*32+x2+1]===c)x2++;o+='<rect x="'+x+'" y="'+y+'" width="'+(x2-x+1)+'" height="1" fill="'+c+'"/>';x=x2+1}}return PXC[key]='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" shape-rendering="crispEdges">'+o+'</svg>'}
function pixSkin(){document.querySelectorAll('.pi').forEach(e=>{const n=e.dataset.n;if(n)e.innerHTML='<i class="pe">'+(e.dataset.e||'')+'</i>'+pxsvg(n)})}
{const re=new RegExp('(⟦[a-z0-9_]+⟧|'+Object.keys(PEM).join('|')+')\\\\uFE0F?','g');
 const st=document.createElement('style');st.textContent='.pi{display:inline-block;width:max(1.25em,18px);height:max(1.25em,18px);vertical-align:-.22em;font-style:normal;line-height:1}.pi svg{width:100%%;height:100%%;display:block}.pi .pe{display:none}html[data-d=synth] .pi svg{filter:drop-shadow(0 0 2px rgba(255,43,214,.65))}html[data-d=term] .pi svg{filter:drop-shadow(0 0 2px rgba(255,176,0,.5))}';document.head.appendChild(st);
 const skip=p=>!p||/^(SCRIPT|STYLE|TEXTAREA|INPUT|OPTION|TITLE)$/.test(p.nodeName)||(p.closest&&p.closest('.pi,#stg'));
 function pix(n){if(n.nodeType===3){const s=n.nodeValue;re.lastIndex=0;if(!re.test(s)){re.lastIndex=0;return}re.lastIndex=0;const p=n.parentNode;if(skip(p))return;
   const f=document.createDocumentFragment();let last=0,m;
   while((m=re.exec(s))){if(m.index>last)f.appendChild(document.createTextNode(s.slice(last,m.index)));const sp=document.createElement('span');sp.className='pi';const tk=m[1][0]==='⟦',nm=tk?m[1].slice(1,-1):PEM[m[1]];if(tk&&!PIX[nm]){f.appendChild(document.createTextNode(PFB[nm]||''));last=re.lastIndex;continue}const pe=tk?(PFB[nm]||''):m[1];sp.dataset.n=nm;sp.dataset.e=pe;sp.innerHTML='<i class="pe">'+pe+'</i>'+pxsvg(nm);f.appendChild(sp);last=re.lastIndex}
   re.lastIndex=0;if(last<s.length)f.appendChild(document.createTextNode(s.slice(last)));p.replaceChild(f,n)}
  else if(n.nodeType===1&&!skip(n)&&n.id!=='stg'){[...n.childNodes].forEach(pix)}}
 new MutationObserver(ms=>{for(const m of ms){if(m.type==='characterData')pix(m.target);else m.addedNodes.forEach(pix)}}).observe(document.body,{childList:true,subtree:true,characterData:true});
 new MutationObserver(()=>pixSkin()).observe(document.documentElement,{attributes:true,attributeFilter:['data-d']});
 pix(document.body)}
/*PIXICON-END*/
"""%(json.dumps(S,ensure_ascii=False,separators=(',',':')),json.dumps(M,ensure_ascii=False,separators=(',',':')),json.dumps(FB,ensure_ascii=False,separators=(',',':')))
t=open(H+'/../index.html').read()
if '/*PIXICON-START*/' not in t: a=t.index('/* Pixel-Icons (Test)');b=t.index("const BBV=")
else: a=t.index('/*PIXICON-START*/');b=t.index('/*PIXICON-END*/')+len('/*PIXICON-END*/\n')
t=t[:a]+js+t[b:]
open(H+'/../index.html','w').write(t)
print(len(S),'Icons',len(M),'Emojis',len(js)//1024,'KB')
