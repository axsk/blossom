module ard

using LibSerialPort
using Dates
using DelimitedFiles
using Plots

export plot, request


lastadd = 0

nows() = round(Int, Dates.datetime2epochms(now()) / 1000)

resetstore!() = (global store = reshape(Float64[],0,6))

if !isdefined(ard, :store) 
    resetstore!()
end

function request(n=128)
    return log(true,n)
end

function log(request=false, maxread = false) 
    @show data = []
    try
        open("COM3", 115200) do p
            if request
                write(p, ".")
            end
            while true
                r = readuntil(p, '-', Inf)
                #@show r
                x = parseline(r)
                println(x)
                if length(x) == 6
                    push!(data, x)
                    lastadd = nows()
                end
                if length(data) == maxread
                    break
                end
            end
        end
    catch e
        isa(e, InterruptException) || rethrow(e)
    end
    data = hcat(data...)' |> collect
    data[:,1] = round.(Int, (data[:,1] .- data[end,1]) ./ 1000) .+ nows()
    appendstore!(data)
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

function appendstore!(data)
    global store
    store = vcat(store, data)
end


kill(t) = Base.throwto(t, InterruptException())

t = nothing

function startlog() 
    global t = @async log()
end 
stoplog() = (try kill(t) catch end)

function save(data=store)
    writedlm("data/"*string(nows())*".csv", data)
end

function preplot(data=store)
    data = data[sortperm(data[:,1]),:]
    t = Dates.epochms2datetime.(data[:,1]*1000)
    x = data[:,2:end]
    x = x .- minimum(x, dims=1)
    x = x ./ maximum(x, dims=1)
    t,x
end

function plot(data=store)
    data = preplot(data)
    Plots.plot(data..., labels=["weight" "dryness" "temp" "air" "light"], legend=:right)
end

end