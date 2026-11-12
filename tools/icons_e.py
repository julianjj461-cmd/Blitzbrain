"""Eigene Spiel-Symbole (kein Emoji-Vorbild): Maskottchen 'Blitzkopf', Strafzeit, Schwierigkeit. Im Text als ⟦name⟧ verwendbar."""
from icolib import *
K='#1a1033'
def head(face):
    s=[(P((13,0),(20,0),(17,7),(23,7),(11,16),(15,9),(9,9)),'#FFD23F'),(E(3,9,28,31),'#FFD23F')]
    return s+face
def cheeks(): return [(R(4,23,7,25),'#FF8FB1','f'),(R(24,23,27,25),'#FF8FB1','f')]
@icon('mascot')
def _(): return head([(E(8,15,14,23),K,'f'),(E(18,15,24,23),K,'f'),(R(10,16,11,18),'#FFFFFF','f'),(R(20,16,21,18),'#FFFFFF','f'),(R(10,26,21,27),K,'f'),(R(9,25,9,25),K,'f'),(R(22,25,22,25),K,'f')]+cheeks())
@icon('mascot_win')
def _(): return head([(R(8,18,9,18),K,'f'),(R(10,16,12,16),K,'f'),(R(13,18,14,18),K,'f'),(R(18,18,19,18),K,'f'),(R(20,16,22,16),K,'f'),(R(23,18,24,18),K,'f'),(E(9,15,22,30)&R(0,24,31,31),K,'f'),(E(12,26,19,32)&R(0,27,31,31),'#FF4D4D','f'),(STAR(4,6,3,1.2),'#FFFFFF','f') ]+cheeks())
@icon('mascot_sad')
def _(): return head([(E(8,16,14,23),K,'f'),(E(18,16,24,23),K,'f'),(R(10,17,11,19),'#FFFFFF','f'),(R(20,17,21,19),'#FFFFFF','f'),(L((7,13),(13,15),1),K,'f'),(L((24,13),(18,15),1),K,'f'),(R(11,27,20,27),K,'f'),(R(10,28,10,28),K,'f'),(R(21,28,21,28),K,'f'),(R(8,24,9,27),'#2EE6FF','f')]+cheeks())
@icon('pen')
def _(): return [(R(9,0,14,3),'#8c1d1d'),(E(0,4,25,29),'#FF4D4D'),(E(3,7,22,26),'#FFE3E3'),(L((12,16),(12,9),2),K,'f'),(L((12,16),(17,19),2),K,'f'),(E(17,-1,31,13),'#FFD23F'),(R(23,2,25,10),K,'f'),(R(20,5,28,7),K,'f')]
def _bolt(ox,oy,sc,c):
    pts=[(19,1),(7,17),(14,17),(10,31),(26,12),(18,12),(23,1)]
    return (P(*[(ox+(x-7)*sc,oy+(y-1)*sc) for x,y in pts]),c)
def _diff(n,c):
    s=[_bolt(6,1,.78,c)]
    for x in {1:[14],2:[10,18],3:[6,14,22]}[n]: s.append((R(x,26,x+4,30),c))
    return s
@icon('d1')
def _(): return _diff(1,'#3DFF8B')
@icon('d2')
def _(): return _diff(2,'#FFD23F')
@icon('d3')
def _(): return _diff(3,'#FF4D4D')
