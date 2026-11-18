"""Wordmark sprouts: each plant is anchored to a letter in em units, so it lines up at any size.
Writes src/brand-name.html (the inner HTML of .bname)."""
import math
G="var(--ground)"
def defs():
    return '''<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
<linearGradient id="bgM" x1="0" y1="0" x2="0" y2="-10" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#1F5530"/><stop offset="1" stop-color="#3F8A4C"/></linearGradient>
<linearGradient id="bgP" x1="-3" y1="0" x2="3" y2="-10" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#4E8E3C"/><stop offset="1" stop-color="#8CC45A"/></linearGradient>
<linearGradient id="bgF" x1="0" y1="0" x2="0" y2="-3" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#3A7A3E"/><stop offset="1" stop-color="#6DAA55"/></linearGradient>
<linearGradient id="bgS" x1="0" y1="0" x2="0" y2="-14" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#244F2C"/><stop offset="1" stop-color="#3E7A40"/></linearGradient>
<radialGradient id="bgE" cx="0" cy="0" r="5" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#CFE3D2"/><stop offset=".7" stop-color="#93B9A4"/><stop offset="1" stop-color="#7FA894"/></radialGradient>
<radialGradient id="bgR" cx="-.4" cy="-.4" r="1.3" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#B9DE97"/><stop offset="1" stop-color="#4E8A45"/></radialGradient>
</defs></svg>'''
def bez(p,t):
    (x0,y0),(x1,y1),(x2,y2),(x3,y3)=p;u=1-t
    x=u**3*x0+3*u*u*t*x1+3*u*t*t*x2+t**3*x3;y=u**3*y0+3*u*u*t*y1+3*u*t*t*y2+t**3*y3
    dx=3*u*u*(x1-x0)+6*u*t*(x2-x1)+3*t*t*(x3-x2);dy=3*u*u*(y1-y0)+6*u*t*(y2-y1)+3*t*t*(y3-y2)
    return x,y,math.degrees(math.atan2(dx,-dy))
MONSTERA=('<path d="M0-.5C-1 .4-5.6.2-6.1-3.4-6.5-6.6-3.6-9.6 0-10.1 3.6-9.6 6.5-6.6 6.1-3.4 5.6.2 1 .4 0-.5Z" fill="url(#bgM)"/>'
  f'<path d="M-6.2-3.2-1.6-2.4M-5.6-6.4-1.3-4.9M-3.3-9-1-7.2M6.2-3.2 1.6-2.4M5.6-6.4 1.3-4.9M3.3-9 1-7.2" stroke="{G}" stroke-width=".75" stroke-linecap="round"/>'
  f'<ellipse cx="-2.6" cy="-3.6" rx=".55" ry=".35" fill="{G}"/><ellipse cx="2.6" cy="-3.6" rx=".55" ry=".35" fill="{G}"/><ellipse cx="-2.3" cy="-6.6" rx=".45" ry=".3" fill="{G}"/><ellipse cx="2.3" cy="-6.6" rx=".45" ry=".3" fill="{G}"/>'
  '<path d="M0-.4V-9.6" stroke="#17401F" stroke-width=".35" opacity=".6"/>')
POTHOS=('<path d="M0 0C-1-.8-4-1.3-4-4.1-4-6.7-1.6-8.6 0-10 1.6-8.6 4-6.7 4-4.1 4-1.3 1-.8 0 0Z" fill="url(#bgP)"/>'
  '<path d="M-1.6-2.4C-2.6-4-2.2-6-1-7.4M1.2-3.2C2-4.4 2-5.8 1.4-6.8" stroke="#F1E6A6" stroke-width=".7" stroke-linecap="round" fill="none" opacity=".75"/>'
  '<path d="M0-.5V-9.2" stroke="#fff" stroke-width=".3" opacity=".5"/>')
PINNA='<path d="M0 0C-.9-.5-1-2-.1-3 .8-2 .8-.5 0 0Z" fill="url(#bgF)"/>'
def blade(h):
    return (f'<path d="M0 0C-1.6-{h*.35:.1f}-1.3-{h*.75:.1f} 0-{h} 1.3-{h*.75:.1f} 1.6-{h*.35:.1f} 0 0Z" fill="url(#bgS)" stroke="#D7D06A" stroke-width=".45"/>'
            + "".join(f'<path d="M-.9-{y:.1f}C-.3-{y+.5:.1f}.3-{y+.5:.1f}.9-{y:.1f}" stroke="#8DBE6A" stroke-width=".45" fill="none" opacity=".8"/>' for y in [h*f for f in (.2,.38,.56,.72)]))
PEARL='<circle cx="0" cy="0" r="1.15" fill="url(#bgR)"/><path d="M.9-.3 1.5-.6" stroke="#6E9E58" stroke-width=".3" stroke-linecap="round"/>'
def rosette():
    out=[]
    for ring,(n,L,w,c) in enumerate([(9,4.6,1.7,"#6E9F86"),(7,3.4,1.5,"#8DBBA0"),(5,2.2,1.2,"#B3D6BE")]):
        for k in range(n):
            a=360/n*k+ring*17
            out.append(f'<path transform="rotate({a:.0f})" d="M0 0C-{w}-{L*.4:.1f}-{w*.6:.1f}-{L*.85:.1f} 0-{L}C{w*.6:.1f}-{L*.85:.1f} {w}-{L*.4:.1f} 0 0Z" fill="{c}" stroke="#D99A9A" stroke-width=".25"/>')
    return "".join(out)
sprigs=[]; n=[0]
def sprig(letter,ax,ay,box,body,delay):
    """box=(minx,miny,w,h) in units where 10 = 1em; anchor (ax,ay) in em on the letter."""
    mx,my,w,h=box
    sprigs.append((letter,f'<svg class="sg{" front" if letter==4 else ""}" viewBox="{mx} {my} {w} {h}" style="left:calc({ax}em + {mx/10}em);top:calc({ay}em + {my/10}em);width:{w/10}em;height:{h/10}em;--sw:{(n[0]%2)*2-1}" aria-hidden="true"><g class="sp">{body(delay)}</g></svg>'))
    n[0]+=1
def stem(d,dl,dur,w=.7,c="#3B6B3E"):
    return f'<path class="st" d="{d}" pathLength="1" stroke="{c}" stroke-width="{w}" fill="none" stroke-linecap="round" style="--d:{dl}ms;--t:{dur}ms"/>'
def lf(x,y,r,s,dl,art):
    return f'<g transform="translate({x:.2f} {y:.2f}) rotate({r:.1f}) scale({s})"><g class="lf" style="--d:{dl}ms">{art}</g></g>'
# M: a monstera leaf on a curving petiole from the top of the left stroke
def m(dl):
    c=[(0,0),(-.5,-3),(-2.5,-5),(-3.6,-6.4)]
    return stem("M0 0C-.5-3-2.5-5-3.6-6.4",dl,420,.8)+lf(-3.6,-6.4,-38,.95,dl+260,MONSTERA)
sprig(0,.13,.16,(-12,-17,18,18),m,0)
# T: an arching fern frond from the right end of the crossbar
def t(dl):
    p=[(0,0),(2,-4),(6,-7),(10,-6.5)]; d="M0 0C2-4 6-7 10-6.5"
    s=stem(d,dl,520,.55,"#3A6E3C")
    for i,tt in enumerate([.18,.3,.42,.54,.66,.77,.87,.95]):
        x,y,a=bez(p,tt); sc=1.05-tt*.55
        s+=lf(x,y,a-62,sc,int(dl+520*tt),PINNA)+lf(x,y,a+62,sc,int(dl+520*tt)+30,PINNA)
    x,y,a=bez(p,1); s+=lf(x,y,a,.6,dl+500,PINNA)
    return s
sprig(8,.42,.17,(-2,-12,15,14),t,240)
# i: an echeveria rosette sitting on the dot
def i_(dl): return lf(0,0,0,1,dl,f'<g transform="scale(.72)">{rosette()}</g>')
sprig(4,.14,.27,(-5,-5,10,10),i_,170)
# y: string of pearls hanging from the tail
def y_(dl):
    p=[(0,0),(.8,3),(-.8,6),(.4,10)]; s=stem("M0 0C.8 3-.8 6 .4 10",dl,520,.35,"#5C8B4C")
    for k,tt in enumerate([.12,.27,.42,.56,.7,.84,.97]):
        x,y,_=bez(p,tt); s+=lf(x+(.5 if k%2 else -.5),y,0,1,int(dl+480*tt),PEARL)
    return s
sprig(6,.18,1.0,(-3,-1,6,13),y_,110)
# l: a snake plant clump behind the ascender
def l_(dl): return "".join(lf(x,0,r,1,dl+k*70,blade(h)) for k,(x,r,h) in enumerate([(-1.2,-16,9),(0,2,12.5),(1.3,18,8)]))
sprig(12,.12,.12,(-5,-14,10,15),l_,300)
# g: a pothos vine trailing from the descender
def g_(dl):
    p=[(0,0),(2,2.5),(5,3.5),(7,7.5)]; s=stem("M0 0C2 2.5 5 3.5 7 7.5",dl,480,.55)
    for tt,side,sc in [(.35,-110,.42),(.65,100,.5),(1,170,.6)]:
        x,y,a=bez(p,tt); s+=lf(x,y,a+side,sc,int(dl+480*tt),POTHOS)
    return s
sprig(11,.32,.98,(-1,-1,13,14),g_,360)
name="My Tiny Jungle"; parts=[]; by={l:h for l,h in sprigs}
for idx,ch in enumerate(name):
    parts.append(f'<span class="bl">{ch}{by[idx]}</span>' if idx in by else ch)
html="".join(parts)+defs()
open(__file__.rsplit("/",2)[0]+"/src/brand-name.html","w").write(html)
print(len(html))
