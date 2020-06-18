module ard

    using LibSerialPort
    using Dates
    using DelimitedFiles
    using Plots

    export aplot, request, readall, save, auto, process, smoothdata

    Base.isless(d::DateTime, x::Number) = toseconds(d) < x
    
    todatetime(x::Number) =  Dates.epochms2datetime(x*1000)
    toseconds(x::DateTime) = Dates.datetime2epochms(x) / 1000

    todatetime(x::Array{T,2}) where T = hcat(todatetime.(x[:,1]), x[:,2:end])
    
    nows() = round(Int, Dates.datetime2epochms(now()) / 1000)

    request(n=80) = log(request=true,maxread=n)

    function log(;request=false, maxread = false, liveplot=false, verbose=false) 
        data = []
        offset = 0
        try
            open("COM3", 115200) do p
                if request
                    write(p,Char(1))
                end
                while true
                    r = readuntil(p, '-', Inf)
                    x = parseline(r)
                    if verbose
                        print(r)
                        print(x)
                    else
                        print(".")
                    end
                    if occursin("average", r)
                        continue
                    end
                    #println(x)
                    if (length(x) == 1) || !request# received the current time
                        offset = nows() - round(Int, x[1])
                    end
                    if length(x) == 7
                        push!(data, x)
                        let data = data
                            data = hcat(data...)' |> collect
                            data[:,1] = round.(Int, data[:,1]) .+ offset
                            if liveplot
                                aplot(data) |> display
                            end
                        end
                    end
                    (length(data) == maxread) && break
                end
            end
        catch e
            isa(e, InterruptException) || rethrow(e)
        end
        data = hcat(data...)' |> collect
        data[:,1] = round.(Int, data[:,1]) .+ offset
        data
    end


    function parseline(s)
        matches = eachmatch(r"(\w+)(?:\s|=)(\d+\.*\d*|nan)", s) |> collect
        map(matches) do match
            if match.captures[2]  == "nan"
                0
            else
                parse(Float64, match.captures[2])
            end
        end
    end

    function save(data)
        t = replace(string(todatetime(maximum(data[:,1]))), ":"=>"-")
        writedlm("data/$t.csv", data)
    end



    function aplot(data)
        data = data[sortperm(data[:,1]),:]
        t = todatetime.(data[:,1])
        x = data[:,2:end]
        x = x .- minimum(x, dims=1)
        x = x ./ maximum(x, dims=1)
        Plots.plot(t, x, labels=["weight" "dryness" "temp" "air" "pressure" "light"], legend=:outertopright)
    end


    function readall(dir="data", maxlength = 160, proc=true)
        dats = cd(dir) do
            d=map(readdir()) do d
                d = readdlm(d)
                if size(d,2) == 6
                    d = d[:, [1,2,3,4,5,6,6]]
                    d[:,6] .= 0
                end
                d = sortslices(d, dims=1, lt=(x,y) -> x[1]<y[1])
            end
        end
        if maxlength > 0
            dats = filter(x->@show(size(x, 1)) <= maxlength, dats)
        end
        length(dats)
        data = vcat(dats...)
        if proc
            data=process(data)
        end
        data
    end

    function mergewithoutoverlap(d1, d2)
        t1 = maximum(d1[:,1])
        d2 = filterrows(x->x[1]>t1, d2)
        length(d2) == 0 && return d1
        vcat(d1, d2)
    end

    function filterasc(x)
        ts = x[:,1]
        xs = []
        t = 0
        for i = 1:length(ts)
            if ts[i] > t
                t = ts[i]
                push!(xs, x[i, :])
            end
        end
        hcat(xs...)'
    end

    function filterrows(f, x)
        hcat(filter(x->f(x), eachrow(x)|>collect)...)' |> collect
    end

    function auto()
        data = ard.request()
        ard.save(data)
        plotall()
    end

    function plotall()
        data = readall()
        data = process(data, Inf)
        data = smoothdata(data, 60)
        p = aplot(data) |> display
        Plots.savefig("plot.png") 
        p
    end

    function process(d, maxdwdt=Inf)
        d = copy(d)
        n = size(d,1)
        #d = sortslices(d, dims=1)
        d = filterasc(d)
        for i=1:size(d,1)
            (d[i,2] > 10000) && (d[i,2] /= 10) # switched format
            (d[i,4] > 100) && (d[i,4] /= 10)
        end
        if maxdwdt < Inf
            for i=2:size(d,1)-1
                if 1<i<n # outliers of hx711
                    dw = d[i,2] - d[i-1,2]
                    dt = d[i,1] - d[i-1,1]
                    if abs(dw) > maxdwdt * dt
                        d[i,2] = d[i-1,2]
                    end
                end
            end
        end
        return d
    end

    function sortbytime(data)
        data = sortslices(data, dims=1, lt=(x,y) -> x[1]<y[1])
    end

    function process_scale(d)
        d[:,2] = (d[:,2] .- 430) / 4.5
        d
    end

    function smoothdata(d,s)
        g(x,y) = 1/(s*sqrt(2*pi)) * exp(-1/2 * ((x-y)/s)^2)
        ts = d[:,1]
        k = g.(ts,ts')
        k ./= sum(k, dims=2)
        x = d[:,2:end]
        s = hcat(ts, k*x)
        s[:,5] .= 1 # fix for missing data
        s
    end

end

using .ard

calibratedweight(w,t) = -53.5249 + 0.220758 * w - 1.40055 * t

using Statistics
using Plots

function weightvariance(l)
    d = l[:,2] |> diff
    m = l[:,2] |> mean
    @show std(d/m)
    Plots.plot(d/m, ylims = (-0.0005, 0.0005)) |> display
    Plots.plot(d/m |> sort, ylims = (-0.0005, 0.0005)) |> display
end

function cutwater(x, dw=300)
    inds = vcat(1, findall(x[2:end,2] .> x[1:end-1, 2] .+ dw) .+ 1, size(x,1) + 1)
    xs = [x[inds[i]:inds[i+1]-1,:] for i in 1:length(inds)-1]
end