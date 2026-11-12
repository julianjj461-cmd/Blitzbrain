"""ENTWURF Gehirn-Maskottchen, Varianten. Nicht im Export."""
from icolib import *
K='#1a1033';W='#FFFFFF';Y='#FFD23F'
BOLT=[(19,1),(7,17),(14,17),(10,31),(26,12),(18,12),(23,1)]
def bolt(ox,oy,sc): return P(*[(ox+(x-7)*sc,oy+(y-1)*sc) for x,y in BOLT])
def body(c,d,fis=True):
    s=[(E(0,8,11,21),c),(E(4,1,15,12),c),(E(16,1,27,12),c),(E(20,8,31,21),c),(RR(2,9,29,30,9),c)]
    if fis: s+=[(L((16,3),(16,9),1),d,'f'),(L((6,8),(9,11),1),d,'f'),(L((9,5),(12,7),1),d,'f'),(L((25,8),(22,11),1),d,'f'),(L((22,5),(19,7),1),d,'f'),(L((3,16),(6,14),1),d,'f'),(L((28,16),(25,14),1),d,'f')]
    return s
def eyes(dx=0): return [(E(9,15,14,21),K,'f'),(E(17,15,22,21),K,'f'),(R(10,16,11,17),W,'f'),(R(18,16,19,17),W,'f')]
def mouth(): return [(R(13,25,18,25),K,'f'),(R(12,24,12,24),K,'f'),(R(19,24,19,24),K,'f')]
def cheeks(c='#FF4D8D'): return [(R(5,22,8,23),c,'f'),(R(23,22,26,23),c,'f')]
@icon('v1')  # Blitz als Riss in der Mitte
def _(): return body('#FF8FB1','#C9577F',False)+[(P((15,3),(18,3),(16,10),(19,10),(14,19),(15,12),(13,12)),Y,'f'),(L((7,8),(11,11),1),'#C9577F','f'),(L((24,8),(20,11),1),'#C9577F','f')]+[(E(8,19,13,25),K,'f'),(E(18,19,23,25),K,'f'),(R(9,20,10,21),W,'f'),(R(19,20,20,21),W,'f'),(R(14,28,17,28),K,'f')]
@icon('v2')  # lila
def _(): return body('#A57BFF','#6A3FD1')+eyes()+mouth()+cheeks('#FF8FD8')+[(bolt(21,0,.33),Y)]
@icon('v3')  # cyan-gehirn
def _(): return body('#5EE6FF','#2B9FBF')+eyes()+mouth()+cheeks('#FFFFFF')+[(bolt(21,0,.33),Y)]
@icon('v4')  # cool, Sonnenbrille
def _(): return body('#FF8FB1','#C9577F')+[(R(5,15,26,21),K,'f'),(R(6,16,13,18),'#3B8BEB','f'),(R(18,16,25,18),'#3B8BEB','f'),(R(14,17,17,17),K,'f')]+mouth()+[(bolt(21,0,.33),Y)]
@icon('v5')  # mit Armen/Beinchen
def _(): return [(L((5,22),(1,27),2),'#C9577F'),(L((26,22),(30,27),2),'#C9577F'),(R(9,28,13,31),'#C9577F'),(R(18,28,22,31),'#C9577F')]+[(E(2,1,16,17),'#FF8FB1'),(E(15,1,29,17),'#FF8FB1'),(E(5,9,26,27),'#FF8FB1'),(L((16,2),(16,8),1),'#C9577F','f'),(L((7,5),(10,8),1),'#C9577F','f'),(L((24,5),(21,8),1),'#C9577F','f')]+[(E(9,12,14,18),K,'f'),(E(17,12,22,18),K,'f'),(R(10,13,11,14),W,'f'),(R(18,13,19,14),W,'f'),(R(13,21,18,21),K,'f'),(bolt(22,0,.3),Y,'f')]
@icon('v6')  # Blitz-Haare (drei Funken)
def _(): return body('#FF8FB1','#C9577F')+eyes()+mouth()+cheeks()+[(L((9,0),(12,3),1),Y,'f'),(L((16,-1),(16,3),1),Y,'f'),(L((23,0),(20,3),1),Y,'f')]
@icon('v7')  # eine Hälfte Gehirn, eine Hälfte Elektronik
def _(): return body('#FF8FB1','#C9577F')+[(R(16,3,30,30),'#6B7A99','f'),(E(19,15,25,21),'#2EE6FF','f'),(E(9,15,14,21),K,'f'),(R(10,16,11,17),W,'f'),(R(13,25,18,25),K,'f'),(R(18,7,26,8),'#2EE6FF','f'),(R(18,25,26,26),'#2EE6FF','f')]
@icon('v8')  # schlau: Brille + Blitz-Glühbirne
def _(): return body('#FF8FB1','#C9577F')+eyes()+[(RING(11.5,18,5,3),K,'f'),(RING(19.5,18,5,3),K,'f'),(R(16,17,16,17),K,'f')]+mouth()+[(E(11,-3,20,5),'#FFF3A0'),(bolt(12,-1,.2),Y,'f')]
V=['v1','v2','v3','v4','v5','v6','v7','v8']
