# Let's generate clean, high quality SVG files for:
# 1. duo_spirits.svg (The attached duo: skull-ghost and small spirit with neon violet glow)
# 2. solo_spirit.svg (The cute little whimsical ghost)
# 3. solo_skull_spirit.svg (The skull-head ghost)
# 4. castle_gate_spirits.svg (The glowing castle portcullis gate with spirits slipping through)

duo_spirits_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 260" width="100%" height="100%">
  <defs>
    <!-- Outer Glow Filter -->
    <filter id="purple-glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="6" result="blur1" />
      <feGaussianBlur stdDeviation="12" result="blur2" />
      <feMerge>
        <feMergeNode in="blur2" />
        <feMergeNode in="blur1" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>

    <!-- Subtle gradient for spirits -->
    <linearGradient id="ghostBodyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="70%" stop-color="#F1F5F9" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </linearGradient>

    <!-- Eye glow gradient -->
    <radialGradient id="eyePink" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FF66CC" />
      <stop offset="60%" stop-color="#E11D48" />
      <stop offset="100%" stop-color="#9F1239" />
    </radialGradient>
  </defs>

  <!-- BACKGROUND GLOW AURA -->
  <g filter="url(#purple-glow)">
    <!-- Aura path for Duo -->
    <path d="M 180 32
             C 125 32 110 75 118 115
             C 105 110 85 110 65 125
             C 40 145 42 195 68 220
             C 95 245 135 240 155 220
             C 165 228 185 242 210 240
             C 245 238 270 205 265 155
             C 260 90 235 32 180 32 Z"
          fill="#8B5CF6" opacity="0.6" />
  </g>

  <!-- SOLID PURPLE OUTLINE / BORDER -->
  <g stroke="#3B185F" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
    <!-- Big Skull Spirit Base Outline -->
    <path d="M 185 45
             C 142 45 130 80 135 118
             C 137 132 135 142 130 148
             C 128 152 132 165 140 168
             C 145 170 145 180 142 195
             C 140 205 148 215 156 210
             C 165 204 172 212 178 218
             C 188 228 202 222 208 212
             C 216 198 218 185 228 200
             C 238 214 252 212 255 198
             C 260 175 252 152 248 142
             C 255 130 256 112 254 98
             C 250 62 222 45 185 45 Z" fill="#3B185F" />
    
    <!-- Small Spirit Base Outline -->
    <path d="M 92 122
             C 65 122 52 145 54 175
             C 56 200 68 228 92 232
             C 118 236 138 222 148 212
             C 135 200 125 180 126 155
             C 126 135 112 122 92 122 Z" fill="#3B185F" />
  </g>

  <!-- SPIRIT BODIES (Fill Layer) -->
  <!-- Small Spirit Body -->
  <path d="M 92 125
           C 68 125 56 148 58 175
           C 60 198 70 224 92 227
           C 114 230 132 218 142 209
           C 130 198 121 178 122 155
           C 122 137 110 125 92 125 Z"
        fill="url(#ghostBodyGrad)" stroke="#2E1065" stroke-width="4" />

  <!-- Small Spirit Face -->
  <circle cx="78" cy="162" r="6.5" fill="#2E1065" />
  <circle cx="108" cy="162" r="6.5" fill="#2E1065" />
  <!-- Small Spirit Smile -->
  <path d="M 88 172 Q 93 179 98 172" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />
  <!-- Small Spirit Highlights -->
  <circle cx="76" cy="160" r="2" fill="#FFFFFF" />
  <circle cx="106" cy="160" r="2" fill="#FFFFFF" />
  <!-- Soft blush -->
  <ellipse cx="69" cy="168" rx="4" ry="2.5" fill="#F472B6" opacity="0.4" />
  <ellipse cx="117" cy="168" rx="4" ry="2.5" fill="#F472B6" opacity="0.4" />

  <!-- Big Skull Spirit Body -->
  <path d="M 185 48
           C 146 48 136 82 140 118
           C 142 130 140 140 135 146
           C 133 150 137 162 144 165
           C 149 167 149 178 146 192
           C 144 201 151 209 158 205
           C 166 199 173 207 178 213
           C 187 222 199 217 205 208
           C 212 195 215 182 225 195
           C 234 207 246 205 249 193
           C 253 172 246 150 243 142
           C 250 130 251 112 249 98
           C 246 65 220 48 185 48 Z"
        fill="url(#ghostBodyGrad)" stroke="#2E1065" stroke-width="4.5" />

  <!-- Skull Head Details -->
  <!-- Skull Brow & Head Highlight -->
  <ellipse cx="180" cy="65" rx="32" ry="14" fill="#FFFFFF" opacity="0.8" />
  
  <!-- Big Skull Eyes -->
  <g>
    <!-- Left Eye Socket -->
    <ellipse cx="163" cy="108" rx="14" ry="16" fill="#2E1065" />
    <circle cx="163" cy="108" r="6.5" fill="url(#eyePink)" />
    <circle cx="165" cy="106" r="2" fill="#FFFFFF" />

    <!-- Right Eye Socket -->
    <ellipse cx="212" cy="108" rx="14" ry="16" fill="#2E1065" />
    <circle cx="212" cy="108" r="6.5" fill="url(#eyePink)" />
    <circle cx="214" cy="106" r="2" fill="#FFFFFF" />
  </g>

  <!-- Skull Nose Hole -->
  <path d="M 187 118 L 182 128 L 192 128 Z" fill="#2E1065" stroke-linejoin="round" />

  <!-- Skull Teeth / Jaw Ridge -->
  <path d="M 160 144
           C 162 158 174 162 187 162
           C 200 162 212 158 214 144" 
        fill="none" stroke="#2E1065" stroke-width="4" stroke-linecap="round" />
  <!-- Teeth separator lines -->
  <path d="M 172 150 L 172 158
           M 187 150 L 187 160
           M 202 150 L 202 158" 
        stroke="#2E1065" stroke-width="3" stroke-linecap="round" />

  <!-- Ghost Little Stub Arm / Waving Fold -->
  <path d="M 226 152 C 220 165 214 175 208 175 C 203 175 202 165 204 158" 
        fill="#E2E8F0" stroke="#2E1065" stroke-width="3" stroke-linecap="round" />

</svg>
"""

solo_spirit_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 180" width="100%" height="100%">
  <defs>
    <filter id="purple-glow-solo" x="-25%" y="-25%" width="150%" height="150%">
      <feGaussianBlur stdDeviation="5" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
    <linearGradient id="soloBodyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="75%" stop-color="#F1F5F9" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </linearGradient>
  </defs>

  <!-- Aura Glow -->
  <path d="M 80 20
           C 40 20 25 50 28 92
           C 30 125 45 158 78 162
           C 112 166 138 148 148 135
           C 132 120 120 95 122 62
           C 122 38 105 20 80 20 Z"
        fill="#8B5CF6" opacity="0.6" filter="url(#purple-glow-solo)" />

  <!-- Outline Border -->
  <path d="M 80 25
           C 45 25 32 55 35 92
           C 37 122 50 152 78 156
           C 106 160 130 144 140 132
           C 126 118 116 95 117 65
           C 117 42 102 25 80 25 Z"
        fill="#3B185F" stroke="#3B185F" stroke-width="10" stroke-linejoin="round" />

  <!-- Body -->
  <path d="M 80 25
           C 45 25 32 55 35 92
           C 37 122 50 152 78 156
           C 106 160 130 144 140 132
           C 126 118 116 95 117 65
           C 117 42 102 25 80 25 Z"
        fill="url(#soloBodyGrad)" stroke="#2E1065" stroke-width="4" />

  <!-- Highlights -->
  <ellipse cx="68" cy="42" rx="20" ry="9" fill="#FFFFFF" opacity="0.9" />

  <!-- Face -->
  <circle cx="62" cy="78" r="7.5" fill="#2E1065" />
  <circle cx="98" cy="78" r="7.5" fill="#2E1065" />
  <circle cx="60" cy="75" r="2.5" fill="#FFFFFF" />
  <circle cx="96" cy="75" r="2.5" fill="#FFFFFF" />

  <!-- Smile -->
  <path d="M 74 90 Q 80 98 86 90" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />

  <!-- Blushing Cheeks -->
  <ellipse cx="50" cy="86" rx="5" ry="3" fill="#F472B6" opacity="0.45" />
  <ellipse cx="110" cy="86" rx="5" ry="3" fill="#F472B6" opacity="0.45" />
</svg>
"""

castle_gate_spirits_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 380" width="100%" height="100%">
  <defs>
    <!-- Gate & Neon Glow -->
    <filter id="neon-violet-glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="4" result="blur1" />
      <feGaussianBlur stdDeviation="9" result="blur2" />
      <feMerge>
        <feMergeNode in="blur2" />
        <feMergeNode in="blur1" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>

    <linearGradient id="gateGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#C084FC" />
      <stop offset="50%" stop-color="#A855F7" />
      <stop offset="100%" stop-color="#7E22CE" />
    </linearGradient>

    <linearGradient id="spookyGhostGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="70%" stop-color="#EDE9FE" />
      <stop offset="100%" stop-color="#DDD6FE" />
    </linearGradient>
  </defs>

  <!-- BACKGROUND ARCHWAY (Dark stone frame) -->
  <rect width="500" height="380" fill="#090D16" rx="16" />
  
  <!-- Distant Castle Arch -->
  <path d="M 70 380 L 70 170 C 70 80 150 40 250 40 C 350 40 430 80 430 170 L 430 380 Z" 
        fill="#05070A" stroke="#1E293B" stroke-width="4" />

  <!-- CASTLE PORTCULLIS GATES (Behind some spirits, in front of others) -->
  <g filter="url(#neon-violet-glow)" stroke="url(#gateGrad)" stroke-width="5" stroke-linecap="round">
    <!-- Outer Gate Frame Arch -->
    <path d="M 90 380 L 90 180 C 90 100 160 60 250 60 C 340 60 410 100 410 180 L 410 380" fill="none" />

    <!-- Vertical Iron Bars with Spikes -->
    <!-- Bar 1 -->
    <path d="M 130 380 L 130 140 L 126 120 L 130 100 L 134 120 Z" fill="#A855F7" />
    <!-- Bar 2 -->
    <path d="M 178 380 L 178 100 L 174 80 L 178 60 L 182 80 Z" fill="#A855F7" />
    <!-- Bar 3 (Center left) -->
    <path d="M 226 380 L 226 80 L 222 60 L 226 42 L 230 60 Z" fill="#A855F7" />
    <!-- Bar 4 (Center right) -->
    <path d="M 274 380 L 274 80 L 270 60 L 274 42 L 278 60 Z" fill="#A855F7" />
    <!-- Bar 5 -->
    <path d="M 322 380 L 322 100 L 318 80 L 322 60 L 326 80 Z" fill="#A855F7" />
    <!-- Bar 6 -->
    <path d="M 370 380 L 370 140 L 366 120 L 370 100 L 374 120 Z" fill="#A855F7" />

    <!-- Horizontal Crossbars & Scrollwork -->
    <line x1="90" y1="210" x2="410" y2="210" stroke-width="6" />
    <line x1="90" y1="330" x2="410" y2="330" stroke-width="6" />

    <!-- Gothic Wrought Scrolls on Gate -->
    <path d="M 130 210 Q 154 240 178 210" fill="none" stroke-width="3" />
    <path d="M 178 210 Q 202 240 226 210" fill="none" stroke-width="3" />
    <path d="M 226 210 Q 250 240 274 210" fill="none" stroke-width="3" />
    <path d="M 274 210 Q 298 240 322 210" fill="none" stroke-width="3" />
    <path d="M 322 210 Q 346 240 370 210" fill="none" stroke-width="3" />
  </g>

  <!-- WANDERING SPIRITS SLIPPING THROUGH THE BARS -->

  <!-- Spirit 1: Slipping through Left Bars (Waving) -->
  <g transform="translate(100, 150) rotate(-10)">
    <!-- Aura -->
    <path d="M 40 10 C 15 10 5 35 8 65 C 10 90 28 115 50 115 C 72 115 90 95 85 65 C 80 35 65 10 40 10 Z" 
          fill="#A855F7" opacity="0.5" filter="url(#neon-violet-glow)" />
    <!-- Body -->
    <path d="M 40 12 C 18 12 8 35 11 62 C 14 85 28 108 48 108 C 68 108 82 90 80 62 C 78 35 62 12 40 12 Z" 
          fill="url(#spookyGhostGrad)" stroke="#3B185F" stroke-width="3.5" />
    <!-- Tail Swoop -->
    <path d="M 40 108 Q 30 130 15 135 Q 35 125 52 108" fill="url(#spookyGhostGrad)" stroke="#3B185F" stroke-width="3" />
    <!-- Face -->
    <circle cx="32" cy="46" r="4.5" fill="#2E1065" />
    <circle cx="54" cy="46" r="4.5" fill="#2E1065" />
    <circle cx="31" cy="44" r="1.5" fill="#FFFFFF" />
    <circle cx="53" cy="44" r="1.5" fill="#FFFFFF" />
    <path d="M 39 55 Q 43 61 47 55" fill="none" stroke="#2E1065" stroke-width="2.5" stroke-linecap="round" />
    <ellipse cx="25" cy="52" rx="3.5" ry="2" fill="#F472B6" opacity="0.4" />
    <ellipse cx="61" cy="52" rx="3.5" ry="2" fill="#F472B6" opacity="0.4" />
  </g>

  <!-- Spirit 2: Big Skull Spirit Squeezing Through Center Gate -->
  <g transform="translate(210, 110)">
    <!-- Glow -->
    <path d="M 45 10 C 15 10 5 40 10 70 C 14 95 30 120 52 120 C 75 120 90 95 88 65 C 85 30 75 10 45 10 Z" 
          fill="#A855F7" opacity="0.6" filter="url(#neon-violet-glow)" />
    <!-- Head & Body -->
    <path d="M 48 14 C 20 14 12 40 15 68 C 17 80 14 90 8 96 C 20 115 45 120 58 112 C 72 105 85 85 82 62 C 80 32 68 14 48 14 Z" 
          fill="url(#spookyGhostGrad)" stroke="#3B185F" stroke-width="4" />
    <!-- Skull Face -->
    <ellipse cx="34" cy="48" rx="8" ry="9" fill="#2E1065" />
    <circle cx="34" cy="48" r="4" fill="#EC4899" />
    <ellipse cx="62" cy="48" rx="8" ry="9" fill="#2E1065" />
    <circle cx="62" cy="48" r="4" fill="#EC4899" />
    <polygon points="48,54 45,61 51,61" fill="#2E1065" />
    <!-- Teeth -->
    <path d="M 36 72 C 40 80 56 80 60 72" fill="none" stroke="#2E1065" stroke-width="2.5" stroke-linecap="round" />
    <line x1="44" y1="74" x2="44" y2="79" stroke="#2E1065" stroke-width="2" />
    <line x1="52" y1="74" x2="52" y2="79" stroke="#2E1065" stroke-width="2" />
  </g>

  <!-- Spirit 3: High Floating Playful Ghost Peek over Upper Right Bar -->
  <g transform="translate(340, 80) rotate(15)">
    <path d="M 30 8 C 10 8 2 28 5 50 C 8 72 25 85 45 80 C 60 75 68 55 64 35 C 60 15 50 8 30 8 Z" 
          fill="url(#spookyGhostGrad)" stroke="#3B185F" stroke-width="3" filter="url(#neon-violet-glow)" />
    <circle cx="26" cy="32" r="3.5" fill="#2E1065" />
    <circle cx="44" cy="32" r="3.5" fill="#2E1065" />
    <path d="M 32 40 Q 35 44 38 40" fill="none" stroke="#2E1065" stroke-width="2" stroke-linecap="round" />
    <!-- Playful wink/cheek -->
    <ellipse cx="20" cy="36" rx="2.5" ry="1.5" fill="#F472B6" opacity="0.4" />
    <ellipse cx="50" cy="36" rx="2.5" ry="1.5" fill="#F472B6" opacity="0.4" />
  </g>

  <!-- FOREGROUND ACCENTS: Glowing Spores / Sparkles -->
  <circle cx="150" cy="90" r="2.5" fill="#E9D5FF" opacity="0.8" />
  <circle cx="280" cy="70" r="3" fill="#FDE047" opacity="0.8" />
  <circle cx="390" cy="230" r="2" fill="#E9D5FF" opacity="0.7" />
  <circle cx="110" cy="290" r="3" fill="#A855F7" opacity="0.6" />
</svg>
"""

# Save all SVG files
with open("duo_spirits.svg", "w") as f:
    f.write(duo_spirits_svg.strip())

with open("solo_spirit.svg", "w") as f:
    f.write(solo_spirit_svg.strip())

with open("castle_gate_spirits.svg", "w") as f:
    f.write(castle_gate_spirits_svg.strip())

print("SVG files generated successfully:")
print("- duo_spirits.svg")
print("- solo_spirit.svg")
print("- castle_gate_spirits.svg")