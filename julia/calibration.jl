using GLM


function shift(x1, x2, n)
    x1[1+n:end,:], x2[1:end-n,:]
end

# 1600 seconds was a good delay
function calibrationdata(shiftby=1600)
    dl = readdlm("calibration/scale.csv")[:,[2,4]]
    dl = shift(dl, shiftby)
    dn = readdlm("calibration/scaleneutral.csv")[:,[2,4]]
    dl = hcat(dl, ones(size(dl,1)) * 1043)
    dn = hcat(dn, zeros(size(dn,1)))
    vcat(dl,dn)
end

fitweightcoeffs(x::Array) = lm(@formula(x3 ~ x1 + x2), DataFrame(x))

#= 
Coefficients:
────────────────────────────────────────────────────────────────────────────────
               Estimate  Std. Error    t value  Pr(>|t|)   Lower 95%   Upper 95%
────────────────────────────────────────────────────────────────────────────────
(Intercept)  -53.5249    0.0857742    -624.02     <1e-99  -53.693     -53.3567
x1             0.220758  1.13252e-5  19492.6      <1e-99    0.220736    0.220781
x2            -1.40055   0.00271404   -516.041    <1e-99   -1.40587    -1.39523
────────────────────────────────────────────────────────────────────────────────
=#