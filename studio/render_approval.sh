#!/bin/zsh
# Approval frames for the lighting pass: full 3D renders (ground truth), Station and Bill, day.
cd "${0:A:h}"
export TREATMENT=study LIGHTING=day
A=editorial/approval; mkdir -p $A/motion
r() { blender -b -P rig.py -- $1 $PWD/$2 2>&1 | grep -E "Traceback|WROTE"; }
for id in station bill; do
  LENS=50 HMS=10:09:36 RES=2400 SAMPLES=128 r $id $A/$id-full-1009.png
  LENS=50 HMS=2:11:40 RES=2400 SAMPLES=128 r $id $A/$id-full-crossing.png
  CAM="0.15,-0.19,0.43;0.03,-0.04,0.034" FOCUS="0.01,-0.01,0.034" FSTOP=11 LENS=75 HMS=2:11:40 RES=2400 SAMPLES=160 r $id $A/$id-closeup-crossing.png
done
# motion: same light, hands at sixteen different angles
for i in {0..15}; do
  m=$(( 609 + i * 47 )); h=$(( (m / 60) % 12 )); mm=$(( m % 60 )); s=$(( (i * 37) % 60 ))
  LENS=50 HMS=$h:$mm:$s RES=1400 SAMPLES=48 r station $A/motion/station-$(printf %02d $i).png
done
echo APPROVAL DONE
