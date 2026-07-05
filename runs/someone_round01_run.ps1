# someone — round-01 reproduction runner (S5). Reproducibility artifact: the exact way the
# science calls `someone` for the de-confounded, multi-seed complexity sweep (BITE #3, D-DAK-RNG).
# Runs L0..L3 at a fixed config with an ensemble of n=24 replicas (seed+r), fixed RNG (confound
# fixed), steps=800 so L3's night fires. Saves per-level JSON + CSV under runs/round01/.
#
# Usage:  powershell -NoProfile -File runs/someone_round01_run.ps1
$ErrorActionPreference = "Stop"
$exe = "C:\ORRERY\tools\someone\someone.exe"
$out = "C:\ORRERY\runs\round01"
New-Item -ItemType Directory -Force $out | Out-Null

$common = @("--pop","120","--gens","70","--steps","800","--N","128","--k","32",
            "--zombie-frac","0.5","--mut-rate","0.02","--mut-str","0.1",
            "--ensemble","24","--seed","20260705")

Write-Output "level,exit,delta_fit,winner,win_rate,p_value,mean_pure_gap,zombie_extinct_gen,normal_alive,zombie_alive"
foreach ($L in "L0","L1","L2","L3") {
    $json = & $exe @common "--complexity" $L "--csv" "$out\round01_$L.csv" "--json" 2>$null
    $code = $LASTEXITCODE
    $json | Out-File -Encoding utf8 "$out\round01_$L.json"
    $o = $json | ConvertFrom-Json
    $r = $o.result
    Write-Output ("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f `
        $L,$code,$r.delta_fit,$r.winner,$r.win_rate,$r.p_value,$r.mean_pure_gap,`
        $r.zombie_extinct_gen,$r.normal_alive_final,$r.zombie_alive_final)
}
Write-Output "DONE — per-level JSON + CSV in $out"
