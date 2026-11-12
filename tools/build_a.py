import icons_a,icons_b,icons_c
from icolib import *
O='/tmp/claude-0/-home-claude/8486d080-b04a-5ac8-926a-c4c09e7d274f/scratchpad/ico/'
names=list(ICONS)
i=names.index('cross')
sheet(names[i:i+30],O+'c1',cols=6,scale=3)
sheet(names[i+30:],O+'c2',cols=6,scale=3)
print(len(names))
