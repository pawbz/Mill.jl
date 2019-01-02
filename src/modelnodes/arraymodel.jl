"""
struct ArrayModel{T <: MillFunction} <: MillModel
m::T
end

use a Chain, Dense, or any other function on an ArrayNode
"""
struct ArrayModel{T <: MillFunction} <: MillModel
    m::T
end

Flux.@treelike ArrayModel

(m::ArrayModel)(x::ArrayNode) = mapdata(x -> m.m(x), x)

modelprint(io::IO, m::ArrayModel; pad=[]) = paddedprint(io, m.m, "\n")
