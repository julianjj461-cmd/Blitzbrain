import icons_a,icons_b,icons_c,icons_d
from icolib import *
O='/tmp/claude-0/-home-claude/8486d080-b04a-5ac8-926a-c4c09e7d274f/scratchpad/ico/'
names=list(ICONS)
i=names.index('bottle')
sheet(names[i:],O+'d1',cols=6,scale=3)
print(len(names))
