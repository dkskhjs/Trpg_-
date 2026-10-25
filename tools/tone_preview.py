"""초상화 색조 미리보기. godot/shaders/portrait.gdshader와 같은 공식이다.

    python3 tools/tone_preview.py [출력.jpg]
원본 | 포인트 색 | 창백 60% 를 인물별로 한 줄씩 그린다. 색을 바꾸려면 ACC와 main.gd의 PORTRAITS를 함께 고친다.
"""
import os
import sys
import numpy as np
from PIL import Image
P=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'godot','art','portraits')+'/'
ACC={'hero':None,'park':'#b8302b','myeongsu':'#6e7d3a','oh':'#c98a2e','cat':'#2a9e9b'}
INK=np.array([0.10,0.09,0.08]); PAPER=np.array([0.93,0.91,0.86])
def hexrgb(h): return np.array([int(h[i:i+2],16)/255 for i in (1,3,5)])
def tone(img, acc, strength=0.85, pale=0.0):
    a=np.asarray(img.convert('RGB'))/255.0
    l=a@np.array([0.299,0.587,0.114])
    l=np.clip((l-0.5)*1.15+0.5,0,1)[...,None]               # 대비 살짝
    gray=INK+(PAPER-INK)*l
    if acc is None: return gray
    c=hexrgb(acc)
    c=c+(PAPER-c)*pale                                      # 창백: 포인트 색이 빠진다
    lo=INK+(c-INK)*np.clip(l*2,0,1); hi=c+(PAPER-c)*np.clip(l*2-1,0,1)
    duo=np.where(l<0.5,lo,hi)
    return gray+(duo-gray)*strength
tiles=[]
for k,acc in ACC.items():
    im=Image.open(P+k+'.webp').convert('RGB').resize((300,402))
    for pale in (0.0,0.6):
        out=tone(im,acc,pale=pale)
        tiles.append(Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)))
    tiles.insert(len(tiles)-2, im)
W,H=300,402; cols=3; sheet=Image.new('RGB',(W*cols,H*len(ACC)),'black')
for i,t in enumerate(tiles): sheet.paste(t,((i%cols)*W,(i//cols)*H))
out=sys.argv[1] if len(sys.argv)>1 else 'tone_sheet.jpg'
sheet.save(out,quality=85); print(out)
