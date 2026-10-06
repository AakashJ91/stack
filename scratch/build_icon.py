import math

def build_5tier_icon_svg():
    width = 512
    height = 512

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <!-- Background Space Gradient -->
    <radialGradient id="bgRadial" cx="50%" cy="32%" r="80%">
      <stop offset="0%" stop-color="#26125c"/>
      <stop offset="35%" stop-color="#160c3b"/>
      <stop offset="70%" stop-color="#0b0621"/>
      <stop offset="100%" stop-color="#050312"/>
    </radialGradient>

    <!-- Squircle Border Rim -->
    <linearGradient id="squircleBorder" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.5"/>
      <stop offset="25%" stop-color="#f472b6" stop-opacity="0.3"/>
      <stop offset="60%" stop-color="#38bdf8" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0.12"/>
    </linearGradient>

    <!-- Squircle Subtle Inner Bevel -->
    <linearGradient id="squircleGloss" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.14"/>
      <stop offset="30%" stop-color="#ffffff" stop-opacity="0.02"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.35"/>
    </linearGradient>

    <!-- Radiant Nebula Aura behind Stack -->
    <radialGradient id="nebulaAura" cx="50%" cy="45%" r="52%">
      <stop offset="0%" stop-color="#c084fc" stop-opacity="0.38"/>
      <stop offset="35%" stop-color="#f43f5e" stop-opacity="0.22"/>
      <stop offset="70%" stop-color="#38bdf8" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>

    <!-- Pedestal / Floor Shadow -->
    <radialGradient id="floorShadow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#000000" stop-opacity="0.85"/>
      <stop offset="50%" stop-color="#030014" stop-opacity="0.55"/>
      <stop offset="80%" stop-color="#6366f1" stop-opacity="0.15"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>

    <!-- Inter-block Ambient Shadow -->
    <radialGradient id="blockAO" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#000000" stop-opacity="0.75"/>
      <stop offset="65%" stop-color="#000000" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>

    <!-- Glass Specular Highlight Streak -->
    <linearGradient id="glassStreak" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.65"/>
      <stop offset="30%" stop-color="#ffffff" stop-opacity="0.2"/>
      <stop offset="65%" stop-color="#ffffff" stop-opacity="0.0"/>
    </linearGradient>

    <!-- ===================================== -->
    <!-- TIER PALETTES (5 Distinct Rich Tiers) -->
    <!-- ===================================== -->

    <!-- TIER 1: ROYAL SAPPHIRE / INDIGO (Base) -->
    <linearGradient id="t1_top" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#4f46e5"/>
      <stop offset="50%" stop-color="#4338ca"/>
      <stop offset="100%" stop-color="#3730a3"/>
    </linearGradient>
    <linearGradient id="t1_left" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#28207e"/>
      <stop offset="100%" stop-color="#17124f"/>
    </linearGradient>
    <linearGradient id="t1_right" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#3730a3"/>
      <stop offset="100%" stop-color="#1e1b4b"/>
    </linearGradient>

    <!-- TIER 2: DEEP AMETHYST / NEON PURPLE -->
    <linearGradient id="t2_top" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#a855f7"/>
      <stop offset="50%" stop-color="#9333ea"/>
      <stop offset="100%" stop-color="#7e22ce"/>
    </linearGradient>
    <linearGradient id="t2_left" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#581c87"/>
      <stop offset="100%" stop-color="#3b0764"/>
    </linearGradient>
    <linearGradient id="t2_right" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#7e22ce"/>
      <stop offset="100%" stop-color="#581c87"/>
    </linearGradient>

    <!-- TIER 3: VIVID NEON CORAL / MAGENTA -->
    <linearGradient id="t3_top" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ff3b81"/>
      <stop offset="50%" stop-color="#f43f5e"/>
      <stop offset="100%" stop-color="#e11d48"/>
    </linearGradient>
    <linearGradient id="t3_left" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#9f1239"/>
      <stop offset="100%" stop-color="#4c0519"/>
    </linearGradient>
    <linearGradient id="t3_right" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#e11d48"/>
      <stop offset="100%" stop-color="#881337"/>
    </linearGradient>

    <!-- TIER 4: ELECTRIC CYAN / NEON AZURE -->
    <linearGradient id="t4_top" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="50%" stop-color="#0ea5e9"/>
      <stop offset="100%" stop-color="#0284c7"/>
    </linearGradient>
    <linearGradient id="t4_left" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0369a1"/>
      <stop offset="100%" stop-color="#075985"/>
    </linearGradient>
    <linearGradient id="t4_right" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0ea5e9"/>
      <stop offset="100%" stop-color="#0369a1"/>
    </linearGradient>

    <!-- TIER 5: RADIANT SUN GOLD / AMBER CROWN -->
    <linearGradient id="t5_top" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fff59d"/>
      <stop offset="35%" stop-color="#fde047"/>
      <stop offset="70%" stop-color="#facc15"/>
      <stop offset="100%" stop-color="#eab308"/>
    </linearGradient>
    <linearGradient id="t5_left" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#b45309"/>
      <stop offset="100%" stop-color="#78350f"/>
    </linearGradient>
    <linearGradient id="t5_right" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#f59e0b"/>
      <stop offset="100%" stop-color="#b45309"/>
    </linearGradient>

    <!-- Sparkle Radial Auras -->
    <radialGradient id="sparkleAuraGold" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="1"/>
      <stop offset="25%" stop-color="#fef08a" stop-opacity="0.85"/>
      <stop offset="55%" stop-color="#f59e0b" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#f59e0b" stop-opacity="0"/>
    </radialGradient>

    <radialGradient id="sparkleAuraCyan" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="1"/>
      <stop offset="30%" stop-color="#38bdf8" stop-opacity="0.75"/>
      <stop offset="65%" stop-color="#0284c7" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#0284c7" stop-opacity="0"/>
    </radialGradient>

    <radialGradient id="sparkleAuraPink" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="1"/>
      <stop offset="30%" stop-color="#ff7da7" stop-opacity="0.75"/>
      <stop offset="65%" stop-color="#e11d48" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#e11d48" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <!-- ========================================== -->
  <!-- SQUIRCLE FRAMEWORK                         -->
  <!-- ========================================== -->
  <rect width="512" height="512" rx="116" ry="116" fill="url(#bgRadial)"/>
  <rect width="512" height="512" rx="116" ry="116" fill="url(#squircleGloss)"/>
  <rect width="506" height="506" x="3" y="3" rx="113" ry="113" fill="none" stroke="url(#squircleBorder)" stroke-width="2.5"/>

  <!-- Cosmic Nebula Back-light -->
  <circle cx="256" cy="270" r="225" fill="url(#nebulaAura)"/>

  <!-- Pedestal Floor Shadow -->
  <ellipse cx="256" cy="452" rx="160" ry="46" fill="url(#floorShadow)"/>

  <!-- ========================================== -->
  <!-- TIER 1: ROYAL SAPPHIRE (Base)              -->
  <!-- cx=256, cy=388, dx=136, dy=68, h=36        -->
  <!-- ========================================== -->
  <g id="tier_1">
    <!-- Left Face: (120, 388) -> (256, 456) -> (256, 492) -> (120, 424) -->
    <polygon points="120,388 256,456 256,492 120,424" fill="url(#t1_left)"/>
    <!-- Right Face: (256, 456) -> (392, 388) -> (392, 424) -> (256, 492) -->
    <polygon points="256,456 392,388 392,424 256,492" fill="url(#t1_right)"/>
    <!-- Top Face: (256, 320) -> (392, 388) -> (256, 456) -> (120, 388) -->
    <polygon points="256,320 392,388 256,456 120,388" fill="url(#t1_top)"/>
    <!-- Top Face Glass Reflection -->
    <polygon points="188,354 256,320 304,344 236,378" fill="url(#glassStreak)" opacity="0.4"/>
    <!-- Bevel Highlights -->
    <polyline points="120,388 256,320 392,388" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-opacity="0.55" stroke-linejoin="round"/>
    <polyline points="120,388 256,456 392,388" fill="none" stroke="#ffffff" stroke-width="1.3" stroke-opacity="0.3" stroke-linejoin="round"/>
    <line x1="256" y1="456" x2="256" y2="492" stroke="#ffffff" stroke-width="1.3" stroke-opacity="0.3"/>
  </g>

  <!-- ========================================== -->
  <!-- TIER 2: DEEP AMETHYST                      -->
  <!-- cx=254, cy=340, dx=122, dy=61, h=35        -->
  <!-- ========================================== -->
  <g id="tier_2">
    <ellipse cx="256" cy="388" rx="104" ry="38" fill="url(#blockAO)" opacity="0.65"/>
    <!-- Left Face: (132, 340) -> (254, 401) -> (254, 436) -> (132, 375) -->
    <polygon points="132,340 254,401 254,436 132,375" fill="url(#t2_left)"/>
    <!-- Right Face: (254, 401) -> (376, 340) -> (376, 375) -> (254, 436) -->
    <polygon points="254,401 376,340 376,375 254,436" fill="url(#t2_right)"/>
    <!-- Top Face: (254, 279) -> (376, 340) -> (254, 401) -> (132, 340) -->
    <polygon points="254,279 376,340 254,401 132,340" fill="url(#t2_top)"/>
    <!-- Top Face Glass -->
    <polygon points="193,310 254,279 300,302 239,333" fill="url(#glassStreak)" opacity="0.45"/>
    <!-- Bevel Highlights -->
    <polyline points="132,340 254,279 376,340" fill="none" stroke="#ffffff" stroke-width="2.3" stroke-opacity="0.6" stroke-linejoin="round"/>
    <polyline points="132,340 254,401 376,340" fill="none" stroke="#ffffff" stroke-width="1.4" stroke-opacity="0.32" stroke-linejoin="round"/>
    <line x1="254" y1="401" x2="254" y2="436" stroke="#ffffff" stroke-width="1.4" stroke-opacity="0.35"/>
  </g>

  <!-- ========================================== -->
  <!-- TIER 3: VIVID NEON CORAL / HOT PINK        -->
  <!-- cx=258, cy=292, dx=108, dy=54, h=35        -->
  <!-- ========================================== -->
  <g id="tier_3">
    <ellipse cx="254" cy="340" rx="92" ry="34" fill="url(#blockAO)" opacity="0.65"/>
    <!-- Left Face: (150, 292) -> (258, 346) -> (258, 381) -> (150, 327) -->
    <polygon points="150,292 258,346 258,381 150,327" fill="url(#t3_left)"/>
    <!-- Right Face: (258, 346) -> (366, 292) -> (366, 327) -> (258, 381) -->
    <polygon points="258,346 366,292 366,327 258,381" fill="url(#t3_right)"/>
    <!-- Top Face: (258, 238) -> (366, 292) -> (258, 346) -> (150, 292) -->
    <polygon points="258,238 366,292 258,346 150,292" fill="url(#t3_top)"/>
    <!-- Top Face Glass -->
    <polygon points="204,265 258,238 300,259 246,286" fill="url(#glassStreak)" opacity="0.5"/>
    <!-- Bevel Highlights -->
    <polyline points="150,292 258,238 366,292" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-opacity="0.65" stroke-linejoin="round"/>
    <polyline points="150,292 258,346 366,292" fill="none" stroke="#ffffff" stroke-width="1.5" stroke-opacity="0.35" stroke-linejoin="round"/>
    <line x1="258" y1="346" x2="258" y2="381" stroke="#ffffff" stroke-width="1.5" stroke-opacity="0.4"/>
  </g>

  <!-- ========================================== -->
  <!-- TIER 4: ELECTRIC CYAN / AZURE              -->
  <!-- cx=252, cy=244, dx=94, dy=47, h=34         -->
  <!-- ========================================== -->
  <g id="tier_4">
    <ellipse cx="258" cy="292" rx="80" ry="30" fill="url(#blockAO)" opacity="0.68"/>
    <!-- Left Face: (158, 244) -> (252, 291) -> (252, 325) -> (158, 278) -->
    <polygon points="158,244 252,291 252,325 158,278" fill="url(#t4_left)"/>
    <!-- Right Face: (252, 291) -> (346, 244) -> (346, 278) -> (252, 325) -->
    <polygon points="252,291 346,244 346,278 252,325" fill="url(#t4_right)"/>
    <!-- Top Face: (252, 197) -> (346, 244) -> (252, 291) -> (158, 244) -->
    <polygon points="252,197 346,244 252,291 158,244" fill="url(#t4_top)"/>
    <!-- Top Face Glass -->
    <polygon points="205,221 252,197 292,217 245,241" fill="url(#glassStreak)" opacity="0.6"/>
    <!-- Bevel Highlights -->
    <polyline points="158,244 252,197 346,244" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-opacity="0.75" stroke-linejoin="round"/>
    <polyline points="158,244 252,291 346,244" fill="none" stroke="#ffffff" stroke-width="1.6" stroke-opacity="0.4" stroke-linejoin="round"/>
    <line x1="252" y1="291" x2="252" y2="325" stroke="#ffffff" stroke-width="1.6" stroke-opacity="0.45"/>
  </g>

  <!-- ========================================== -->
  <!-- TIER 5: SUN GOLD / AMBER CROWN             -->
  <!-- cx=258, cy=194, dx=80, dy=40, h=34         -->
  <!-- ========================================== -->
  <g id="tier_5">
    <ellipse cx="252" cy="244" rx="68" ry="26" fill="url(#blockAO)" opacity="0.7"/>
    <!-- Left Face: (178, 194) -> (258, 234) -> (258, 268) -> (178, 228) -->
    <polygon points="178,194 258,234 258,268 178,228" fill="url(#t5_left)"/>
    <!-- Right Face: (258, 234) -> (338, 194) -> (338, 228) -> (258, 268) -->
    <polygon points="258,234 338,194 338,228 258,268" fill="url(#t5_right)"/>
    <!-- Top Face: (258, 154) -> (338, 194) -> (258, 234) -> (178, 194) -->
    <polygon points="258,154 338,194 258,234 178,194" fill="url(#t5_top)"/>
    <!-- Specular Gloss Streak -->
    <polygon points="218,174 258,154 292,171 252,191" fill="url(#glassStreak)" opacity="0.8"/>
    <!-- Golden Crown Bevel Highlights -->
    <polyline points="178,194 258,154 338,194" fill="none" stroke="#ffffff" stroke-width="3" stroke-opacity="0.9" stroke-linejoin="round"/>
    <polyline points="178,194 258,234 338,194" fill="none" stroke="#ffffff" stroke-width="2" stroke-opacity="0.6" stroke-linejoin="round"/>
    <line x1="258" y1="234" x2="258" y2="268" stroke="#ffffff" stroke-width="2" stroke-opacity="0.6"/>
  </g>

  <!-- ========================================== -->
  <!-- PERFECT COMBO CROWN STAR & LENS FLARES     -->
  <!-- ========================================== -->
  <!-- Main Star at Crown Apex (258, 154) -->
  <g transform="translate(258, 154)">
    <circle cx="0" cy="0" r="42" fill="url(#sparkleAuraGold)"/>
    <!-- Cross Lens Flare -->
    <line x1="-36" y1="0" x2="36" y2="0" stroke="#ffffff" stroke-width="1.2" opacity="0.6"/>
    <line x1="0" y1="-36" x2="0" y2="36" stroke="#ffffff" stroke-width="1.2" opacity="0.6"/>
    <!-- Diagonal Subtle Glint -->
    <line x1="-24" y1="-24" x2="24" y2="24" stroke="#ffffff" stroke-width="0.9" opacity="0.35"/>
    <line x1="24" y1="-24" x2="-24" y2="24" stroke="#ffffff" stroke-width="0.9" opacity="0.35"/>
    <!-- 4-Point Star Core -->
    <path d="M 0,-30 Q 0,0 30,0 Q 0,0 0,30 Q 0,0 -30,0 Q 0,0 0,-30 Z" fill="#ffffff"/>
    <circle cx="0" cy="0" r="3.5" fill="#fef08a"/>
  </g>

  <!-- Top-Right Ambient Star -->
  <g transform="translate(396, 120)">
    <circle cx="0" cy="0" r="26" fill="url(#sparkleAuraGold)"/>
    <line x1="-18" y1="0" x2="18" y2="0" stroke="#ffffff" stroke-width="0.8" opacity="0.5"/>
    <line x1="0" y1="-18" x2="0" y2="18" stroke="#ffffff" stroke-width="0.8" opacity="0.5"/>
    <path d="M 0,-18 Q 0,0 18,0 Q 0,0 0,18 Q 0,0 -18,0 Q 0,0 0,-18 Z" fill="#ffffff"/>
    <circle cx="0" cy="0" r="2" fill="#fef08a"/>
  </g>

  <!-- Left Cyan Star -->
  <g transform="translate(106, 230)">
    <circle cx="0" cy="0" r="28" fill="url(#sparkleAuraCyan)"/>
    <line x1="-20" y1="0" x2="20" y2="0" stroke="#ffffff" stroke-width="0.8" opacity="0.5"/>
    <line x1="0" y1="-20" x2="0" y2="20" stroke="#ffffff" stroke-width="0.8" opacity="0.5"/>
    <path d="M 0,-20 Q 0,0 20,0 Q 0,0 0,20 Q 0,0 -20,0 Q 0,0 0,-20 Z" fill="#ffffff"/>
    <circle cx="0" cy="0" r="2.5" fill="#38bdf8"/>
  </g>

  <!-- Mid-Right Pink Star -->
  <g transform="translate(420, 275)">
    <circle cx="0" cy="0" r="24" fill="url(#sparkleAuraPink)"/>
    <path d="M 0,-16 Q 0,0 16,0 Q 0,0 0,16 Q 0,0 -16,0 Q 0,0 0,-16 Z" fill="#ffffff"/>
    <circle cx="0" cy="0" r="2" fill="#ff7da7"/>
  </g>

  <!-- Ambient Micro Glitter Stardust -->
  <circle cx="156" cy="130" r="2.5" fill="#ffffff" opacity="0.8"/>
  <circle cx="340" cy="80" r="2" fill="#fde047" opacity="0.75"/>
  <circle cx="192" cy="98" r="2" fill="#38bdf8" opacity="0.6"/>
  <circle cx="92" cy="336" r="2.5" fill="#38bdf8" opacity="0.5"/>
  <circle cx="422" cy="386" r="2.5" fill="#c084fc" opacity="0.65"/>
  <circle cx="116" cy="426" r="2" fill="#ffffff" opacity="0.4"/>
  <circle cx="396" cy="444" r="2" fill="#f43f5e" opacity="0.5"/>

</svg>'''
    return svg

if __name__ == "__main__":
    svg = build_5tier_icon_svg()
    with open("d:/GitHub/stack2/icon.svg", "w", encoding="utf-8") as f:
        f.write(svg)
    print("5-tier icon.svg successfully built!")
