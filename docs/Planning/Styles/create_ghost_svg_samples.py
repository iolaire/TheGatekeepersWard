# Let's generate the requested SVG and Swift implementation:
# Criteria:
# 1. Matches solo_spirit.svg styling (neon violet glow aura, deep midnight purple outline #3B185F, smooth ectoplasm gradient, cute face, blush).
# 2. Formed rounded head.
# 3. Draped cloak style pulled in at the waist.
# 4. Flares out wider at the floor/base with ripple hem folds, but NOT wider than the head diameter.

# Let's design the coordinate geometry:
# ViewBox: 0 0 200 240
# Head: centered at X=100. Width: ~90px (radius ~45px). X range roughly 55 to 145.
# Waist: pulled in to width ~60px (X range 70 to 130) around Y=135.
# Floor hem: flares out to width ~82px (X range 59 to 141), noticeably wider than waist (60px), but strictly narrower than head (90px).
# Draped cloak ripples at hem with ghost fold shadow lines.

cloaked_spirit_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240" width="100%" height="100%">
  <defs>
    <!-- Outer Violet Neon Glow Filter -->
    <filter id="purple-glow-cloaked" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="5" result="blur1" />
      <feGaussianBlur stdDeviation="10" result="blur2" />
      <feMerge>
        <feMergeNode in="blur2" />
        <feMergeNode in="blur1" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>

    <!-- Ectoplasm Body Gradient -->
    <linearGradient id="cloakedBodyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="65%" stop-color="#F1F5F9" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </linearGradient>

    <!-- Cloak Drape Shadow Gradient -->
    <linearGradient id="drapeShadow" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#CBD5E1" stop-opacity="0" />
      <stop offset="100%" stop-color="#94A3B8" stop-opacity="0.4" />
    </linearGradient>
  </defs>

  <!-- 1. VIOLET AURA GLOW -->
  <path d="M 100 25
           C 60 25 50 50 52 82
           C 53 104 62 118 68 132
           C 71 138 71 144 68 152
           C 62 168 56 186 58 206
           C 68 212 80 206 90 203
           C 97 201 103 201 110 203
           C 120 206 132 212 142 206
           C 144 186 138 168 132 152
           C 129 144 129 138 132 132
           C 138 118 147 104 148 82
           C 150 50 140 25 100 25 Z"
        fill="#8B5CF6" opacity="0.65" filter="url(#purple-glow-cloaked)" />

  <!-- 2. DEEP PURPLE SILHOUETTE OUTLINE -->
  <path d="M 100 28
           C 62 28 53 52 55 82
           C 56 103 64 117 70 131
           C 72 136 72 142 69 150
           C 63 166 58 184 60 204
           C 70 209 82 203 91 200
           C 97 198 103 198 109 200
           C 118 203 130 209 140 204
           C 142 184 137 166 131 150
           C 128 142 128 136 130 131
           C 136 117 144 103 145 82
           C 147 52 138 28 100 28 Z"
        fill="#3B185F" stroke="#3B185F" stroke-width="12" stroke-linejoin="round" stroke-linecap="round" />

  <!-- 3. CLOAKED SPIRIT BODY (White/Ectoplasm Fill) -->
  <path d="M 100 28
           C 62 28 53 52 55 82
           C 56 103 64 117 70 131
           C 72 136 72 142 69 150
           C 63 166 58 184 60 204
           C 70 209 82 203 91 200
           C 97 198 103 198 109 200
           C 118 203 130 209 140 204
           C 142 184 137 166 131 150
           C 128 142 128 136 130 131
           C 136 117 144 103 145 82
           C 147 52 138 28 100 28 Z"
        fill="url(#cloakedBodyGrad)" stroke="#2E1065" stroke-width="4" stroke-linejoin="round" />

  <!-- 4. DRAPED CLOAK FOLDS & HEM RIPPLES -->
  <!-- Left drape fold -->
  <path d="M 72 142 C 78 160 76 182 72 202"
        fill="none" stroke="#CBD5E1" stroke-width="3" stroke-linecap="round" />
  <path d="M 72 142 C 78 160 76 182 72 202"
        fill="none" stroke="#2E1065" stroke-width="2.5" stroke-opacity="0.35" stroke-linecap="round" />

  <!-- Center-right drape fold -->
  <path d="M 128 142 C 122 160 124 182 128 202"
        fill="none" stroke="#CBD5E1" stroke-width="3" stroke-linecap="round" />
  <path d="M 128 142 C 122 160 124 182 128 202"
        fill="none" stroke="#2E1065" stroke-width="2.5" stroke-opacity="0.35" stroke-linecap="round" />

  <!-- Center subtle waist-to-hem crease -->
  <path d="M 100 148 C 100 166 100 186 100 199"
        fill="none" stroke="#CBD5E1" stroke-width="2.5" stroke-linecap="round" />

  <!-- Bottom Hem Scallop Outlines -->
  <path d="M 60 204 Q 75 212 90 200" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />
  <path d="M 90 200 Q 100 205 110 200" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />
  <path d="M 110 200 Q 125 212 140 204" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />

  <!-- 5. HEAD & FACE -->
  <!-- Head Highlight -->
  <ellipse cx="88" cy="46" rx="22" ry="10" fill="#FFFFFF" opacity="0.95" />

  <!-- Big expressive dark purple eyes -->
  <circle cx="82" cy="80" r="7.5" fill="#2E1065" />
  <circle cx="118" cy="80" r="7.5" fill="#2E1065" />
  <!-- Eye Sparkle Glints -->
  <circle cx="80" cy="78" r="2.5" fill="#FFFFFF" />
  <circle cx="116" cy="78" r="2.5" fill="#FFFFFF" />

  <!-- Whimsical Smile -->
  <path d="M 94 92 Q 100 99 106 92" fill="none" stroke="#2E1065" stroke-width="3.5" stroke-linecap="round" />

  <!-- Cute Rosy Cheeks -->
  <ellipse cx="70" cy="88" rx="5.5" ry="3" fill="#F472B6" opacity="0.45" />
  <ellipse cx="130" cy="88" rx="5.5" ry="3" fill="#F472B6" opacity="0.45" />
</svg>
"""

with open("cloaked_spirit.svg", "w") as f:
    f.write(cloaked_spirit_svg.strip())

print("cloaked_spirit.svg successfully generated.")