using Flux
import Mill: segmented_mean
import Mill: segmented_max
import Mill: segmented_meanmax
import Flux.Tracker: gradcheck

x1 = randn(2,10)
x2 = Matrix{Float64}(reshape(1:12, 2, 6))
bags1 = [1:5,6:10]
bags2 = [1:1, 2:3, 4:6]
w = [1, 1/2, 1/2, 1/8, 1/3, 13/24]

@testset "aggregation grad check" begin

	@test gradcheck(x -> sum(segmented_mean(x, [1:4])), randn(4, 4))
	@test gradcheck(x -> sum(segmented_mean(x, [1:2, 3:4, 5:5, 6:8])), randn(4, 8))
	@test gradcheck(x -> sum(segmented_mean(x, [1:2, 3:4, 0:-1, 5:5, 6:8])), randn(4, 8))
	@test gradcheck(x -> sum(segmented_max(x, [1:4])), randn(4, 4))
	@test gradcheck(x -> sum(segmented_max(x, [1:4, 5:5, 6:8])), randn(4, 8))
	@test gradcheck(x -> sum(segmented_meanmax(x, [1:4])), randn(4, 4))
	@test gradcheck(x -> sum(segmented_meanmax(x, [1:4, 5:5, 6:8])), randn(4, 8))

	for se in [	x -> sum(segmented_mean(x, bags1)),
				x -> sum(segmented_max(x, bags1)),
				x -> sum(segmented_meanmax(x, bags1)),
		]
		@test gradcheck(se, x1)
	end
	for se in [  x -> sum(segmented_mean(x, bags2, w)),
				x -> sum(segmented_max(x, bags2, w)),
				x -> sum(segmented_meanmax(x, bags2, w))
		]
		@test gradcheck(se, x2)
	end
end

x1 = randn(2,10)
x2 = Matrix{Float64}(reshape(1:12, 2, 6))
bags1 = [1:5,6:10]
bags2 = [1:1, 2:3, 4:6]
w = [1, 1/2, 1/2, 1/8, 1/3, 13/24]
@testset "aggregation functionality" begin
	@test segmented_mean(x2, bags2) ≈ [1.0 4.0 9.0; 2.0 5.0 10.0]
	@test segmented_max(x2, bags2) ≈ [1.0 5.0 11.0; 2.0 6.0 12.0]
	@test segmented_meanmax(x2, bags2) ≈ cat(segmented_mean(x2, bags2), segmented_max(x2, bags2), dims=1)
	@test segmented_mean(x2, bags2, w) ≈ [1.0 4.0 236/24; 2.0 5.0 260/24]
	@test segmented_max(x2, bags2, w) ≈ segmented_max(x2, bags2)
	@test segmented_meanmax(x2, bags2, w) ≈ cat(segmented_mean(x2, bags2, w), segmented_max(x2, bags2, w), dims=1)
end
