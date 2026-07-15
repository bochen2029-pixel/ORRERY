import numpy as np
from itertools import product as iproduct
from math import comb

# Pauli matrices
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

def Phi_12(H, U, n):
    Hu = U.conj().T @ H @ U
    coeffs, weights = pauli_decomp(Hu, n)
    if coeffs.sum() < 1e-15:
        return float('nan')
    return coeffs[np.array(weights) <= 2].sum() / coeffs.sum()

def Phi_xcut(H, U, nA, nB):
    dA, dB = 2**nA, 2**nB
    d = dA * dB
    Hu = U.conj().T @ H @ U
    Hnorm2 = float(np.real(np.trace(H.conj().T @ H)))
    # partial traces
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

def su2_rot(theta, axis):
    if axis == 'x':
        return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*X
    if axis == 'y':
        return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*Y
    return np.cos(theta/2)*I2 - 1j*np.sin(theta/2)*Z

# ============================================================
print("=== Test 1: n=3, 2-local Ising + product-unitary scrambler ===")
np.random.seed(42)
n = 3
D = 2**n
H0 = np.zeros((D,D), dtype=complex)
for i in range(n-1):
    J = [0.5, 1.0][i % 2]
    ZZ = kron_n(*[Z if k in (i,i+1) else I2 for k in range(n)])
    H0 += J * ZZ
for i in range(n):
    h = [0.3, 0.7, 0.4][i]
    XI = kron_n(*[X if k==i else I2 for k in range(n)])
    H0 += h * XI

angles = [np.pi/4, np.pi/3, np.pi/6]
axes   = ['x','y','z']
V_single = [su2_rot(angles[i], axes[i]) for i in range(n)]
V = kron_n(*V_single)
H_scr = V @ H0 @ V.conj().T

phi_H0_std  = Phi_mean_weight(H0,    np.eye(D), n)
phi_scr_std = Phi_mean_weight(H_scr, np.eye(D), n)
phi_scr_rec = Phi_mean_weight(H_scr, V,         n)
print(f"Phi(H0, I)         = {phi_H0_std:.4f}   [local H, standard frame]")
print(f"Phi(H_scr, I)      = {phi_scr_std:.4f}   [scrambled, wrong frame]")
print(f"Phi(H_scr, V)      = {phi_scr_rec:.4f}   [scrambled, recovered frame]")
print()

# ============================================================
print("=== Test 2: n=4 Haar-scrambled baseline ===")
n4 = 4
E_mean_w_Haar = 3*n4/4
E_Phi_Haar = 1 - E_mean_w_Haar / n4
for k in range(n4+1):
    cnt = comb(n4,k) * 3**k
    print(f"  weight-{k}: {cnt} strings, fraction={cnt/4**n4:.4f}")
C_n2_4 = sum(comb(n4,k)*3**k for k in range(3))
print(f"  C(4,<=2)={C_n2_4}, baseline Phi_12={C_n2_4/4**n4:.4f}")
print(f"  E[Phi_mean_weight] Haar n=4 = {E_Phi_Haar:.4f}")
print()

n4D = 2**n4
H0_4 = np.zeros((n4D,n4D), dtype=complex)
for i in range(n4-1):
    J = [0.5, 1.0, 0.7][i%3]
    ZZ4 = kron_n(*[Z if k in (i,i+1) else I2 for k in range(n4)])
    H0_4 += J * ZZ4
for i in range(n4):
    h = [0.3,0.7,0.4,0.6][i]
    XI4 = kron_n(*[X if k==i else I2 for k in range(n4)])
    H0_4 += h * XI4

phi_haar_vals = []
for seed in range(5):
    rng = np.random.default_rng(seed)
    W = np.linalg.qr(rng.standard_normal((n4D,n4D)) + 1j*rng.standard_normal((n4D,n4D)))[0]
    H_haar = W @ H0_4 @ W.conj().T
    ph = Phi_mean_weight(H_haar, np.eye(n4D), n4)
    phi_haar_vals.append(ph)
    print(f"  Haar sample {seed}: Phi = {ph:.4f}")
print(f"  Haar mean = {np.mean(phi_haar_vals):.4f}  (expect ~{E_Phi_Haar:.4f})")
print()

phi_local_n4 = Phi_mean_weight(H0_4, np.eye(n4D), n4)
phi12_local_n4 = Phi_12(H0_4, np.eye(n4D), n4)
print(f"Phi(H0_n4, I)      = {phi_local_n4:.4f}   [local H standard frame]")
print(f"Phi_12(H0_n4, I)   = {phi12_local_n4:.4f}   [weight-1+2 fraction]")
print()

# ============================================================
print("=== Test 3: Landscape ruggedness n=3 scrambled H, 200 random frames ===")
np.random.seed(7)
phi_samples = []
for _ in range(200):
    U_rand = np.linalg.qr(np.random.randn(D,D)+1j*np.random.randn(D,D))[0]
    phi_samples.append(Phi_mean_weight(H_scr, U_rand, n))
phi_arr = np.array(phi_samples)
print(f"  Random frames: min={phi_arr.min():.4f}  max={phi_arr.max():.4f}  mean={phi_arr.mean():.4f}  std={phi_arr.std():.4f}")
print(f"  Known-answer V: Phi = {phi_scr_rec:.4f}")
print(f"  Signal above mean = {phi_scr_rec - phi_arr.mean():.4f}  ({(phi_scr_rec-phi_arr.mean())/phi_arr.std():.1f} sigma)")
print()

# ============================================================
print("=== Test 4: Entangling-power (cross-cut Frobenius) n=4, 2+2 split ===")
nA, nB = 2, 2
phi_xcut_local = Phi_xcut(H0_4, np.eye(n4D), nA, nB)
V4_single = [su2_rot(a,ax) for a,ax in [(np.pi/4,'x'),(np.pi/3,'y'),(np.pi/6,'z'),(np.pi/5,'x')]]
V4 = kron_n(*V4_single)
H_scr4 = V4 @ H0_4 @ V4.conj().T
phi_xcut_scr_std = Phi_xcut(H_scr4, np.eye(n4D), nA, nB)
phi_xcut_scr_rec = Phi_xcut(H_scr4, V4,           nA, nB)
print(f"  Phi_xcut(H0_4, I)        = {phi_xcut_local:.4f}  [local: not pure product -> non-zero]")
print(f"  Phi_xcut(H_scr4, I)      = {phi_xcut_scr_std:.4f}  [scrambled, wrong frame]")
print(f"  Phi_xcut(H_scr4, V4)     = {phi_xcut_scr_rec:.4f}  [recovered frame]")
print()

# ============================================================
print("=== Test 5: Commutant null-control: pure product H ===")
nA3, nB3 = 1, 2
H_ts_only = np.kron(Z, np.eye(4))
phi_xcut_ts = Phi_xcut(H_ts_only, np.eye(8), nA3, nB3)
print(f"  Phi_xcut(Z tensor I, I, 1+2) = {phi_xcut_ts:.6f}  [expect 1.0 = fully local]")
H_full_local = np.kron(Z, np.eye(4)) + np.kron(I2, np.kron(Z, I2)) + np.kron(I2, np.kron(I2, Z))
phi_xcut_full = Phi_xcut(H_full_local, np.eye(8), nA3, nB3)
print(f"  Phi_xcut(Z+IZ+IIZ, I, 1+2)  = {phi_xcut_full:.6f}  [fully local on each factor]")
print()

# ============================================================
print("=== Test 6: n-trend Phi_12 Haar baseline decay ===")
for nn in [3,4,5,6]:
    C_n2 = sum(comb(nn,k)*3**k for k in range(3))
    frac = C_n2 / 4**nn
    print(f"  n={nn}: C(n,<=2)={C_n2}, 4^n={4**nn}, Phi_12_baseline={frac:.5f}")
print()

# ============================================================
print("=== Test 7: mcts frame space size vs n ===")
print("Product-unitary frame space (16 choices/qubit):")
for nn in [4,5,6,7,8]:
    leaves = 16**nn
    print(f"  n={nn}: 16^n = {leaves:.2e} leaves")
print()
print("Two-qubit gate frame (branching per entangling-power design):")
for nn in [4,5,6]:
    B_per_layer = nn*(nn-1)//2 * 3 * 8
    leaves_3L = B_per_layer**3
    print(f"  n={nn}: B_per_layer={B_per_layer}, depth-3 tree = {leaves_3L:.2e} leaves")
print()
print("Commutant design (6^n frame space):")
for nn in [4,6,8]:
    print(f"  n={nn}: 6^n = {6**nn:.2e} leaves")
