#!/usr/bin/env python3
# =============================================================================
# img_from_hex.py
# Reconstructs a black-and-white classified image from simulation results
#
# Reads results.hex produced by tb_nn_rgb_image.v and reconstructs
# the image so you can visually verify the traffic sign was detected.
# Also overlays the original image side-by-side for easy comparison.
#
# Usage:
#   python3 img_from_hex.py --results results.hex \
#                           --original traffic_sign.jpg \
#                           --width 64 --height 64 \
#                           --output classified.png
# =============================================================================

import argparse
from PIL import Image, ImageDraw, ImageFont

def reconstruct_image(results_path, original_path, output_path, width, height):

    total_pixels = width * height

    # -------------------------------------------------------------------------
    # Read results.hex
    # Each line is one byte: FF = white pixel, 00 = black pixel
    # -------------------------------------------------------------------------
    pixels_out = []
    with open(results_path, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                val = int(line, 16)
                pixels_out.append(255 if val >= 128 else 0)

    if len(pixels_out) != total_pixels:
        print(f"  WARNING: expected {total_pixels} pixels, got {len(pixels_out)}")

    # -------------------------------------------------------------------------
    # Reconstruct classified image (grayscale: 255=white, 0=black)
    # -------------------------------------------------------------------------
    classified_img = Image.new("RGB", (width, height))
    for idx, val in enumerate(pixels_out):
        x = idx % width
        y = idx // width
        classified_img.putpixel((x, y), (val, val, val))

    # Scale up for visibility (nearest neighbor to keep pixel art look)
    scale = max(1, 256 // width)
    classified_img = classified_img.resize(
        (width * scale, height * scale), Image.NEAREST)

    # -------------------------------------------------------------------------
    # Load and resize original image for side-by-side comparison
    # -------------------------------------------------------------------------
    original_img = Image.open(original_path).convert("RGB")
    original_img = original_img.resize((width, height), Image.LANCZOS)
    original_img = original_img.resize(
        (width * scale, height * scale), Image.NEAREST)

    # -------------------------------------------------------------------------
    # Create side-by-side comparison image with labels
    # -------------------------------------------------------------------------
    label_height = 30
    combined_width  = original_img.width * 2 + 20   # 10px gap
    combined_height = original_img.height + label_height

    combined = Image.new("RGB", (combined_width, combined_height), (40, 40, 40))

    # Paste original on left, classified on right
    combined.paste(original_img,   (0, label_height))
    combined.paste(classified_img, (original_img.width + 20, label_height))

    # Add text labels
    draw = ImageDraw.Draw(combined)
    draw.rectangle([(0, 0), (combined_width, label_height)], fill=(40, 40, 40))
    draw.text((10, 8),                              "Original",    fill=(255, 255, 255))
    draw.text((original_img.width + 30, 8),        "NN Output",   fill=(255, 255, 255))

    combined.save(output_path)

    # -------------------------------------------------------------------------
    # Statistics
    # -------------------------------------------------------------------------
    white_count = pixels_out.count(255)
    black_count = pixels_out.count(0)
    print(f"  Results file  : {results_path}")
    print(f"  Image size    : {width} x {height} = {total_pixels} pixels")
    print(f"  White pixels  : {white_count}  ({100*white_count//total_pixels}%)")
    print(f"  Black pixels  : {black_count}  ({100*black_count//total_pixels}%)")
    print(f"  Output saved  : {output_path}")

# =============================================================================
# Main
# =============================================================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Reconstruct classified image from nn_rgb simulation results")
    parser.add_argument("--results",  required=True, help="results.hex from simulation")
    parser.add_argument("--original", required=True, help="Original input image")
    parser.add_argument("--output",   required=True, help="Output comparison image (png)")
    parser.add_argument("--width",    type=int, default=64, help="Image width  (default: 64)")
    parser.add_argument("--height",   type=int, default=64, help="Image height (default: 64)")
    args = parser.parse_args()

    reconstruct_image(args.results, args.original,
                      args.output, args.width, args.height)
