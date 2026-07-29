# LiquidMorphDiag

Tweak diagnostic doc lap — khong chua logic morph, chi log animation/layer that
ma SpringBoard tao ra khi mo/dong app, de xac dinh chinh xac class/keyPath can
nham toi cho du an LiquidMorph.

## Build

1. Push repo nay len GitHub.
2. GitHub Actions (.github/workflows/build.yml) tu build khi push vao main,
   hoac chay tay qua tab Actions -> Build LiquidMorphDiag -> Run workflow.
3. Tai file .deb tu muc Artifacts cua run vua chay.

Neu SDK version trong Makefile (TARGET = iphone:clang:16.5:14.0) khong khop
voi SDK co trong theos/sdks sau buoc cai dat, sua ca hai cho (Makefile va
build.yml) cho khop.

## Cai dat tren may

dpkg -i LiquidMorphDiag_1.0.0_iphoneos-arm64.deb
killall -9 SpringBoard

## Cach dung

1. Bat log truoc khi test (qua SSH):
   touch /var/jb/var/mobile/Documents/lm_diag_on   # rootless (Dopamine)
   hoac neu khong phai rootless:
   touch /var/mobile/Documents/lm_diag_on

2. Mo mot app tu Home Screen bang cach tap icon (hoac bam Home de dong).
3. Doi khoang 2 giay (cua so log dai 1.2s).
4. Keo log ve may:
   scp mobile@<ip>:/var/jb/var/mobile/Documents/LiquidMorphDiag.log ./
5. Tat log khi xong (xoa file flag):
   rm /var/jb/var/mobile/Documents/lm_diag_on

## Doc log

Moi lan test tao ra mot khoi tu "===== WINDOW OPEN =====" den
"===== WINDOW CLOSE =====". Trong khoi do, uu tien loc cac dong co
keyPath=transform, keyPath=position, hoac keyPath=bounds — day la ung vien
kha nghi nhat cho animation zoom that. Gui khoi log nay lai de phan tich tiep.

## Go cai dat

dpkg -r com.furina.liquidmorphdiag
killall -9 SpringBoard
