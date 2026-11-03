# 报告每页正文栏底部空白比例（最后一页除外）
import sys,glob,subprocess,tempfile,os
from PIL import Image
for pdf in sys.argv[1:]:
    d=tempfile.mkdtemp()
    subprocess.run(['pdftoppm','-r','30','-gray','-png',pdf,d+'/p'],check=True)
    fs=sorted(glob.glob(d+'/p-*.png'))
    out=[]
    for k,f in enumerate(fs[:-1]):
        im=Image.open(f).convert('L'); w,h=im.size
        x0=int(w*0.35); x1=int(w*0.93); top=int(h*0.08); bot=int(h*0.90)
        px=im.load(); last=top
        for y in range(top,bot):
            if any(px[x,y]<200 for x in range(x0,x1,2)): last=y
        frac=(bot-last)/(bot-top)
        if frac>0.18: out.append(f'p{k+1}:{frac:.0%}')
    print(os.path.basename(pdf), len(fs), ' '.join(out))
