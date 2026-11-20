"""Render the repository's simple node-graph mark to platform icon sizes.

Development-only dependency: Pillow. No runtime image downloads.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
image = Image.new("RGB", (1024, 1024), "#176b4b")
draw = ImageDraw.Draw(image)
nodes = [(512, 280), (300, 430), (365, 705), (720, 415), (685, 710)]
for point in nodes:
    draw.line([(512, 512), point], fill="#d9edaa", width=22)
for x, y, radius in [(512, 512, 110)] + [(x, y, 53) for x, y in nodes]:
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill="#d9edaa")

android = ROOT / "android/app/src/main/res"
for density, pixels in {"mdpi":48, "hdpi":72, "xhdpi":96, "xxhdpi":144, "xxxhdpi":192}.items():
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(android / f"mipmap-{density}/ic_launcher.png")
ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for icon in json.loads((ios / "Contents.json").read_text())["images"]:
    pixels = round(float(icon["size"].split("x")[0]) * float(icon["scale"].rstrip("x")))
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ios / icon["filename"])
