"""Eigene Spiel-Symbole (kein Emoji-Vorbild): Maskottchen 'Blitzkopf', Strafzeit, Schwierigkeit. Im Text als ⟦name⟧ verwendbar."""
from icolib import *
K='#1a1033'
PK='#FF8FB1';PD='#C9577F'
def brain():
    return [(E(1,9,12,21)|E(4,2,16,13)|E(15,2,27,13)|E(19,9,30,21)|E(3,7,28,31)|E(6,15,25,31),PK),(L((6,8),(9,11),1),PD,'f'),(L((9,5),(12,7),1),PD,'f'),(L((25,8),(22,11),1),PD,'f'),(L((22,5),(19,7),1),PD,'f'),(L((3,16),(6,14),1),PD,'f'),(L((28,16),(25,14),1),PD,'f'),
            (P((15,3),(18,3),(16,10),(19,10),(14,19),(15,12),(13,12)),'#FFD23F','f')]
def cheeks(): return [(R(4,24,7,25),'#FF4D8D','f'),(R(24,24,27,25),'#FF4D8D','f')]
@icon('mascot')
def _(): return brain()+[(E(8,19,13,25),K,'f'),(E(18,19,23,25),K,'f'),(R(9,20,10,21),'#FFFFFF','f'),(R(19,20,20,21),'#FFFFFF','f'),(R(14,28,17,28),K,'f'),(R(13,27,13,27),K,'f'),(R(18,27,18,27),K,'f')]+cheeks()
@icon('mascot_win')
def _(): return brain()+[(R(8,22,9,22),K,'f'),(R(10,20,12,20),K,'f'),(R(13,22,14,22),K,'f'),(R(18,22,19,22),K,'f'),(R(20,20,22,20),K,'f'),(R(23,22,24,22),K,'f'),(E(10,24,21,32)&R(0,26,31,31),K,'f'),(E(13,28,18,33)&R(0,29,31,31),'#FF4D4D','f'),(STAR(3,4,2.2,.9),'#FFFFFF','f'),(STAR(28,4,2.2,.9),'#FFFFFF','f')]+cheeks()
@icon('mascot_sad')
def _(): return brain()+[(E(8,20,13,26),K,'f'),(E(18,20,23,26),K,'f'),(R(9,21,10,22),'#FFFFFF','f'),(R(19,21,20,22),'#FFFFFF','f'),(L((7,20),(13,18),1),K,'f'),(L((24,20),(18,18),1),K,'f'),(R(13,29,18,29),K,'f'),(R(12,30,12,30),K,'f'),(R(19,30,19,30),K,'f'),(R(7,27,8,30),'#2EE6FF','f')]+cheeks()
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
