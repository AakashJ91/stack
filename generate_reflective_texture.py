import math
import numpy as np
from PIL import Image, ImageFilter

def generate_reflective(size=512):
    print("Generating seamless Reflective Chrome / Mirror texture...")
    np.random.seed(777)
    
    # 1. Coordinate grids
    x = np.arange(size, dtype=np.float32)
    y = np.arange(size, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)
    
    # 2. Seamless periodic angle coordinates for mirror sheen
    # Diagonal studio soft reflection bands (period matching texture wrap)
    diag1 = (xx + yy * 0.75) / size
    # 3 major reflection bands across diagonal
    streak1 = np.sin(diag1 * np.pi * 4.0) * 0.5 + 0.5
    streak1 = np.power(streak1, 4.0) * 0.18
    
    # Counter-diagonal secondary highlight band
    diag2 = (xx * 0.65 - yy) / size
    streak2 = np.sin(diag2 * np.pi * 6.0 + 0.8) * 0.5 + 0.5
    streak2 = np.power(streak2, 5.0) * 0.12
    
    # 3. Ultra-subtle liquid mirror undulating micro-reflection
    # Using seamless sine/cosine harmonics
    liquid_wave = (
        np.sin(xx * (2 * np.pi / size) * 2.0) * np.cos(yy * (2 * np.pi / size) * 2.0) * 0.03 +
        np.sin((xx + yy) * (2 * np.pi / size) * 4.0) * 0.02
    )
    
    # 4. Chrome albedo: near-pure silver/white (0.86 to 0.98)
    albedo = np.clip(0.88 + streak1 + streak2 + liquid_wave, 0.0, 1.0)
    
    # 5. Mirror specular gloss in Alpha: nearly 1.0 everywhere, peaking at reflection streaks
    spec = np.clip(0.92 + streak1 * 0.35 + streak2 * 0.25, 0.0, 1.0)
    
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    # Neutral platinum/silver tone: R=0.98, G=0.99, B=1.00
    arr[:, :, 0] = np.clip(albedo * 0.98 * 255.0, 0, 255).astype(np.uint8)
    arr[:, :, 1] = np.clip(albedo * 0.99 * 255.0, 0, 255).astype(np.uint8)
    arr[:, :, 2] = np.clip(albedo * 1.00 * 255.0, 0, 255).astype(np.uint8)
    arr[:, :, 3] = np.clip(spec * 255.0, 0, 255).astype(np.uint8)
    
    pil_img = Image.fromarray(arr, mode="RGBA")
    pil_img = pil_img.filter(ImageFilter.GaussianBlur(radius=0.5))
    pil_img.save("textures/skin_reflective.png")
    print("Saved textures/skin_reflective.png successfully!")

if __name__ == "__main__":
    generate_reflective()
