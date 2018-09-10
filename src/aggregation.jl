using Flux.Tracker: TrackedArray, param

# https://arxiv.org/pdf/1311.1780.pdf
struct PNorm{T}
	ρ::T
	c::T
end

PNorm(d::Integer) = PNorm(param(randn(d)), param(randn(d)))
Flux.treelike(PNorm)

(n::PNorm)(x, bags) = segmented_pnorm(x, bags, p_map(n.ρ), n.c)

p_map(ρ) = 1 .+ log.(1 .+ exp.(ρ))
inv_p_map(p) = log.(exp.(p-1) .- 1)

function segmented_pnorm(x, bags, p, c)
	o = zeros(eltype(p), size(x, 1), length(bags))
	@inbounds for (j, b) in enumerate(bags)
		for bi in b
			for i in 1:size(x, 1)
				o[i, j] += abs(x[i, bi] - c[i]) ^ p[i]
			end
		end
		o[:, j] ./= max(1, length(b))
		o[:, j] .^= 1 ./ p
	end
	o
end

function segmented_pnorm_back(x, n, bags, p, c, Δ)
	o = zero(x)
	dp = zero(p)
	dps1 = zero(p)
	dps2 = zero(p)
	dc = zero(c)
	dcs = zero(c)
	@inbounds for (j, b) in enumerate(bags)
		dcs .= 0
		dps1 .= 0
		dps2 .= 0
		for bi in b
			for i in 1:size(x,1)
				ab = abs(x[i, bi] - c[i])
				sig = sign(x[i, bi] - c[i])
				o[i, bi] = Δ[i, j] * sig
				o[i, bi] /= max(1, length(b))
				o[i, bi] *= (ab / n[i, j]) ^ (p[i] - 1)
				dps1[i] +=  ab ^ p[i] * log(ab)
				dps2[i] +=  ab ^ p[i]
				dcs[i] -= sig * (ab ^ (p[i] - 1))
			end
		end
		t = n[:, j] ./ p .* (dps1 ./ dps2 .- (log.(dps2) .- log(max(1, length(b)))) ./ p)
		dp .+= Δ[:, j] .* t
		dcs ./= max(1, length(b))
		dcs .*= n[:, j] .^ (1 .- p)
		dc .+= Δ[:, j] .* dcs
	end
	o, dp , dc
end

function segmented_mean(x::Matrix, bags::Bags)
	o = zeros(eltype(x), size(x, 1), length(bags))
	@inbounds for (j, b) in enumerate(bags)
		for bi in b
			for i in 1:size(x, 1)
				o[i,j] += x[i,bi]
			end
		end
		o[:,j] ./= max(1, length(b))
	end
	o
end

function segmented_mean_back(x::Matrix, bags::Bags, Δ::Matrix)
	o = similar(x, size(x))
	@inbounds for (j, b) in enumerate(bags)
		for bi in b
			for i in 1:size(x,1)
				o[i,bi] = Δ[i,j] / length(b)
			end
		end
	end
	o
end

function segmented_weighted_mean(x::Matrix, bags::Bags, w::Vector)
	o = zeros(eltype(x), size(x, 1), length(bags))
	@inbounds for (j,b) in enumerate(bags)
		ws = sum(w[b])
		for bi in b
			for i in 1:size(x, 1)
				o[i,j] += w[bi] * x[i,bi]
			end
		end
		o[:,j] ./= max(1, ws)
	end
	o
end

function segmented_weighted_mean_back(x::Matrix, bags::Bags, w::Vector, Δ::Matrix)
	o = similar(x, size(x))
	@inbounds for (j, b) in enumerate(bags)
		ws = sum(w[b])
		for bi in b
			for i in 1:size(x,1)
				o[i, bi] = w[bi] * Δ[i, j] / ws
			end
		end
	end
	o
end

function segmented_max(x::Matrix, bags::Bags)
	o = similar(x, size(x,1), length(bags))
	fill!(o, typemin(eltype(x)))
	for (j,b) in enumerate(bags)
		for bi in b
			for i in 1:size(x, 1)
				o[i,j] = max(o[i,j],x[i,bi])
			end
		end
	end
	o[o.== typemin(eltype(x))] .= 0
	o
end

function segmented_max_back(x::Matrix, bags::Bags, Δ::Matrix)
	o = similar(x, size(x))
	fill!(o, 0)
	v = similar(x, size(x,1))
	idxs = zeros(Int,size(x,1))
	@inbounds for (j,b) in enumerate(bags)
		fill!(v, typemin(eltype(x)))
		for bi in b
			for i in 1:size(x, 1)
				if v[i] < x[i,bi]
					idxs[i] = bi
					v[i] = x[i,bi]
				end
			end
		end

		for i in 1:size(x, 1)
			o[i,idxs[i]] = Δ[i,j]
		end
	end
	o
end

function segmented_meanmax(x::Matrix, bags::Bags)
	d = size(x, 1)
	o = similar(x, 2*d, length(bags))
	fill!(view(o, 1:d, :), typemin(eltype(x)))
	fill!(view(o, d+1:2d, :), 0)
	for (j, b) in enumerate(bags)
		for bi in b
			for i in 1:d
				o[i, j] = max(o[i, j], x[i, bi])
				o[i+d, j] += x[i, bi] / max(length(b), 1)
			end
		end
	end
	o
end

function segmented_meanmax_back(x::Matrix, bags::Bags, Δ::Matrix)
	d = size(x, 1)
	o = similar(x, size(x))
	fill!(o, 0)
	v = similar(x, d)
	idxs = zeros(Int, d)
	@inbounds for (j, b) in enumerate(bags)
		fill!(v, typemin(eltype(x)))
		for bi in b
			for i in 1:d
				if v[i] < x[i, bi]
					idxs[i] = bi
					v[i] = x[i, bi]
				end
				o[i, bi] += Δ[i+d, j] / length(b)
			end
		end

		for i in 1:size(x,1)
			o[i,idxs[i]] += Δ[i,j]
		end
	end
	o[ o.== typemin(eltype(x))] .= 0
	o
end


function segmented_weighted_meanmax(x::Matrix, bags::Bags, w::Vector)
	d = size(x, 1)
	o = similar(x, 2*d, length(bags))
	fill!(view(o, 1:d, :), typemin(eltype(x)))
	fill!(view(o, d+1:2d, :), 0)
	for (j, b) in enumerate(bags)
		ws = sum(w[b])
		for bi in b
			for i in 1:d
				o[i, j] = max(o[i, j],x[i, bi])
				o[i+d, j] += w[bi] * x[i, bi] / max(ws, 1)
			end
		end
	end
	o
end

function segmented_weighted_meanmax_back(x::Matrix, bags::Bags, w::Vector, Δ::Matrix)
	d = size(x, 1)
	o = similar(x, size(x))
	fill!(o, 0)
	v = similar(x, d)
	idxs = zeros(Int, d)
	@inbounds for (j, b) in enumerate(bags)
		fill!(v, typemin(eltype(x)))
		ws = sum(w[b])
		for bi in b
			for i in 1:d
				if v[i] < x[i, bi]
					idxs[i] = bi
					v[i] = x[i, bi]
				end
				o[i, bi] += w[bi] * Δ[i+d, j] / ws
			end
		end

		for i in 1:size(x,1)
			o[i, idxs[i]] += Δ[i,j]
		end
	end
	o[o.== typemin(eltype(x))] .= 0
	o
end

# identical by definition
segmented_weighted_max(x, bags, w) = segmented_max(x, bags)
segmented_weighted_max_back(x, bags, w, Δ) = segmented_max_back(x, bags, Δ)

unweighted = [
	:segmented_mean,
	:segmented_max,
	:segmented_meanmax,
]
weighted = [
	:segmented_weighted_mean,
	:segmented_weighted_max,
	:segmented_weighted_meanmax
]

for s in vcat(unweighted, weighted)
	@eval $s(x::ArrayNode, args...) = ArrayNode($s(x.data, args...))
end
(n::PNorm)(x::ArrayNode, args...) = ArrayNode(n(x.data, args...))

for s in unweighted
	@eval $s(x, bags, w) = $s(x, bags)
	@eval $s(x::TrackedArray, bags::Bags) = Flux.Tracker.track($s, x, bags)
end

function segmented_pnorm(x::AbstractArray, bags, p::TrackedArray, c::TrackedArray)
	Flux.Tracker.track(segmented_pnorm, x, bags, p, c)
end

for s in unweighted
	@eval Flux.Tracker.@grad function $s(x, bags)
		$s(Flux.data(x), bags), Δ -> ($(Symbol(string(s) * "_back"))(Flux.data(x), bags, Δ), nothing)
	end
end

Flux.Tracker.@grad function segmented_pnorm(x, bags, p, c)
	n = segmented_pnorm(Flux.data(x), bags, Flux.data(p), Flux.data(c))
	grad = Δ -> begin
		o, dp, dc = segmented_pnorm_back(Flux.data(x), Flux.data(n), bags, Flux.data(p), Flux.data(c), Δ)
		(o, nothing, dp, dc)
	end
	n, grad
end

for s in weighted
	@eval $s(x::TrackedArray, bags, w) = Flux.Tracker.track($s, x, bags, w)
	@eval Flux.Tracker.@grad function $s(x, bags, w)
		$s(Flux.data(x), bags, w), Δ -> ($(Symbol(string(s) * "_back"))(Flux.data(x), bags, w, Δ), nothing, nothing)
	end
end
