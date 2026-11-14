# Capacitor-এর android প্রজেক্টে অনুমতি, নিরাপত্তা সেটিং ও আইকন বসায়
import glob, math, os, re
from PIL import Image, ImageDraw
RED = (200, 16, 46, 255); WHITE = (255, 255, 255, 255)
RES = "android/app/src/main/res"; MAN = "android/app/src/main/AndroidManifest.xml"

def draw(size, scale, bg):
    S = size * 4; im = Image.new("RGBA", (S, S), bg); d = ImageDraw.Draw(im)
    cx = S / 2; k = S * scale; r = 0.26 * k; cc = S / 2 + 0.10 * k; py = S / 2 - 0.40 * k
    th = math.acos(r / (cc - py))
    d.polygon([(cx, py), (cx + r * math.sin(th), cc - r * math.cos(th)), (cx - r * math.sin(th), cc - r * math.cos(th))], fill=WHITE)
    d.ellipse([cx - r, cc - r, cx + r, cc + r], fill=WHITE)
    hr = 0.075 * k; hy = cc - 0.01 * k
    for sx in (-1, 1): d.ellipse([cx + sx * hr * 0.95 - hr, hy - hr, cx + sx * hr * 0.95 + hr, hy + hr], fill=RED)
    d.polygon([(cx - hr * 1.9, hy + hr * 0.25), (cx + hr * 1.9, hy + hr * 0.25), (cx, hy + hr * 2.5)], fill=RED)
    return im.resize((size, size), Image.LANCZOS)

def circle(im):
    m = Image.new("L", im.size, 0); ImageDraw.Draw(m).ellipse([0, 0, im.size[0] - 1, im.size[1] - 1], fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0)); out.paste(im, (0, 0), m); return out

for dens, a, f in [("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216), ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)]:
    d = f"{RES}/mipmap-{dens}"; os.makedirs(d, exist_ok=True)
    base = draw(a, 1.0, RED)
    base.save(f"{d}/ic_launcher.png"); circle(base).save(f"{d}/ic_launcher_round.png")
    draw(f, 0.58, (0, 0, 0, 0)).save(f"{d}/ic_launcher_foreground.png")

os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
xml = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n'
for n in ("ic_launcher.xml", "ic_launcher_round.xml"):
    open(f"{RES}/mipmap-anydpi-v26/{n}", "w").write(xml)

done = False
for p in glob.glob(f"{RES}/values*/*.xml"):
    t = open(p, encoding="utf-8").read()
    if 'name="ic_launcher_background"' in t:
        t = re.sub(r'(<color name="ic_launcher_background">)[^<]*(</color>)', r'\g<1>#C8102E\g<2>', t)
        open(p, "w", encoding="utf-8").write(t); done = True
if not done:
    os.makedirs(f"{RES}/values", exist_ok=True)
    open(f"{RES}/values/ic_launcher_background.xml", "w").write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#C8102E</color>\n</resources>\n')

m = open(MAN, encoding="utf-8").read()
perms = ""
for p in ("CAMERA", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION"):
    if f"android.permission.{p}" not in m: perms += f'    <uses-permission android:name="android.permission.{p}" />\n'
if "android.hardware.camera" not in m: perms += '    <uses-feature android:name="android.hardware.camera" android:required="false" />\n'
m = m.replace("</manifest>", perms + "</manifest>")
m = m.replace('android:allowBackup="true"', 'android:allowBackup="false"')
open(MAN, "w", encoding="utf-8").write(m)
print("android সেটআপ সম্পন্ন")
