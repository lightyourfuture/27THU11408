# 生成双链表后插 4 步的 TikZ 图
def node(n, lab, x, y, fill):
    return (f"\\node[c] ({n}P) at ({x-0.6},{y}) {{}};"
            f"\\node[c,minimum width=8mm,fill={fill}] ({n}D) at ({x},{y}) {{\\textsf{{{lab}}}}};"
            f"\\node[c] ({n}N) at ({x+0.6},{y}) {{}};")
# 箭头定义：名字 -> tikz path
A = {
 'xy': r"\draw[a] ([yshift=1.2mm]xN.center) -- ([yshift=1.2mm]yP.west);",
 'yx': r"\draw[a] ([yshift=-1.2mm]yP.center) -- ([yshift=-1.2mm]xN.east);",
 'ey': r"\draw[a,NEW] (eN.center) to[out=0,in=-100] ([xshift=-1mm]yP.south);",
 'ye': r"\draw[a,NEW] ([xshift=1mm]yP.south) to[out=-80,in=0] (eN.east);",
 'ex': r"\draw[a,NEW] (eP.center) to[out=180,in=-80] ([xshift=1mm]xN.south);",
 'xe': r"\draw[a,NEW] ([xshift=-1mm]xN.south) to[out=-100,in=180] (eP.west);",
}
def old(s): return s.replace(',NEW','')
steps = [
 ("初始：p 指向 x，s 指向新结点 e", ['xy','yx'], None),
 ("{\\cjk ①} s->next = p->next;", ['xy','yx','ey'], 'ey'),
 ("{\\cjk ②} p->next->prior = s;", ['xy','ey','ye'], 'ye'),
 ("{\\cjk ③} s->prior = p;", ['xy','ey','ye','ex'], 'ex'),
 ("{\\cjk ④} p->next = s;", ['ey','ye','ex','xe'], 'xe'),
]
out = [r"""\documentclass[border=4pt]{standalone}
\usepackage{xeCJK}\setCJKmainfont{Noto Sans CJK SC}\setCJKsansfont{Noto Sans CJK SC}
\newfontfamily\cjk{Noto Sans CJK SC}\usepackage{tikz}\usetikzlibrary{arrows.meta,positioning}
\begin{document}\begin{tikzpicture}[
 c/.style={draw,minimum width=4mm,minimum height=6mm,inner sep=0,fill=gray!25},
 a/.style={-{Stealth[length=2mm]},thick,black!70},
 NEW/.style={red!80!black,very thick},
 font=\small]"""]
for i,(cap,arrs,new) in enumerate(steps):
    ox = (i%2)*7.5; oy = -(i//2)*4.4
    out.append(f"\\begin{{scope}}[shift={{({ox},{oy})}}]")
    out.append(node('x','x',0,0,'orange!45'))
    out.append(node('y','y',4,0,'orange!45'))
    out.append(node('e','e',2,-1.5,'violet!35'))
    out.append(r"\node[below=1mm of xD] {\footnotesize p};" if False else r"\draw[a,black] (0,0.9) node[above]{\footnotesize p} -- (xD.north);")
    out.append(r"\draw[a,black] (2,-2.4) node[below]{\footnotesize s} -- (eD.south);")
    for k in arrs:
        out.append(A[k] if k==new else old(A[k]))
    out.append(f"\\node[anchor=west,font=\\ttfamily\\small] at (-1,1.55) {{{cap.replace('->','{-}>')}}};" if i else f"\\node[anchor=west] at (-1,1.55) {{{cap}}};")
    out.append(r"\end{scope}")
# 第 6 格：整理后
out.append(r"\begin{scope}[shift={(7.5,-8.8)}]")
out.append(node('x','x',0,-0.6,'orange!45')); out.append(node('e','e',2.2,-0.6,'violet!35')); out.append(node('y','y',4.4,-0.6,'orange!45'))
for u,v in [('x','e'),('e','y')]:
    out.append(f"\\draw[a] ([yshift=1.2mm]{u}N.center) -- ([yshift=1.2mm]{v}P.west);")
    out.append(f"\\draw[a] ([yshift=-1.2mm]{v}P.center) -- ([yshift=-1.2mm]{u}N.east);")
out.append(r"\node[anchor=west] at (-1,1.55) {完成：e 插在 x 与 y 之间，双向都连好};")
out.append(r"\end{scope}")
out.append(r"\end{tikzpicture}\end{document}")
open('dins.tex','w').write('\n'.join(out))
