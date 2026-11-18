"""Generates the growing-plants wordmark overlay (src/brand-leaves.svg.html)."""
import math
def bez(p, t):
    (x0,y0),(x1,y1),(x2,y2),(x3,y3)=p; u=1-t
    x=u**3*x0+3*u*u*t*x1+3*u*t*t*x2+t**3*x3; y=u**3*y0+3*u*u*t*y1+3*u*t*t*y2+t**3*y3
    dx=3*u*u*(x1-x0)+6*u*t*(x2-x1)+3*t*t*(x3-x2); dy=3*u*u*(y1-y0)+6*u*t*(y2-y1)+3*t*t*(y3-y2)
    return x,y,math.degrees(math.atan2(dx,-dy))  # angle relative to "up"
LEAF={
 "monstera":('<path d="M0 0C-7.5-1.5-9-9.5-4-12.6-2-13.6 0-11.8 0-11.8S2-13.6 4-12.6C9-9.5 7.5-1.5 0 0Z" fill="url(#gM)"/>'
             '<path d="M-1.2-2.6-5.4-6.2M-1-6-5.6-9.8M1.2-2.6 5.4-6.2M1-6 5.6-9.8" stroke="var(--ground)" stroke-width=".9" stroke-linecap="round"/>'
             '<path d="M0-.6V-11" stroke="#1f4a2a" stroke-width=".5" opacity=".5"/>'),
 "pothos":('<path d="M0 0C-5.2-.6-6-6.4 0-11.2 6-6.4 5.2-.6 0 0Z" fill="url(#gP)"/><path d="M0-.8V-10" stroke="#fff" stroke-width=".45" opacity=".55"/>'
           '<path d="M-2.2-3.8C-2.8-5.6-1.6-7.2-.6-8" stroke="#F4E9A8" stroke-width=".8" stroke-linecap="round" opacity=".6" fill="none"/>'),
 "basil":('<path d="M0 0C-3.6-2.4-3.4-7 0-9.4 3.4-7 3.6-2.4 0 0Z" fill="url(#gB)"/><path d="M0-.6V-8.6" stroke="#fff" stroke-width=".4" opacity=".6"/>'),
 "pinna":('<path d="M0 0C-1.4-.8-1.6-3-.2-4.6 1.2-3 1.2-.8 0 0Z" fill="url(#gF)"/>'),
 "blade":('<path d="M0 0C-2.2-6-1.8-13 0-18.5 1.8-13 2.2-6 0 0Z" fill="url(#gS)"/>'
          '<path d="M-1.1-4.5 1-5.3M-1.3-8.5 1.2-9.3M-1.1-12.5.9-13.2" stroke="#C9DE8C" stroke-width=".55" opacity=".8" stroke-linecap="round"/>'),
 "pearl":('<circle cx="0" cy="-1.7" r="1.7" fill="url(#gR)"/><circle cx="-.5" cy="-2.2" r=".45" fill="#fff" opacity=".7"/>'),
}
out=[]; n=[0]
def leaf(kind,x,y,rot,s,delay):
    out.append(f'<g transform="translate({x:.2f} {y:.2f}) rotate({rot:.1f}) scale({s})"><g class="lf" style="--d:{delay}ms">{LEAF[kind]}</g></g>')
def stem(ox,oy,ctrl,delay,dur,leaves,width=1.1,color="#3E6B3F"):
    pts=[(0,0)]+ctrl
    d="M0 0C"+" ".join(f"{a} {b}" for a,b in ctrl)
    out.append(f'<g class="sp" transform="translate({ox} {oy})" style="--d:{delay}ms;--sw:{(n[0]%2)*2-1}">')
    out.append(f'<path class="st" d="{d}" pathLength="1" stroke="{color}" stroke-width="{width}" fill="none" stroke-linecap="round" style="--d:{delay}ms;--t:{dur}ms"/>')
    for kind,t,side,s in leaves:
        x,y,a=bez(pts,t); leaf(kind,x,y,a+side,s,int(delay+dur*t*0.9))
    out.append('</g>'); n[0]+=1
# Coordinates: viewBox 0 0 160 60; letters sit about y 23..38.
stem(9,25,[(-1,-6),(-7,-9),(-8,-17)],0,560,[("pothos",.42,62,.62),("monstera",1,-8,1.0)])
stem(47,24,[(0,-6),(2,-12),(5,-19)],90,600,[("pinna",t,s*70,.9) for t in (.3,.45,.6,.75,.88) for s in (-1,1)]+[("pinna",1,0,1)])
stem(93,24,[(3,-5),(9,-8),(12,-15)],170,560,[("pothos",.45,-70,.7),("pothos",.72,72,.8),("pothos",1,0,.95)])
for i,(r,s) in enumerate([(-22,.8),(0,1.05),(19,.72)]): leaf("blade",141,26,r,s,230+i*60)
stem(36,37,[(2,5),(-2,10),(1,16)],260,620,[("pearl",t,0,.95) for t in (.25,.42,.58,.72,.86,1)],width=.6,color="#5C8B4C")
stem(116,37,[(3,4),(7,7),(9,13)],320,520,[("basil",.5,-120,.55),("basil",.8,110,.6),("basil",1,180,.7)],width=.8)
defs='''<defs>
<linearGradient id="gM" x1="0" y1="0" x2="0" y2="-13" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#2F6B3A"/><stop offset="1" stop-color="#4E9A55"/></linearGradient>
<linearGradient id="gP" x1="-4" y1="0" x2="4" y2="-11" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#5E9B45"/><stop offset="1" stop-color="#9CCB63"/></linearGradient>
<linearGradient id="gB" x1="0" y1="0" x2="0" y2="-9" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#4C8F3E"/><stop offset="1" stop-color="#8FC66A"/></linearGradient>
<linearGradient id="gF" x1="0" y1="0" x2="0" y2="-5" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#2F5D3A"/><stop offset="1" stop-color="#5E9B5A"/></linearGradient>
<linearGradient id="gS" x1="0" y1="0" x2="0" y2="-18" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#2E5B34"/><stop offset=".8" stop-color="#4F8A45"/><stop offset="1" stop-color="#B8CF6A"/></linearGradient>
<radialGradient id="gR" cx="-.4" cy="-2.2" r="2.2" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#A8D48A"/><stop offset="1" stop-color="#4E8A45"/></radialGradient>
</defs>'''
svg=f'<svg class="bleaves" viewBox="0 0 160 60" aria-hidden="true" focusable="false">{defs}{"".join(out)}</svg>'
open(__file__.rsplit("/",2)[0]+"/src/brand-leaves.svg.html","w").write(svg)
print(len(svg))
