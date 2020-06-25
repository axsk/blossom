using LsqFit
using Plots

function myfit(x)
    xs = x[:,1]
    xs = xs .- minimum(xs)

    ys = x[:,2]

    @. model(x, p) = p[1]*exp(-x*p[2]) + p[3]

    p0 = [-0.1, 0, 6000]

    fit = curve_fit(model, xs, ys, p0)
    plot(xs, fitfun(fit))
    plot!(xs, ys)
end

function fitfun(fit)
    p = fit.param
    x->p[1]*exp(-x*p[2]) + p[3]
end

using Optim

function myloss(xs::Vector)
    n = length(xs)

    tss = [x[:,1] for x in xs]
    tss = [(ts .- minimum(ts)) ./ 3600 for ts in tss]
    ws = [x[:,2] for x in xs]
    
    dts = map(diff, tss)
    ttotal = sum(sum.(dts))

    model(t, alpha, offset, shift, temp, tempscale) = exp(alpha * (t+shift)) + offset + tempscale * temp

    function loss(p)
        alpha = p[1]
        offset = p[2]
        tempshift = p[3]
        #tempshift = 0
        #tempshift = -.1
        tempscale = p[4]
        shifts = p[5:end]

        loss = 0.
        for i in 1:n
            #shiftedtemp = xs[i][timeshiftinds(tss[i], tempshift),4]
            ts = tss[i]
            x  = xs[i]

            temps = timeshift(ts, tempshift, x[:,4])
            for j = 1:length(tss[i]) - 1
                f = model(tss[i][j], alpha, offset, shifts[i],temps[j], tempscale)
                loss += (ws[i][j] - f)^2 * dts[i][j]
            end
        end
        loss / ttotal
    end

    x0 = vcat([-0.01, 5700, -.1, 10 ],  [-680 for i in 1:n])

    @show opt = optimize(loss, x0, iterations=10000)
    @show p = opt.minimizer
    alpha = p[1]
    offset = p[2]
    tempshift = p[3]
    #tempshift = 0
    tempscale = p[4]
    shifts = p[5:end]

    p = Plots.plot()
    for i in 1:n
        ts = tss[i]
        shift = shifts[i]
        temps = timeshift(ts, tempshift, xs[i][:,4])
        scatter!(ts .+ shift, ws[i], marker=:cross, alpha=0.5)
        Plots.plot!(ts .+ shift, model.(ts, alpha, offset, shift, temps, tempscale), label="", color=:black)
    end
    p

end


""" get the indices for the ts shifted by shift
note: requires ts to be sorted """
function timeshiftinds(ts, shift)
    js = similar(ts, Int)
    n = length(ts)
    i = 1
    j = 1
    while true
        if ts[j] >= ts[i] + shift
            js[i] = j
            i += 1
        else
            j += 1
        end
        if j > n
            js[i:end] .= n
            break
        end
        if i > n
            break
        end
    end
    js
end


""" get the indices for the ts shifted by shift
note: requires ts to be sorted """
function timeshift(ts, shift, data=1:length(ts))
    ds = similar(data)
    n = length(ts)
    i = 1
    j = 1
    while true
        if ts[j] >= ts[i] + shift
            ds[i] = data[j]
            i += 1
        else
            j += 1
        end
        if j > n
            ds[i:end] .= data[n]
            break
        end
        if i > n
            break
        end
    end
    ds
end