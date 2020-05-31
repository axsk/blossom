using LibSerialPort
using Dates
using DelimitedFiles

if !isdefined(Main, :data) 
    data = []
end

lastadd = 0

nows() = round(Int, Dates.datetime2epochms(now()) / 1000)

function log() 
    open("COM3", 115200) do p
        while true
            r = readuntil(p, '-', Inf)
            @show r
            x = eachmatch(r"(\w+)(?:\s|=)(\d+).*", r) |> collect
            if length(x) == 5
                push!(data, [parse(Int,x.captures[2]) for x in x])
                lastadd = nows()
            end
        end
    end
end

kill(t) = Base.throwto(t, InterruptException())

t = nothing
function startlog() 
    global t = @async log()
end 
stoplog() = (try kill(t) catch end)

function save()
    x = hcat(data...)'
    x[:,1] = x[:,1] .- x[end,1] .+ nows()
    writedlm("data/"*string(nows())*".csv", x)
    x
end
