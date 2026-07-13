# born_proto.py — design de-risk prototype for the `trace-born` tool (NOT the tool; evidence).
# Validates, in plain numpy, every declared quantity in contracts/trace-born.contract.md v1.0.0:
#   brute-force full-state construction + partial trace  vs  the analytic Gram oracle (I-11),
#   the STEP-B fine-graining micro-branch flatness, the STEP-A envariance residual, the purity
#   witness, the partial-decoherence negative control. If the CUDA reproduces THESE numbers, it is right.
#
# HONESTY NOTE (flagged by the cold two-pass): this prototype's rho_S IS a genuine partial trace of the
# materialized d^(R+1) state, but its trace-WEIGHTS (num_i) use the closed-form G_ia^{2R} in BOTH the
# `brute_force` and `analytic` functions -- so the prototype's two weight paths are NOT mutually independent.
# This file only de-risks the MATH (the expected numbers). The SHIPPED tool (trace-born.cu) computes num_i by a
# genuine state contraction (kOverlap over the materialized state), independent of the analytic Gram path -- the
# real I-11 cross-check lives in the .cu, and the two-pass confirmed it empirically. Prototype = evidence, not the shipped path.
import numpy as np, itertools, math

def records(d, s):
    """d record vectors in d-dim fragment space with <r_i|r_j> = s (i!=j), 1 (i=i). Real, via Cholesky of G."""
    G = (1.0 - s) * np.eye(d) + s * np.ones((d, d))
    L = np.linalg.cholesky(G)          # G = L L^T ; rows of L are the record vectors
    return L                            # r_i = L[i], so <r_i|r_j> = (L L^T)_{ij} = G_{ij}

def amps(weights, phase):
    M = sum(weights); d = len(weights)
    return np.array([math.sqrt(w / M) * complex(math.cos(i*phase), math.sin(i*phase))
                     for i, w in enumerate(weights)]), M

def brute_force(weights, R, s, phase):
    d = len(weights); c, M = amps(weights, phase); r = records(d, s)
    # dense global state |Psi> = sum_i c_i |i>_S (x) |r_i>^{(x)R}, dim d^(R+1)
    dim = d ** (R + 1)
    psi = np.zeros(dim, dtype=complex)
    for i in range(d):
        for env in itertools.product(range(d), repeat=R):
            amp = c[i]
            for e in env:
                amp *= r[i][e]
            idx = i
            for e in env:
                idx = idx * d + e
            psi[idx] = amp
    # reduced rho_S by brute-force partial trace over the R env indices
    rho = np.zeros((d, d), dtype=complex)
    psi_t = psi.reshape([d] + [d] * R)                 # [system, e1..eR]
    for a in range(d):
        for b in range(d):
            rho[a, b] = np.sum(psi_t[a] * np.conj(psi_t[b]))
    # redundancy-defined branch projection Pi_i = I_S (x) |r_i><r_i|^{(x)R}; normalized trace weight
    num = np.zeros(d)
    for i in range(d):
        Pr = np.outer(r[i], r[i])                       # |r_i><r_i| on one fragment (real)
        # <Psi|Pi_i|Psi> = sum_a |c_a|^2 * (<r_i|r_a>)^{2R}
        acc = 0.0
        for a in range(d):
            acc += (abs(c[a])**2) * (float(r[i] @ r[a]))**(2*R)
        num[i] = acc
    w_trace = num / num.sum()
    # single-fragment read (objectivity): num1_i = sum_a |c_a|^2 (<r_i|r_a>)^2
    num1 = np.array([sum((abs(c[a])**2) * (float(r[i] @ r[a]))**2 for a in range(d)) for i in range(d)])
    w_trace1 = num1 / num1.sum()
    return rho, w_trace, w_trace1, c, M

def analytic(weights, R, s, phase):
    d = len(weights); c, M = amps(weights, phase); G = (1.0 - s)*np.eye(d) + s*np.ones((d, d))
    num = np.array([sum((abs(c[a])**2) * (G[i, a])**(2*R) for a in range(d)) for i in range(d)])
    return num / num.sum()

def finegrain(weights):
    """STEP B: unitary U_E on E refines d branches into M equal-modulus micro-branches (receipt's construction)."""
    d = len(weights); M = sum(weights)
    cols = []
    off = 0
    for i, w in enumerate(weights):
        col = np.zeros(M); col[off:off+w] = 1.0/math.sqrt(w); cols.append(col); off += w
    # Gram-Schmidt complete to a full M-dim orthonormal basis
    basis = [np.eye(M)[j] for j in range(M)]
    for v in basis:
        w = v.astype(complex).copy()
        for u in cols:
            w = w - (np.vdot(u, w)) * np.asarray(u, dtype=complex)
        nw = np.linalg.norm(w)
        if nw > 1e-9 and len(cols) < M:
            cols.append((w/nw).real)
    U = np.array(cols).T                                # columns are the images: U[:,i] = col_i
    unit_dev = np.max(np.abs(U.conj().T @ U - np.eye(M)))
    # coarse env state: amplitude sqrt(w_i/M) on the i-th coarse pointer |i> (i<d); refine forward U @ psi
    psi = np.zeros(M)
    for i, w in enumerate(weights):
        psi[i] = math.sqrt(w/M)
    fine = U @ psi
    micro = np.abs(fine[np.abs(fine) > 1e-12])
    flat_dev = float(np.max(np.abs(micro - 1.0/math.sqrt(M))))
    return unit_dev, flat_dev, len(micro), M

def envariance(phase, a, b):
    """STEP A residual: ||CSWAP_E SWAP_S |psi> - |psi>|| for a 2-branch (a|s1e1> + b e^{iphi}|s2e2>) pair."""
    ph = complex(math.cos(phase), math.sin(phase))
    psi = np.array([a, 0, 0, b*ph], dtype=complex)               # |11>,|12>,|21>,|22>
    SWAP_S = np.array([[0,0,1,0],[0,0,0,1],[1,0,0,0],[0,1,0,0]], dtype=complex)
    CSWAP_E = np.array([[0, ph.conjugate(),0,0],[ph,0,0,0],[0,0,0,ph.conjugate()],[0,0,ph,0]], dtype=complex)
    after = CSWAP_E @ (SWAP_S @ psi)
    return float(np.linalg.norm(after - psi))

if __name__ == "__main__":
    print("=== GOLDEN case: d=2 weights [2,3] R=6 full (s=0) phase=0 ===")
    rho, wt, wt1, c, M = brute_force([2,3], 6, 0.0, 0.0)
    wa = analytic([2,3], 6, 0.0, 0.0)
    born = np.abs(c)**2
    print("  born target      :", born)
    print("  trace weights (BF):", wt)
    print("  trace weights (an):", wa)
    print("  born_max_dev      :", float(np.max(np.abs(wt - born))))
    print("  oracle_max_dev    :", float(np.max(np.abs(wt - wa))))
    print("  rho_purity        :", float(np.real(np.trace(rho @ rho))), " (expect 0.52)")
    print("  offdiag_max       :", float(np.max(np.abs(rho - np.diag(np.diag(rho))))))
    print("  objectivity_dev   :", float(np.max(np.abs(wt - wt1))))
    ud, fd, nm, MM = finegrain([2,3])
    print("  finegrain: unit_dev=%.2e flat_dev=%.2e micro=%d/%d (all 1/sqrt(5)=%.6f)" % (ud, fd, nm, MM, 1/math.sqrt(5)))
    print("  envariance_residual (equal moduli 1/sqrt2):", envariance(0.7, 1/math.sqrt(2), 1/math.sqrt(2)))
    print("  envariance_break    (unequal 0.4,0.6 amps):", envariance(0.0, math.sqrt(2/5), math.sqrt(3/5)))
    print("  flat_dev control (|1/d - born|):", float(np.max(np.abs(1.0/2 - born))))

    print("\n=== NEGATIVE CONTROL: partial decoherence s=0.5, R=2 ===")
    rho2, wt2, wt12, c2, _ = brute_force([2,3], 2, 0.5, 0.0)
    wa2 = analytic([2,3], 2, 0.5, 0.0)
    born2 = np.abs(c2)**2
    print("  born target      :", born2)
    print("  trace weights (BF):", wt2)
    print("  born_max_dev      :", float(np.max(np.abs(wt2 - born2))), " (should be > tol 1e-4 -> G-BORN-MISMATCH)")
    print("  oracle_max_dev    :", float(np.max(np.abs(wt2 - wa2))))
    print("  offdiag_max       :", float(np.max(np.abs(rho2 - np.diag(np.diag(rho2))))), " (should be > coh_tol -> G-NOT-DECOHERED)")
    print("  objectivity_dev   :", float(np.max(np.abs(wt2 - wt12))), " (single frag disagrees with full -> redundancy matters)")

    print("\n=== complex path: d=3 weights [1,2,3] R=4 full phase=0.5 ===")
    rho3, wt3, _, c3, _ = brute_force([1,2,3], 4, 0.0, 0.5)
    print("  born_max_dev      :", float(np.max(np.abs(wt3 - np.abs(c3)**2))))
    print("  oracle_max_dev    :", float(np.max(np.abs(wt3 - analytic([1,2,3], 4, 0.0, 0.5)))))
    print("  rho hermitian dev :", float(np.max(np.abs(rho3 - rho3.conj().T))))
