#=
ellipse_sino.jl
2019-07-12, Helena H
2019-07-13, Jeff Fessler, refactor to use sg.geom
=#

using Plots

export ellipse_sino

"""
`sino = ellipse_sino(sg, ells ; oversample=1, xscale=1, yscale=1)`

Create sinogram projection of one or more ellipses.
Works for both parallel-beam geometry and for fan-beam geometry.

in
- `sg::MIRT_sino_geom,`		sinogram geometry object from `sino_geom()`
- `ells::Matrix`			`[ne 6]` ellipse parameters
							`[centx centy radx rady angle_degrees amplitude]`

options
- `oversample::Integer`	oversampling factor for emulating "strips"
						default 1: just 1 ray per detector element
- `xscale::Integer`		use -1 to flip in x (not recommended); default 1
- `yscale::Integer`		use -1 to flip in y (not recommended); default 1


out
- `sino`		`[nb na]` sinogram

To get the sample locations, use `(pos,ang) = sg.grid`
"""
function ellipse_sino(sg::MIRT_sino_geom, ells::AbstractMatrix{<:Real} ;
		oversample::Integer=1, kwargs...)

	sg = sg.over(oversample)
	(rg, ϕg) = sg.grid
	sino = ellipse_sino(rg, ϕg, ells; kwargs...)
	if oversample > 1
		sino = downsample2(sino, [oversample 1])
	end
	return sino
end


"""
`sino = ellipse_sino(rg::AbstractArray{<:Real}, ϕg::AbstractArray{<:Real},
		ells ; oversample=1, xscale=1, yscale=1)`

Create sinogram projection of one or more ellipses,
for arbitrary radial/angular sampling grid locations `(rg, ϕg)`

in
- `rg::AbstractArray{<:Real}`	radial sampling locations
- `ϕg::AbstractArray{<:Real}`	angular sampling locations (radians)
- `ells::Matrix`			`[ne 6]` ellipse parameters
							`[centx centy radx rady angle_degrees amplitude]`

options
- `xscale::Integer`		use -1 to flip in x (not recommended); default 1
- `yscale::Integer`		use -1 to flip in y (not recommended); default 1

out
- `sino::AbstractArray{Float32}` same size as `rg` and `ϕg`
"""
function ellipse_sino(rg::AbstractArray{<:Real}, ϕg::AbstractArray{<:Real},
		ells::AbstractMatrix{<:Real} ;
		xscale::Integer=1,
		yscale::Integer=1,
	)

	size(ells,2) != 6 && throw("6 parameters per ellipse")
	size(rg) != size(ϕg) && throw("rg and ϕg size mismatch")

	sino = zeros(Float32, size(rg))

	cangs = cos.(ϕg)
	sangs = sin.(ϕg)

	#loop over ellipses
	#ticker reset

	ne = size(ells, 1)
	for ie in 1:ne
		#ticker(mfilename, ie, ne)
		ell = ells[ie, :]

		cx = ell[1] * xscale
		rx = ell[3]
		cy = ell[2] * yscale
		ry = ell[4]
		eang = deg2rad(ell[5])
		val = ell[6]

		if yscale == -1
			eang = -eang
		end
		if xscale == -1
			eang = pi - eang
		end
		scale = 2 * val * rx * ry

		# square of projected radius:
		rp2 = @. (rx * (cangs * cos(eang) + sangs * sin(eang)))^2 +
				(ry * (sangs * cos(eang) - cangs * sin(eang)))^2
		sp = cx * cangs + cy * sangs # radial shift
		dis2 = (rg - sp).^2 # square of distances from center
		@. sino += scale / rp2 * sqrt(max(rp2 - dis2, 0))
	end

	return sino
end


"""
`ellipse_sino()`

shows doc strings
"""
function ellipse_sino()
	@doc ellipse_sino
end


"""
`ellipse_sino_test()`

internal test routine: standard sampling
"""
function ellipse_sino_test()
	ell = [ 40 70 50 150 20 10 ]
	sg = sino_geom(:ge1, down=8)
	ellipse_sino(sg, ell; xscale=-1, yscale=-1) # test scale
	true
end


"""
`ellipse_sino_show()`
"""
function ellipse_sino_show()
	down = 4
	ell = [ 40 70 50 150 20 10 ]

#	ig = image_geom(nx=512, ny=504, dx=1)
#	xtrue = ellipse_im(ig, ell; oversample=4)

	orbit = 360
	geoms = (
		sino_geom(:par, nb = 888, na = 984, down=down, d = 0.5, orbit=orbit,
			offset = 0.25),
		sino_geom(:fan, nb = 888, na = 984, d = 1.0, orbit = orbit,
			offset = 0.75, dsd = 949, dod = 408, down=down),
		sino_geom(:fan, nb = 888, na = 984, d = 1.0, orbit = orbit,
			offset = 0.75, dsd = 949, dod = 408, down=down,
			dfs = Inf, source_offset = 0.7), # flat fan
		sino_geom(:moj, nb = 888, na = 984, down=down, d = 0.5, orbit=orbit,
			offset = 0.25),
	)

	oversample = 4

	ngeom = length(geoms)
	pl = Array{Plot}(undef, ngeom)

	for ii=1:ngeom
		sg = geoms[ii]
		sino = ellipse_sino(sg, ell; oversample=oversample,
			xscale=-1, yscale=-1)
		dfs = sg.how == :fan ? " dfs=$(sg.dfs)" : ""
		pl[ii] = jim(sino, title="$(sg.how)$dfs")
	end
	plot(pl...)
end


"""
`ellipse_sino(:test)`

`ellipse_sino(:show)`
"""
function ellipse_sino(test::Symbol)
	if test == :show
		return ellipse_sino_show()
	end
	test != :test && throw(ArgumentError("test $test"))
	ellipse_sino() # doc
	ellipse_sino_test()
	ellipse_sino(:show)
	true
end

#ellipse_sino(:show)
