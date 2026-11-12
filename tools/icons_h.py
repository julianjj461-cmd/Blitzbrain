"""ENTWURF Maskottchen-Alternativen (weg von Pikachu). Nicht im Export."""
from icolib import *
K='#1a1033';W='#FFFFFF';Y='#FFD23F'
def eyes(y=15,c=K,dx=0): return [(E(8-dx,y,14-dx,y+7),c,'f'),(E(18+dx,y,24+dx,y+7),c,'f'),(R(10-dx,y+1,11-dx,y+3),W,'f'),(R(20+dx,y+1,21+dx,y+3),W,'f')]
def smile(y=26): return [(R(12,y,19,y),K,'f'),(R(11,y-1,11,y-1),K,'f'),(R(20,y-1,20,y-1),K,'f')]
BOLT=[(19,1),(7,17),(14,17),(10,31),(26,12),(18,12),(23,1)]
def bolt(ox,oy,sc): return P(*[(ox+(x-7)*sc,oy+(y-1)*sc) for x,y in BOLT])
# 1 Cyan-Blitzkopf, kein Zacken, Blitz als Mal auf der Stirn
@icon('m1')
def _(): return [(E(2,2,29,30),'#2EE6FF'),(bolt(12,3,.45),Y,'f')]+eyes(14)+smile()
# 2 Violett mit Blitz-Brille
@icon('m2')
def _(): return [(E(2,2,29,30),'#8A5CFF'),(R(4,12,27,21),K,'f'),(P((9,12),(15,12),(12,17),(15,17),(8,24),(10,18),(7,18)),Y,'f'),(P((20,12),(26,12),(23,17),(26,17),(19,24),(21,18),(18,18)),Y,'f')]+smile(27)
# 3 Gehirn mit Gesicht und Blitz
@icon('m3')
def _(): return [(E(1,3,17,22),'#FF8FB1'),(E(14,3,30,22),'#FF8FB1'),(E(5,14,26,30),'#FF8FB1'),(L((16,4),(16,12),1),'#C9577F','f'),(L((7,8),(11,11),1),'#C9577F','f'),(L((24,8),(20,11),1),'#C9577F','f'),(L((5,16),(9,14),1),'#C9577F','f'),(L((26,16),(22,14),1),'#C9577F','f'),(E(9,15,14,21),K,'f'),(E(17,15,22,21),K,'f'),(R(10,16,11,17),W,'f'),(R(18,16,19,17),W,'f'),(R(13,25,18,25),K,'f'),(bolt(20,0,.35),Y)]
# 4 Blitz-Körper: der Körper ist der Blitz
@icon('m4')
def _(): return [(bolt(1,0,1.0),'#FF6B3D'),(E(9,9,13,13),K,'f'),(E(17,9,21,13),K,'f'),(R(10,10,10,10),W,'f'),(R(18,10,18,10),W,'f'),(R(12,16,15,16),K,'f')]
# 5 Funkenkugel (Plasma) mit Strahlen
@icon('m5')
def _(): return [(STAR(16,16,15.5,11,n=9),'#9BFF4D'),(E(6,6,25,25),'#4DDC6B'),(E(9,12,14,19),K,'f'),(E(17,12,22,19),K,'f'),(R(10,13,11,14),W,'f'),(R(18,13,19,14),W,'f'),(R(12,22,19,22),K,'f'),(R(11,21,11,21),K,'f'),(R(20,21,20,21),K,'f')]
# 6 Weiße Wolke/Gewitter mit Blitz
@icon('m6')
def _(): return [(E(1,8,15,22),'#C7D2EE'),(E(10,2,24,18),'#C7D2EE'),(E(17,8,31,22),'#C7D2EE'),(RR(3,14,28,24,4),'#C7D2EE'),(E(8,12,13,17),K,'f'),(E(18,12,23,17),K,'f'),(R(10,13,11,14),W,'f'),(R(20,13,21,14),W,'f'),(R(13,20,18,20),K,'f'),(bolt(13,21,.3),Y)]
# 7 Eule-Gehirn: orange Monster mit Hörnern und Blitzauge
@icon('m7')
def _(): return [(P((6,10),(4,0),(12,7)),'#FF6B3D'),(P((25,10),(27,0),(19,7)),'#FF6B3D'),(E(2,5,29,30),'#FF6B3D'),(E(6,12,14,22),W,'f'),(E(17,12,25,22),W,'f'),(R(9,15,11,19),K,'f'),(P((20,13),(24,13),(22,17),(24,17),(19,22),(20,18),(18,18)),Y,'f'),(R(10,26,21,26),K,'f'),(R(11,27,12,28),W,'f'),(R(19,27,20,28),W,'f')]
# 8 Pixel-Roboterkopf mit Blitzantenne
@icon('m8')
def _(): return [(R(15,0,16,6),'#6B7A99'),(bolt(12,0,.3),Y,'f'),(RR(3,7,28,30,3),'#6B7A99'),(RR(6,12,25,24,2),'#0F1B3D','f'),(R(9,15,13,19),'#2EE6FF','f'),(R(18,15,22,19),'#2EE6FF','f'),(R(11,21,20,22),'#2EE6FF','f'),(R(0,14,2,22),'#4C5878'),(R(29,14,31,22),'#4C5878')]
M=['m1','m2','m3','m4','m5','m6','m7','m8']
