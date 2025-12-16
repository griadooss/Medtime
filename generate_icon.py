#!/usr/bin/env python3
"""
Generate simple app icons for development.
Requires: pip install Pillow
"""

import os
from PIL import Image, ImageDraw, ImageFont

def generate_app_icon(app_name, symbol, bg_color, fg_color=(255, 255, 255), size=512):
    """
    Generate a simple app icon with colored background and symbol/text.
    
    Args:
        app_name: Name of the app (for filename)
        symbol: Symbol/emoji/letter to display
        bg_color: Background color (R, G, B) tuple
        fg_color: Foreground color (R, G, B) tuple, default white
        size: Icon size in pixels, default 512
    """
    # Create image with background color
    img = Image.new('RGB', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Try to use a font, fallback to default if not available
    try:
        # Try to use a system font
        font_size = int(size * 0.4)
        font = ImageFont.truetype("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            # Fallback to default font
            font = ImageFont.load_default()
            font_size = int(size * 0.3)
    
    # Get text bounding box to center it
    bbox = draw.textbbox((0, 0), symbol, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Center the text
    x = (size - text_width) / 2
    y = (size - text_height) / 2 - bbox[1]
    
    # Draw the symbol
    draw.text((x, y), symbol, fill=fg_color, font=font)
    
    # Create assets/icon directory if it doesn't exist
    os.makedirs('assets/icon', exist_ok=True)
    
    # Save the icon
    icon_path = f'assets/icon/app_icon.png'
    img.save(icon_path)
    print(f"✓ Generated {icon_path} for {app_name}")
    
    return icon_path

def main():
    print("Generating Medtime app icon...")
    
    # Medtime: Green background with pill symbol (💊 emoji or "M" letter)
    # Using green color similar to Colors.green[400] in Flutter
    # RGB: (76, 175, 80) is approximately Material green[400]
    generate_app_icon(
        app_name="Medtime",
        symbol="💊",  # Pill emoji
        bg_color=(76, 175, 80),  # Material green[400]
        fg_color=(255, 255, 255),  # White
        size=512
    )
    
    print("\nIcon generated! Update pubspec.yaml to use this icon.")
    print("For production, you may want to create a more polished icon.")

if __name__ == '__main__':
    main()

