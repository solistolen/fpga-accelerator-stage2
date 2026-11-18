"""Golden model + test-vector generator for the Stage 1 MAC unit.

Writes vectors.txt. Each line is one clock cycle:
    en clr a b expected_acc        (all in hex)
  en           1 = do a MAC this cycle, 0 = hold the accumulator
  clr          1 = start a new sum (acc <= a*b instead of acc + a*b); only acts when en = 1
  a, b         signed 8-bit inputs, two's complement (e.g. 80 = -128, ff = -1)
  expected_acc value the accumulator must hold AFTER this clock edge (32-bit two's complement)

Run:  python gen_vectors.py
"""
import random

W, ACC_W = 8, 32
LO, HI = -(1 << (W - 1)), (1 << (W - 1)) - 1          # -128 .. 127

def wrap(x, bits):
    """Model a fixed-width two's-complement register (what the hardware actually does)."""
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits - 1) else x

def hexw(x, bits):
    return format(x & ((1 << bits) - 1), "0{}x".format(bits // 4))

class MacModel:
    def __init__(self):
        self.acc = 0
    def step(self, en, clr, a, b):
        if en:
            self.acc = wrap(a * b if clr else self.acc + a * b, ACC_W)
        return self.acc

def main(seed=1, n_random=200, kernel=9):
    random.seed(seed)
    m, cycles = MacModel(), []

    def cyc(en, clr, a, b):
        cycles.append((en, clr, a, b, m.step(en, clr, a, b)))

    def dot(xs, ws):                       # one dot product, clr on the first term
        for i, (x, w) in enumerate(zip(xs, ws)):
            cyc(1, int(i == 0), x, w)

    # --- directed corner cases -------------------------------------------
    dot([LO] * kernel, [LO] * kernel)      # -128*-128 = +16384, the largest product
    dot([LO] * kernel, [HI] * kernel)      # most negative sum
    dot([HI] * kernel, [HI] * kernel)
    dot([-1] * kernel, [1] * kernel)       # catches unsigned-math bugs (ff * 01)
    for _ in range(3):                     # en = 0 must hold the value
        cyc(0, 0, random.randint(LO, HI), random.randint(LO, HI))
    cyc(0, 1, 5, 5)                        # clr without en must also hold
    cyc(1, 1, 3, 4)                        # back-to-back clr: new sums with no gap
    cyc(1, 1, -7, 6)
    # --- random 3x3-kernel dot products, with occasional idle cycles ------
    for _ in range(n_random):
        xs = [random.randint(LO, HI) for _ in range(kernel)]
        ws = [random.randint(LO, HI) for _ in range(kernel)]
        dot(xs, ws)
        if random.random() < 0.2:
            cyc(0, 0, random.randint(LO, HI), random.randint(LO, HI))

    with open("vectors.txt", "w") as f:
        for en, clr, a, b, exp in cycles:
            f.write(f"{en} {clr} {hexw(a, W)} {hexw(b, W)} {hexw(exp, ACC_W)}\n")
    print(f"wrote {len(cycles)} cycles to vectors.txt")

if __name__ == "__main__":
    main()
