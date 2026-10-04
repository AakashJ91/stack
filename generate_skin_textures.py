import math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

def create_seamless_noise(size, octaves=4, seed=42):
    np.random.seed(seed)
    noise = np.zeros((size, size), dtype=np.float32)
    
    # Coordinates in 0..2pi for periodic toroid mapping
    x = np.linspace(0, 2 * np.pi, size, endpoint=False)
    y = np.linspace(0, 2 * np.pi, size, endpoint=False)
    xx, yy = np.meshgrid(x, y)
    
    for i in range(1, octaves + 1):
        freq = float(2 ** (i - 1))
        weight = 1.0 / freq
        # Periodic 2D sine/cosine Fourier components
        phase_x = np.random.uniform(0, 2 * np.pi)
        phase_y = np.random.uniform(0, 2 * np.pi)
        n = (np.sin(xx * freq + phase_x) * np.cos(yy * freq + phase_y) +
             np.sin((xx + yy) * freq * 0.7 + phase_x * 0.5)) * 0.5
        noise += n * weight
        
    # Normalize 0..1
    noise = (noise - noise.min()) / (noise.max() - noise.min() + 1e-6)
    return noise

def generate_marble(size=512):
    print("Generating seamless Marble Quartz texture...")
    # Base seamless multi-frequency noise
    n1 = create_seamless_noise(size, octaves=5, seed=101)
    n2 = create_seamless_noise(size, octaves=4, seed=202)
    
    # Domain warping
    x = np.arange(size)
    y = np.arange(size)
    xx, yy = np.meshgrid(x, y)
    
    # Warp coordinates periodically
    angle = 0.65
    coords = (xx * math.cos(angle) + yy * math.sin(angle)) / 28.0
    turb = (n1 - 0.5) * 8.0 + (n2 - 0.5) * 3.5
    
    # Vein profiles
    veins1 = np.abs(np.sin(coords + turb))
    veins1 = np.power(veins1, 0.45) # Sharp vein transition
    
    # Secondary fine veins
    coords2 = (xx * math.sin(angle) - yy * math.cos(angle)) / 18.0
    veins2 = np.abs(np.sin(coords2 + (n2 - 0.5) * 6.0))
    veins2 = np.power(veins2, 0.35)
    
    # Combine veins
    combined = veins1 * 0.75 + veins2 * 0.25
    
    # Albedo: clean bright stone base (0.96) with soft grey-taupe veins (0.68)
    albedo = 0.68 + 0.28 * combined
    
    # Subtle surface crystalline grain
    grain = (create_seamless_noise(size, octaves=6, seed=303) - 0.5) * 0.04
    albedo = np.clip(albedo + grain, 0.0, 1.0)
    
    # Specular / glossiness in Alpha: veins are slightly more matte (0.75), polished stone is glossier (0.95)
    spec = np.clip(0.70 + 0.28 * combined, 0.0, 1.0)
    
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[:, :, 0] = (albedo * 255).astype(np.uint8)
    img[:, :, 1] = (albedo * 255).astype(np.uint8)
    img[:, :, 2] = (albedo * 255).astype(np.uint8)
    img[:, :, 3] = (spec * 255).astype(np.uint8)
    
    pil_img = Image.fromarray(img, mode="RGBA")
    pil_img.save("textures/skin_marble.png")
    print("Saved textures/skin_marble.png")

def generate_wood(size=512):
    print("Generating seamless Nordic Wood Grain texture...")
    n1 = create_seamless_noise(size, octaves=5, seed=404)
    n2 = create_seamless_noise(size, octaves=3, seed=505)
    
    x = np.arange(size)
    y = np.arange(size)
    xx, yy = np.meshgrid(x, y)
    
    # Elongated periodic wood rings along Y axis
    # Periodic Y waviness
    y_wave = np.sin(yy * (2 * np.pi / size) * 3) * 12.0 + np.sin(yy * (2 * np.pi / size) * 7) * 5.0
    x_dist = xx + y_wave + (n1 - 0.5) * 24.0
    
    # Ring bands
    ring_freq = 0.09
    rings = np.sin(x_dist * ring_freq) * 0.5 + 0.5
    # Asymmetric wood growth cycle (steep earlywood, soft latewood)
    rings = np.power(rings, 0.7)
    
    # Fine vertical grain fibers (stretched noise)
    fiber_noise = np.random.normal(0.0, 1.0, (size // 8, size)).astype(np.float32)
    pil_fiber = Image.fromarray(((fiber_noise - fiber_noise.min()) / (fiber_noise.max() - fiber_noise.min()) * 255).astype(np.uint8))
    pil_fiber = pil_fiber.resize((size, size), Image.Resampling.BICUBIC)
    fibers = (np.array(pil_fiber).astype(np.float32) / 255.0 - 0.5) * 0.08
    
    # Plank seam line (subtle vertical groove every 256 pixels)
    seam = np.abs(np.sin(xx * (np.pi / (size / 2))))
    seam_dip = 1.0 - np.clip((1.0 - seam) * 18.0, 0.0, 1.0) * 0.12
    
    albedo = (0.75 + 0.22 * rings + fibers) * seam_dip
    albedo = np.clip(albedo, 0.0, 1.0)
    
    # Warm wood tint variation in green/blue channels for organic richness
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[:, :, 0] = np.clip(albedo * 255, 0, 255).astype(np.uint8)
    img[:, :, 1] = np.clip(albedo * 0.94 * 255, 0, 255).astype(np.uint8)
    img[:, :, 2] = np.clip(albedo * 0.86 * 255, 0, 255).astype(np.uint8)
    img[:, :, 3] = 255
    
    pil_img = Image.fromarray(img, mode="RGBA")
    pil_img.save("textures/skin_wood.png")
    print("Saved textures/skin_wood.png")

def generate_cyber(size=512):
    print("Generating seamless Cyber Grid texture...")
    # Base tech background (very clean dark carbon panel)
    img = Image.new("RGBA", (size, size), (220, 225, 235, 0))
    draw = ImageDraw.Draw(img)
    
    # Minor grid lines (every 32 px)
    for i in range(0, size, 32):
        draw.line([(i, 0), (i, size)], fill=(240, 245, 255, 40), width=1)
        draw.line([(0, i), (size, i)], fill=(240, 245, 255, 40), width=1)
        
    # Major grid lines (every 64 px)
    for i in range(0, size, 64):
        draw.line([(i, 0), (i, size)], fill=(255, 255, 255, 120), width=2)
        draw.line([(0, i), (size, i)], fill=(255, 255, 255, 120), width=2)
        
    # Circuit pads and tech nodes at major intersections
    pad_r = 5
    for x in range(0, size, 64):
        for y in range(0, size, 64):
            # Outer ring
            draw.ellipse([x - pad_r, y - pad_r, x + pad_r, y + pad_r], outline=(255, 255, 255, 220), width=2)
            # Center via
            draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255, 255))
            
    # Angled 45-degree circuit routes inside cells
    for x in range(0, size, 64):
        for y in range(0, size, 64):
            # Diagonal corner chamfer in each cell
            draw.line([(x + 12, y), (x, y + 12)], fill=(255, 255, 255, 140), width=2)
            draw.line([(x + 64 - 12, y), (x + 64, y + 12)], fill=(255, 255, 255, 140), width=2)
            
            # Decorative micro dots
            draw.point((x + 32, y + 32), fill=(255, 255, 255, 200))
            draw.point((x + 32, y + 31), fill=(255, 255, 255, 200))
            draw.point((x + 31, y + 32), fill=(255, 255, 255, 200))
            draw.point((x + 33, y + 32), fill=(255, 255, 255, 200))
            
    # Convert to numpy array to composite smooth glow and alpha
    arr = np.array(img).astype(np.float32)
    # The Alpha channel will serve directly as the glowing emission mask!
    # Base albedo: 0.90 for white lines, 0.70 for panels
    albedo = 0.72 + (arr[:, :, 3] / 255.0) * 0.28
    
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[:, :, 0] = (albedo * 255).astype(np.uint8)
    out[:, :, 1] = (albedo * 255).astype(np.uint8)
    out[:, :, 2] = (albedo * 255).astype(np.uint8)
    # Alpha = glow emission strength
    out[:, :, 3] = arr[:, :, 3].astype(np.uint8)
    
    pil_out = Image.fromarray(out, mode="RGBA")
    pil_out.save("textures/skin_cyber.png")
    print("Saved textures/skin_cyber.png")

def generate_terrazzo(size=512):
    print("Generating seamless Terrazzo Stone texture...")
    np.random.seed(808)
    img = Image.new("RGBA", (size, size), (242, 244, 248, 255))
    draw = ImageDraw.Draw(img)
    
    # Scatter 350 modern geometric stone chips
    num_chips = 320
    for _ in range(num_chips):
        cx = np.random.uniform(0, size)
        cy = np.random.uniform(0, size)
        chip_radius = np.random.exponential(scale=6.5) + 3.0
        chip_radius = min(chip_radius, 24.0)
        
        # 3 to 6 sided irregular polygon
        num_vertices = np.random.randint(3, 7)
        angles = np.sort(np.random.uniform(0, 2 * np.pi, num_vertices))
        radii = chip_radius * np.random.uniform(0.65, 1.25, num_vertices)
        
        # Chip shades: mix of slate dark, warm terracotta/sand, and pure white quartz
        palette_choice = np.random.choice(["dark", "warm", "white", "terracotta"], p=[0.25, 0.30, 0.25, 0.20])
        if palette_choice == "dark":
            val = np.random.randint(60, 110)
            col = (val, val + 5, val + 15, 255)
        elif palette_choice == "warm":
            val = np.random.randint(170, 215)
            col = (val + 10, val, val - 15, 255)
        elif palette_choice == "terracotta":
            r = np.random.randint(190, 230)
            col = (r, int(r * 0.72), int(r * 0.58), 255)
        else: # white quartz
            val = np.random.randint(245, 255)
            col = (val, val, val, 255)
            
        # Draw wrapped polygon for seamless edges
        for ox in [-size, 0, size]:
            for oy in [-size, 0, size]:
                poly = []
                for a, r in zip(angles, radii):
                    px = cx + ox + r * math.cos(a)
                    py = cy + oy + r * math.sin(a)
                    poly.append((px, py))
                draw.polygon(poly, fill=col)
                
    # Add subtle cement composite aggregate noise
    arr = np.array(img).astype(np.float32)
    noise = np.random.normal(0.0, 1.0, (size, size, 1)).astype(np.float32) * 5.0
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    
    pil_out = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    pil_out = pil_out.filter(ImageFilter.GaussianBlur(radius=0.4))
    pil_out.save("textures/skin_terrazzo.png")
    print("Saved textures/skin_terrazzo.png")

if __name__ == "__main__":
    generate_marble()
    generate_wood()
    generate_cyber()
    generate_terrazzo()
    print("All textures generated successfully!")
