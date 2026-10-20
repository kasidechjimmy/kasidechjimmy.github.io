"""Make the web portrait, images/profile.jpg, from an original photo.

What it does, in order:
  1. opens the photo (an iPhone HEIC, or a JPEG or PNG) and turns it upright;
  2. converts its colours to standard web colour (sRGB). iPhones save photos
     in "Display P3", which browsers would otherwise show slightly duller;
  3. cuts out a 4:5 portrait at the place you choose (see below);
  4. resizes it to 960 x 1200 pixels, sharp on high-resolution screens;
  5. saves a JPEG with NO metadata: the camera data, including the GPS
     location where the photo was taken, the date and the phone model, is
     left out.

Run it in the website folder (uv fetches Pillow for this one run):

  uv run --with pillow --with pillow-heif python scripts/make-portrait.py "IMG_3541 3.heic" images/profile.jpg 0.504 0.26 0.693

The three numbers choose the crop, each as a fraction of the photo:
  centre  (0.504)  the crop's horizontal centre: 0 is the left edge, 1 the right
  top     (0.26)   the crop's top edge: 0 is the top of the photo, 1 the bottom
  width   (0.693)  the crop's width as a share of the photo's width; the height
                   follows from the 4:5 shape
If the crop would run off the photo, the script stops and says so: use a
smaller width, or move the centre or the top.

Keep original photos out of the website folder, or rely on the *.heic rule in
.gitignore, so that they never reach the public repository.
"""
import io
import sys

from PIL import Image, ImageCms, ImageOps
from pillow_heif import register_heif_opener

SIZE = (960, 1200)  # output width x height in pixels (4:5)


def main(argv):
    if len(argv) != 6:
        sys.exit(__doc__)
    src, out = argv[1], argv[2]
    centre, top, width = (float(v) for v in argv[3:6])

    register_heif_opener()  # lets Pillow open .heic files
    im = ImageOps.exif_transpose(Image.open(src))  # upright, as the phone shows it
    icc = im.info.get("icc_profile")
    im = im.convert("RGB")
    if icc:  # e.g. Display P3 -> sRGB
        im = ImageCms.profileToProfile(
            im, ImageCms.ImageCmsProfile(io.BytesIO(icc)),
            ImageCms.createProfile("sRGB"), outputMode="RGB")

    full_w, full_h = im.size
    w = round(full_w * width)
    h = round(w * 5 / 4)
    x0 = round(full_w * centre - w / 2)
    y0 = round(full_h * top)
    if x0 < 0 or y0 < 0 or x0 + w > full_w or y0 + h > full_h:
        sys.exit(f"The crop ({w} x {h} pixels at {x0}, {y0}) runs off the photo "
                 f"({full_w} x {full_h}). Use a smaller width, or move the centre or the top.")

    # No exif= and no icc_profile= argument, so the JPEG carries no metadata.
    im.crop((x0, y0, x0 + w, y0 + h)).resize(SIZE, Image.LANCZOS).save(
        out, "JPEG", quality=84, optimize=True, progressive=True)

    check = Image.open(out)
    print(f"Saved {out}: {check.size[0]} x {check.size[1]} pixels, cut from the "
          f"{full_w} x {full_h} photo at ({x0}, {y0}, {x0 + w}, {y0 + h}); "
          f"metadata tags in the file: {len(check.getexif())}.")


if __name__ == "__main__":
    main(sys.argv)
