import sys
f = open('vga_frame1.ppm','rb')
f.readline()  # P6
f.readline()  # 640 480
f.readline()  # 255
data = f.read()
f.close()
w, h = 640, 480

# Check a sweep of positions. VGA is 2x upscaled from 320x240 FB.
# So VGA(2*fx, 2*fy) = FB(fx, fy)
print("=== Frame 1 pixel sweep ===")
# Row sweep at VGA x=100 (FB x=50)
for vy in range(0, 480, 40):
    off = (vy * w + 100) * 3
    r, g, b = data[off], data[off+1], data[off+2]
    print(f'  VGA(100,{vy:3d}) FB({50},{vy//2:3d}): R={r:3d} G={g:3d} B={b:3d}')

print()
# Column sweep at VGA y=100 (FB y=50)
for vx in range(0, 640, 40):
    off = (100 * w + vx) * 3
    r, g, b = data[off], data[off+1], data[off+2]
    print(f'  VGA({vx:3d},100) FB({vx//2:3d}, {50}): R={r:3d} G={g:3d} B={b:3d}')

# Count non-black pixels
total = w * h
nonblack = sum(1 for i in range(0, total * 3, 3) if data[i] or data[i+1] or data[i+2])
print(f'\nNon-black pixels: {nonblack} / {total} ({100*nonblack/total:.1f}%)')
