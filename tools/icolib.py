"""Pixel-Icon-Bibliothek: 32x32, Umriss + Licht/Schatten. Jedes Icon = Liste (Maske, Farbe[, Flag]); Flag 'f' = flach (ohne Umriss/Schatten)."""
import numpy as np, math, json
from PIL import Image, ImageDraw
N=32
def _m(): return Image.new('L',(N,N),0)
def _a(im): return np.array(im)>0
def P(*pts):
    im=_m();ImageDraw.Draw(im).polygon(list(pts),fill=255);return _a(im)
def E(x0,y0,x1,y1):
    im=_m();ImageDraw.Draw(im).ellipse([x0,y0,x1,y1],fill=255);return _a(im)
def R(x0,y0,x1,y1):
    m=np.zeros((N,N),bool);m[max(0,y0):y1+1,max(0,x0):x1+1]=True;return m
def RR(x0,y0,x1,y1,r=2):
    m=R(x0,y0,x1,y1)
    for cx,cy in [(x0,y0),(x1,y0),(x0,y1),(x1,y1)]:
        for dx in range(r):
            for dy in range(r):
                px=cx+(dx if cx==x0 else -dx);py=cy+(dy if cy==y0 else -dy)
                if dx+dy<r-1 or (dx+dy==r-1 and r>2 and False): m[py,px]=False
    return m
def L(p,q,w=2):
    im=_m();ImageDraw.Draw(im).line([p,q],fill=255,width=w);return _a(im)
def RING(cx,cy,ro,ri):
    y,x=np.mgrid[0:N,0:N];d=(x-cx)**2+(y-cy)**2;return (d<=ro*ro)&(d>=ri*ri)
def STAR(cx,cy,ro,ri,n=5,rot=-90):
    pts=[]
    for i in range(n*2):
        a=math.radians(rot+i*180/n);r=ro if i%2==0 else ri
        pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return P(*pts)
def pt(*xy):
    m=np.zeros((N,N),bool)
    for x,y in xy:
        if 0<=x<N and 0<=y<N:m[y,x]=True
    return m
def shift(m,dx,dy):
    o=np.zeros_like(m);ys,xs=np.nonzero(m)
    for y,x in zip(ys,xs):
        if 0<=y+dy<N and 0<=x+dx<N:o[y+dy,x+dx]=True
    return o
def dil(m): return m|shift(m,1,0)|shift(m,-1,0)|shift(m,0,1)|shift(m,0,-1)
def _hx(c):return np.array([int(c[i:i+2],16) for i in (1,3,5)],float)
def _mix(c,t,a):return tuple(((1-a)*_hx(c)+a*np.array(t)).astype(int))
OUT=(22,14,48)
def render(shapes):
    img=np.zeros((N,N,4),np.uint8)
    for sp in shapes:
        m,c=sp[0],sp[1];fl=len(sp)>2 and sp[2]=='f'
        if not fl: img[dil(m)&~m]=(*OUT,255)
        img[m]=(*_mix(c,(255,255,255),0),255)
        if not fl:
            light=_mix(c,(255,255,255),.45);dark=_mix(c,(0,0,0),.38)
            img[(m&~shift(m,-1,-1))]=(*dark,255);img[(m&~shift(m,1,1))]=(*light,255)
    return img
def svg(img):
    rows=[]
    for y in range(N):
        x=0
        while x<N:
            if img[y,x,3]==0:x+=1;continue
            c=tuple(int(v) for v in img[y,x,:3]);x2=x
            while x2+1<N and img[y,x2+1,3] and tuple(int(v) for v in img[y,x2+1,:3])==c:x2+=1
            rows.append(f'<rect x="{x}" y="{y}" width="{x2-x+1}" height="1" fill="#{c[0]:02x}{c[1]:02x}{c[2]:02x}"/>');x=x2+1
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" shape-rendering="crispEdges">'+''.join(rows)+'</svg>'
ICONS={}   # name -> shapes
EMAP={}    # emoji -> name
def icon(name,*emojis):
    def deco(f):
        ICONS[name]=f();
        for e in emojis:EMAP[e]=name
        return f
    return deco
def sheet(names,path,cols=6,scale=4):
    import os
    cells=''.join(f'<div style="width:{32*scale+8}px;text-align:center"><div style="width:{32*scale}px;height:{32*scale}px;margin:0 auto;border:1px solid #2a3a66;background:#0b0b14">{svg(render(ICONS[n]))}</div><span style="font-size:11px">{n}</span><br><span style="display:inline-block;width:32px;height:32px">{svg(render(ICONS[n]))}</span> <span style="display:inline-block;width:22px;height:22px">{svg(render(ICONS[n]))}</span></div>' for n in names)
    html=f'<body style="margin:0;background:#0b0b14;color:#bbb;font:11px monospace;padding:8px"><div style="display:flex;flex-wrap:wrap;gap:6px;width:{cols*(32*scale+14)}px">{cells}</div></body>'
    open(path+'.html','w').write(html)
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b=p.chromium.launch();pg=b.new_page(viewport={'width':cols*(32*scale+14)+20,'height':400},device_scale_factor=1)
        pg.goto('file://'+os.path.abspath(path+'.html'));pg.screenshot(path=path+'.png',full_page=True);b.close()
