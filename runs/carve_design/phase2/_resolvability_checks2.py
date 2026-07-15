import numpy as np
from itertools import product as iproduct
from math import comb

I2 = np.eye(2, dtype=complex)
X  = np.array([[0,1],[1,0]], dtype=complex)
Y  = np.array([[0,-1j],[1j,0]], dtype=complex)
Z  = np.diag([1.,-1.]).astype(complex)
paulis = [I2, X, Y, Z]

def kron_n(*ops):
    out = ops[0]
    for o in ops[1:]:
        out = np.kron(out, o)
    return out

def pauli_decomp(H, n):
    D = 2**n
    coeffs, weights = [], []
    for alpha in iproduct(range(4), repeat=n):
        P = kron_n(*[paulis[a] for a in alpha])
        c = np.trace(P @ H) / D
        w = sum(1 for a in alpha if a != 0)
        coeffs.append(abs(c)**2)
        weights.append(w)
    return np.array(coeffs), np.array(weights)

def Phi_mean_weight(H, U, n):
    Hu = U.conj().T @ H @ U
    coeffs, weights = pauli_decomp(Hu, n)
    if coeffs.sum() < 1e-15:
        return float('nan')
    mean_w = (coeffs * weights).sum() / coeffs.sum()
    return 1.0 - mean_w / n

def su2_rot(theta, axis):
    if axis == 'x':
        return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*X
    if axis == 'y':
        return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*Y
    return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*Z

# ============================================================
# DIAGNOSIS: WHY does Phi(H_scr, I) = Phi(H0, I)?
#
# If V is product-unitary (V = V1 x V2 x V3), then:
#   H_scr = V H0 V†
#   Phi(H_scr, I) = 1 - mean_weight(H_scr in standard frame) / n
#   mean_weight(H_scr) = mean_weight of (V H0 V†) in Pauli basis
#
# KEY CLAIM by pauli-concentration design: local unitaries PRESERVE
# Pauli weight. If V = V1 x V2 x ... x Vn (product), then V P V†
# for any Pauli P has the SAME weight as P (each Vi only mixes
# the single-qubit Pauli algebra on site i, weight-preserving).
#
# Therefore: if H0 = sum_P c_P P, then
#   V H0 V† = sum_P c_P (V P V†) = sum_P c_P P'  where wt(P') = wt(P)
# => the mean Pauli weight is IDENTICAL => Phi is the SAME!
#
# This is the "benign symmetry" the pauli-concentration doc claims.
# But it means: a product-unitary scrambler is INVISIBLE to Phi_mean_weight.
# The oracle in pauli-concentration uses V = product-unitary.
# But Phi(H_scr, I) = Phi(H0, I) already.
# The "known answer" is trivially recovered because the landscape is FLAT
# over all product-unitary transforms.
#
# This is a CRITICAL FLAW in the oracle design, not just a benign symmetry.

print("=== DIAGNOSIS: Product-unitary invariance of Phi_mean_weight ===")
n = 3
D = 2**n
# Simple n=3 2-local Ising
H0 = np.zeros((D,D), dtype=complex)
for i in range(n-1):
    ZZ = kron_n(*[Z if k in (i,i+1) else I2 for k in range(n)])
    H0 += ZZ
for i in range(n):
    XI = kron_n(*[X if k==i else I2 for k in range(n)])
    H0 += 0.5 * XI

# Test many random product-unitary scramblers
phi_std = Phi_mean_weight(H0, np.eye(D), n)
print(f"Phi(H0, I) = {phi_std:.6f}")
np.random.seed(42)
for trial in range(5):
    V_single = []
    for i in range(n):
        theta = np.random.uniform(0, 2*np.pi)
        phi   = np.random.uniform(0, np.pi)
        Vr = su2_rot(theta, 'x') @ su2_rot(phi, 'y')
        V_single.append(Vr)
    V = kron_n(*V_single)
    H_scr = V @ H0 @ V.conj().T
    phi_scr = Phi_mean_weight(H_scr, np.eye(D), n)
    print(f"Trial {trial}: Phi(V H0 V†, I) = {phi_scr:.6f}  [delta = {phi_scr - phi_std:.2e}]")

print()
print("=== DIAGNOSIS: Non-product (entangling) scrambler ===")
# Now use CNOT (entangling) as part of V
import numpy as np
CNOT = np.array([[1,0,0,0],[0,1,0,0],[0,0,0,1],[0,0,1,0]], dtype=complex)
# V = CNOT_{01} x I_2 (entangling gate on qubits 0,1)
V_ent = np.kron(CNOT, I2)
H_scr_ent = V_ent @ H0 @ V_ent.conj().T
phi_scr_ent_std = Phi_mean_weight(H_scr_ent, np.eye(D), n)
phi_scr_ent_rec = Phi_mean_weight(H_scr_ent, V_ent, n)
print(f"Phi(H0, I)                  = {phi_std:.6f}")
print(f"Phi(CNOT*H0*CNOT†, I)       = {phi_scr_ent_std:.6f}  [entangling scrambler in wrong frame]")
print(f"Phi(CNOT*H0*CNOT†, CNOT)    = {phi_scr_ent_rec:.6f}  [recovered frame, should match H0]")
print()
print("=> Non-product scrambler DOES change Phi -- confirms Phi sees non-product frames")
print()

# ============================================================
# CONSEQUENCE: The v1 oracle design is self-defeating for Phi_mean_weight
# because it uses a product-unitary scrambler and Phi is invariant under those.
# The search for max Phi has NO signal to guide it -- the landscape is FLAT
# over product-unitary transforms.
#
# The REAL signal requires a NON-product scrambler. But:
# (1) Non-product scramblers live in U(2^n) \ (U(2))^n
# (2) The v1 frame parameterization is product-unitary (each qubit independently)
# (3) So mcts over product frames CANNOT recover a non-product scrambler
#
# This means the v1 oracle + v1 search are mismatched for Phi_mean_weight.
# The commutant/cross-cut functional has the SAME issue IF the scrambler is product-unitary.
# Let's check:

print("=== DIAGNOSIS: Cross-cut Frobenius vs product-unitary scrambler ===")
def Phi_xcut_simple(H, U, nA, nB):
    dA, dB = 2**nA, 2**nB
    d = dA * dB
    Hu = U.conj().T @ H @ U
    Hnorm2 = float(np.real(np.trace(H.conj().T @ H)))
    r = Hu.reshape(dA, dB, dA, dB)
    HB = np.trace(r, axis1=0, axis2=2) / dA
    HA = np.trace(r, axis1=1, axis2=3) / dB
    IA = np.eye(dA, dtype=complex)
    IB = np.eye(dB, dtype=complex)
    H_ts = np.kron(HA, IB) + np.kron(IA, HB)
    V = Hu - H_ts
    tr = np.trace(Hu) / d
    V = V - tr * np.eye(d, dtype=complex)
    V_norm2 = float(np.real(np.trace(V.conj().T @ V)))
    tr_H = np.trace(H)
    denom = Hnorm2 - float(np.abs(tr_H)**2) / d
    if denom < 1e-15:
        return float('nan')
    return 1.0 - V_norm2 / denom

nA, nB = 1, 2
D3 = 2**3
H0_3 = H0.copy()
phi_xc_std = Phi_xcut_simple(H0_3, np.eye(D3), nA, nB)
print(f"Phi_xcut(H0, I, 1+2)        = {phi_xc_std:.6f}")

# product-unitary scrambler on n=3 (1+2 split)
np.random.seed(99)
for trial in range(3):
    V_single = []
    for i in range(3):
        theta = np.random.uniform(0, 2*np.pi)
        phi_a = np.random.uniform(0, np.pi)
        Vr = su2_rot(theta, 'x') @ su2_rot(phi_a, 'y')
        V_single.append(Vr)
    Vp = kron_n(*V_single)
    H_scrp = Vp @ H0_3 @ Vp.conj().T
    phi_xc_scrp = Phi_xcut_simple(H_scrp, np.eye(D3), nA, nB)
    print(f"Trial {trial}: Phi_xcut(Vp H0 Vp†, I) = {phi_xc_scrp:.6f}  [delta = {phi_xc_scrp - phi_xc_std:.2e}]")

print()
print("If delta ~ 0: cross-cut is ALSO invariant under product-unitary scrambler for THIS split")

# Now try an entangling scrambler
V_ent3 = np.kron(CNOT, I2)
H_scr_ent3 = V_ent3 @ H0_3 @ V_ent3.conj().T
phi_xc_ent_std = Phi_xcut_simple(H_scr_ent3, np.eye(D3), nA, nB)
phi_xc_ent_rec = Phi_xcut_simple(H_scr_ent3, V_ent3, nA, nB)
print()
print(f"Phi_xcut(CNOT H0 CNOT†, I, 1+2)    = {phi_xc_ent_std:.6f}  [entangling scrambler, wrong frame]")
print(f"Phi_xcut(CNOT H0 CNOT†, CNOT, 1+2) = {phi_xc_ent_rec:.6f}  [recovered]")

# ============================================================
print()
print("=== ORACLE DESIGN ISSUE SUMMARY ===")
print("Phi_mean_weight is INVARIANT under product-unitary transforms of H.")
print("=> v1 oracle using product-unitary scrambler + product-unitary frame search:")
print("   Phi(H_scr, I) = Phi(H0, I)  [landscape is FLAT across product-U transforms]")
print("   mcts over product frames has NO signal gradient to maximize.")
print("   This is a KILL for the product-unitary oracle + product-frame search combination.")
print()
print("The ONLY way to make the oracle recoverable:")
print("  A) Use a NON-product scrambler AND a non-product frame space (e.g. full U(2^n))")
print("     -- but full U(2^n) is not discretizable for mcts at n>=4")
print("  B) Use a product-unitary scrambler but change the functional to one that IS")
print("     sensitive to product-unitary transforms of H -- e.g., Phi_12 in a FIXED")
print("     basis where H0 is NOT 2-local (so product-U scrambling DOES change Phi_12).")
print("     But Phi_mean_weight already showed this fails.")
print()
print("Note: Phi_12(H0, I) = 1.0 for a 2-local H0 means the standard frame already")
print("achieves the maximum. A product-unitary scrambler maps 2-local -> 2-local,")
print("so Phi_12(V H0 V†, I) is NOT necessarily 1.0. Let's check:")
print()

n4 = 4
D4 = 2**n4
H0_4 = np.zeros((D4,D4), dtype=complex)
for i in range(n4-1):
    ZZ4 = kron_n(*[Z if k in (i,i+1) else I2 for k in range(n4)])
    H0_4 += [0.5, 1.0, 0.7][i%3] * ZZ4
for i in range(n4):
    XI4 = kron_n(*[X if k==i else I2 for k in range(n4)])
    H0_4 += [0.3,0.7,0.4,0.6][i] * XI4

phi12_H0 = Phi_12(H0_4, np.eye(D4), n4)
print(f"Phi_12(H0_n4, I) = {phi12_H0:.6f}  [should be 1.0 since H0 is exactly 2-local]")

# Product-unitary scrambler: since H0 is 2-local (ZiZj + Xi),
# V H0 V† where V=product-unitary: each Pauli string P -> V P V†
# weight is PRESERVED. So Phi_12(V H0 V†, I) = 1.0 ALWAYS.
# The oracle "known answer" V is trivially found because the scrambled H
# is STILL 2-local in the standard frame (local unitaries preserve weight).
np.random.seed(42)
for trial in range(3):
    V4s = [su2_rot(np.random.uniform(0,2*np.pi),'x') @ su2_rot(np.random.uniform(0,np.pi),'y') for _ in range(n4)]
    V4p = kron_n(*V4s)
    H_scr4 = V4p @ H0_4 @ V4p.conj().T
    phi12_scr = Phi_12(H_scr4, np.eye(D4), n4)
    print(f"  Trial {trial}: Phi_12(Vp H0 Vp†, I) = {phi12_scr:.6f}  [if 1.0: oracle trivially satisfied without search]")

print()
print("=== CONCLUSION: The planted scrambler must be NON-product for there to be a signal ===")
print("mcts over product frames cannot solve a non-product scrambler.")
print("CORRECT oracle design: scrambler = known element of the SAME discrete frame space that mcts searches.")
print("This is the commutant design's 'frame alphabet' approach -- oracle uses Clifford from same alphabet.")
print()
print("For the ENTANGLING-POWER (cross-cut Frobenius) functional:")
print("H_int(U) = off-diagonal block of U†HU under the A:B split.")
print("For a product H (H_A x I + I x H_B): H_int(I) = 0, Phi = 0")
print("But a product-unitary V = VA x VB (on A and B separately) does NOT change H_int(I):")
print("U†HU where U=VA x VB, H = H_A x I + I x H_B:")
print("=> (VA†HAloc VA) x I + I x (VB†HBloc VB) -- still product, H_int=0")
print("=> Phi_xcut is ALSO invariant under SEPARATE LOCAL UNITARIES ON EACH FACTOR")
print()
print("What DOES change Phi_xcut: an entangling unitary V that mixes A and B.")
print("The oracle MUST use an entangling V that lives in the mcts frame lattice.")
