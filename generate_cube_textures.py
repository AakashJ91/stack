import math
import numpy as np
from PIL import Image, ImageFilter

def generate_textures():
    size = 512
    img_albedo = np.zeros((size, size, 4), dtype=np.float32)
    img_normal = np.zeros((size, size, 3), dtype=np.float32)
    img_roughness = np.zeros((size, size), dtype=np.float32)
    
    # Coordinates
    x = np.arange(size)
    y = np.arange(size)
    xx, yy = np.meshgrid(x, y)
    
    # Distance to nearest square edge
    d_left = xx
    d_right = (size - 1) - xx
    d_top = yy
    d_bottom = (size - 1) - yy
    d_edge = np.minimum(np.minimum(d_left, d_right), np.minimum(d_top, d_bottom)).astype(np.float32)
    
    # Height map for normal calculation
    # Base height = 1.0
    height = np.ones((size, size), dtype=np.float32)
    
    # 1. Outer bevel: smooth slope from edge 0 to 18px
    bevel_w = 18.0
    bevel_factor = np.clip(d_edge / bevel_w, 0.0, 1.0)
    # Smooth Hermite
    bevel_slope = bevel_factor * bevel_factor * (3.0 - 2.0 * bevel_factor)
    height *= (0.75 + 0.25 * bevel_slope)
    
    # 2. Inset frame groove using rounded rectangle distance
    cx, cy = (size - 1) / 2.0, (size - 1) / 2.0
    px = np.abs(xx - cx)
    py = np.abs(yy - cy)
    
    # Inset rectangle dimensions
    inset_margin = 36.0
    corner_radius = 24.0
    box_w = (size / 2.0) - inset_margin - corner_radius
    box_h = (size / 2.0) - inset_margin - corner_radius
    
    dx = np.maximum(px - box_w, 0.0)
    dy = np.maximum(py - box_h, 0.0)
    dist_outside = np.sqrt(dx * dx + dy * dy)
    dist_inside = np.minimum(np.maximum(px - box_w, py - box_h), 0.0)
    sdf_corner = dist_outside + dist_inside - corner_radius
    
    # Groove profile around sdf = 0
    groove_width = 3.5
    groove_dist = np.abs(sdf_corner)
    groove_factor = np.clip(groove_dist / groove_width, 0.0, 1.0)
    groove_dip = 1.0 - (groove_factor * groove_factor * (3.0 - 2.0 * groove_factor))
    height -= groove_dip * 0.06
    
    # 3. Micro satin surface grain
    np.random.seed(42)
    noise_raw = np.random.normal(0.0, 1.0, (size, size)).astype(np.float32)
    # Normalize noise to 0..255 for GaussianBlur
    noise_u8 = ((noise_raw - noise_raw.min()) / (noise_raw.max() - noise_raw.min()) * 255.0).astype(np.uint8)
    pil_noise = Image.fromarray(noise_u8, mode="L")
    pil_noise = pil_noise.filter(ImageFilter.GaussianBlur(radius=1.2))
    noise_smooth = np.array(pil_noise).astype(np.float32) / 255.0
    noise_smooth = (noise_smooth - 0.5) * 0.03
    height += noise_smooth * 0.04
    
    # --- ALBEDO TEXTURE ---
    # High base value (0.94 - 1.0) so pastel tints stay vivid and luminous
    albedo = np.ones((size, size), dtype=np.float32) * 0.98
    
    # Edge ambient occlusion: soft shadowing near outer border
    ao_w = 20.0
    ao_factor = np.clip(d_edge / ao_w, 0.0, 1.0)
    ao = 0.88 + 0.12 * (ao_factor * ao_factor * (3.0 - 2.0 * ao_factor))
    albedo *= ao
    
    # Inset groove shadow & highlight
    albedo -= groove_dip * 0.07
    # Subtle inner face glow
    inner_glow = np.clip(1.0 - (sdf_corner / 60.0), 0.0, 1.0)
    inner_glow = inner_glow * (1.0 - inner_glow) * 0.04
    albedo += inner_glow
    
    # Subtle satin grain
    albedo += noise_smooth * 0.5
    albedo = np.clip(albedo, 0.0, 1.0)
    
    # RGBA
    img_albedo[:, :, 0] = albedo
    img_albedo[:, :, 1] = albedo
    img_albedo[:, :, 2] = albedo
    img_albedo[:, :, 3] = 1.0
    
    # --- NORMAL MAP ---
    # Compute height field gradients using central differences
    sobel_scale = 14.0
    grad_x = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * sobel_scale
    grad_y = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * sobel_scale
    
    # Clean edges
    grad_x[:, 0] = grad_x[:, 1]
    grad_x[:, -1] = grad_x[:, -2]
    grad_y[0, :] = grad_y[1, :]
    grad_y[-1, :] = grad_y[-2, :]
    
    # Normal vector = normalize(-grad_x, -grad_y, 1.0)
    # OpenGL format: Y+ is UP
    norm_x = -grad_x
    norm_y = grad_y # In OpenGL texture space, inverted for top-down image
    norm_z = np.ones((size, size), dtype=np.float32)
    
    norm_len = np.sqrt(norm_x * norm_x + norm_y * norm_y + norm_z * norm_z)
    norm_x /= norm_len
    norm_y /= norm_len
    norm_z /= norm_len
    
    img_normal[:, :, 0] = np.clip((norm_x * 0.5 + 0.5), 0.0, 1.0)
    img_normal[:, :, 1] = np.clip((norm_y * 0.5 + 0.5), 0.0, 1.0)
    img_normal[:, :, 2] = np.clip((norm_z * 0.5 + 0.5), 0.0, 1.0)
    
    # --- ROUGHNESS MAP ---
    # Satin baseline: 0.30
    # Outer bevel is slightly glossier (0.22) to catch glints
    # Inset groove is slightly rougher (0.44)
    roughness = np.ones((size, size), dtype=np.float32) * 0.30
    roughness = np.where(d_edge < bevel_w, 0.22 + 0.08 * (d_edge / bevel_w), roughness)
    roughness += groove_dip * 0.14
    roughness += noise_smooth * 0.4
    roughness = np.clip(roughness, 0.0, 1.0)
    
    # Save images
    pil_albedo = Image.fromarray((img_albedo * 255).astype(np.uint8), mode="RGBA")
    pil_normal = Image.fromarray((img_normal * 255).astype(np.uint8), mode="RGB")
    pil_roughness = Image.fromarray((roughness * 255).astype(np.uint8), mode="L")
    
    pil_albedo.save("textures/cube_albedo.png")
    pil_normal.save("textures/cube_normal.png")
    pil_roughness.save("textures/cube_roughness.png")
    print("Cube textures generated successfully in textures/ folder!")

if __name__ == "__main__":
    generate_textures()
