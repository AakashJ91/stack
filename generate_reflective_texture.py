import math
import numpy as np
from PIL import Image, ImageFilter

def generate_reflective(size=512):
    """
    Generates a seamless, high-dynamic-range Reflective Mirror / Chrome texture.
    Features:
    - Seamless diagonal studio reflection softbox bands
    - Subtle optical chromatic dispersion prism fringe along reflection edges
    - High-gloss specular alpha map for razor-sharp chrome reflections
    """
    print("Generating seamless Reflective Mirror / Chrome texture...")
    np.random.seed(42)
    x = np.linspace(0, 2 * np.pi, size, endpoint=False)
    y = np.linspace(0, 2 * np.pi, size, endpoint=False)
    xx, yy = np.meshgrid(x, y)
    
    # 1. Seamless diagonal studio reflection banks
    # Primary softbox light band angled at 45 degrees
    diag1 = xx + yy
    # 2 smooth broad studio highlights across the tile
    band1 = np.sin(diag1 * 2.0) * 0.5 + 0.5
    band1 = np.power(band1, 6.0)
    
    # Secondary counter-diagonal rim highlight
    diag2 = xx - yy
    band2 = np.sin(diag2 * 3.0 + 1.2) * 0.5 + 0.5
    band2 = np.power(band2, 8.0) * 0.65
    
    # Combined studio streaks
    total_streaks = band1 + band2
    
    # 2. Chromatic optical dispersion on edges (prism fringe like luxury glass coating)
    r_channel = np.power(np.sin(diag1 * 2.0 + 0.08) * 0.5 + 0.5, 6.0) + band2 * 0.95
    g_channel = total_streaks
    b_channel = np.power(np.sin(diag1 * 2.0 - 0.08) * 0.5 + 0.5, 6.0) + band2 * 1.05
    
    # Base neutral silver tone (centered around 0.5 so it brightens highlights smoothly)
    r_val = np.clip(0.48 + r_channel * 0.50, 0.0, 1.0)
    g_val = np.clip(0.50 + g_channel * 0.48, 0.0, 1.0)
    b_val = np.clip(0.52 + b_channel * 0.46, 0.0, 1.0)
    
    # Alpha channel: Ultra-high specular gloss map (0.92 to 1.0)
    alpha_val = np.clip(0.92 + total_streaks * 0.08, 0.0, 1.0)
    
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    arr[:, :, 0] = (r_val * 255.0).astype(np.uint8)
    arr[:, :, 1] = (g_val * 255.0).astype(np.uint8)
    arr[:, :, 2] = (b_val * 255.0).astype(np.uint8)
    arr[:, :, 3] = (alpha_val * 255.0).astype(np.uint8)
    
    pil_img = Image.fromarray(arr, mode="RGBA")
    pil_img = pil_img.filter(ImageFilter.GaussianBlur(radius=1.0))
    pil_img.save("textures/skin_reflective.png")
    print("Saved textures/skin_reflective.png successfully!")

if __name__ == "__main__":
    generate_reflective()
