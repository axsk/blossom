using Plots

module ard

using LibSerialPort
using Dates
using DelimitedFiles
using Plots

export plot, request, readall

nows() = round(Int, Dates.datetime2epochms(now()) / 1000)

request(n=128) = log(true,n)

function log(request=false, maxread = false) 
    data = []
    offset = 0
    try
        open("COM3", 115200) do p
            if request
                write(p, ".")
            end
            while true
                @show r = readuntil(p, '-', Inf)
                x = parseline(r)
                println(x)
                if (length(x) == 1) || !request# received the current time
                    @show offset = nows() - round(Int, x[1] / 1000)
                end
                if length(x) == 6
                    push!(data, x)
                end
                (length(data) == maxread) && break
            end
        end
    catch e
        isa(e, InterruptException) || rethrow(e)
    end
    data = hcat(data...)' |> collect
    data[:,1] = round.(Int, data[:,1] / 1000) .+ offset
    data
end


function parseline(s)
    matches = eachmatch(r"(\w+)(?:\s|=)(\d+\.*\d*|nan)", s) |> collect
    map(matches) do match
        if match.captures[2]  == "nan"
            0
        else
            parse(Int, match.captures[2])
        end
    end
end

sortlog(data) = data[sortperm(data[:,1]),:]

kill(t) = Base.throwto(t, InterruptException())

t = nothing

function startlog() 
    global t = @async log()
end 
stoplog() = kill(t)

function save(data)
    t = replace(string(todatetime(maximum(data[:,1]))), ":"=>"-")
    writedlm("data/$t.csv", data)
end

todatetime(x) = Dates.epochms2datetime(x*1000)
todatetime(x::Array) = hcat(todatetime.(x[:,1]), x[:,2:end])

function preplot(data)
    data = data[sortperm(data[:,1]),:]
    t = Dates.epochms2datetime.(data[:,1]*1000)
    x = data[:,2:end]
    x = x .- minimum(x, dims=1)
    x = x ./ maximum(x, dims=1)
    t,x
end

function plot(data)
    data = preplot(data)
    Plots.plot(data..., labels=["weight" "dryness" "temp" "air" "light"])
end

function readall(;from = DateTime(2020, 6, 2, 0,0), dir = "data")
    time = Dates.datetime2epochms(from) / 1000
    dats = cd(dir) do
        d=map(readdlm, readdir())
    end
    data = vcat(dats...)
    data = hcat(filter(x->x[1] > time, eachrow(data)|>collect)...)' |> collect 
    round.(Int, data)
    
end

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

function filterbytime(f, x)
    hcat(filter(x->f(x[1]), eachrow(x)|>collect)...)' |> collect
end

function filterrows(f, x)
    hcat(filter(x->f(x), eachrow(x)|>collect)...)' |> collect
end

function auto()
    data = ard.request()
    ard.save(data)
    p = ard.plot(ard.readall())
    savefig("plot.png")
    data, p
end