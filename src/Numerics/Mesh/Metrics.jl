module Metrics
import GaussQuadrature
using LinearAlgebra

"""
    creategrid!(x1, elemtocoord, ξ1)

Create a 1-D grid using `elemtocoord` (see [`brickmesh`](@ref)) using the 1-D
`(-1, 1)` reference coordinates `ξ1`. The element grids are filled using linear
interpolation of the element coordinates.

If `Nq = length(ξ1)` and `nelem = size(elemtocoord, 3)` then the preallocated
array `x1` should be `Nq * nelem == length(x1)`.
"""
function creategrid!(x1, e2c, ξ1)
    (d, nvert, nelem) = size(e2c)
    @assert d == 1
    Nq = length(ξ1)
    x1 = reshape(x1, (Nq, nelem))

    # linear blend
    @inbounds for e in 1:nelem
        for i in 1:Nq
            x1[i, e] =
                ((1 - ξ1[i]) * e2c[1, 1, e] + (1 + ξ1[i]) * e2c[1, 2, e]) / 2
        end
    end
    nothing
end

"""
    creategrid!(x1, x2, elemtocoord, ξ1, ξ2)

Create a 2-D tensor product grid using `elemtocoord` (see [`brickmesh`](@ref))
using the 1-D `(-1, 1)` reference coordinates `ξ1` and `ξ2`. The element grids
are filled using bilinear interpolation of the element coordinates.

If `Nq = (length(ξ1), length(ξ2))` and `nelem = size(elemtocoord, 3)` then the
preallocated arrays `x1` and `x2` should be
`prod(Nq) * nelem == size(x1) == size(x2)`.
"""
function creategrid!(x1, x2, e2c, ξ1, ξ2)
    (d, nvert, nelem) = size(e2c)
    @assert d == 2
    Nq = (length(ξ1), length(ξ2))
    x1 = reshape(x1, (Nq..., nelem))
    x2 = reshape(x2, (Nq..., nelem))

    # # bilinear blend of corners
    @inbounds for (f, n) in zip((x1, x2), 1:d)
        for e in 1:nelem, j in 1:Nq[2], i in 1:Nq[1]
            f[i, j, e] =
                (
                    (1 - ξ1[i]) * (1 - ξ2[j]) * e2c[n, 1, e] +
                    (1 + ξ1[i]) * (1 - ξ2[j]) * e2c[n, 2, e] +
                    (1 - ξ1[i]) * (1 + ξ2[j]) * e2c[n, 3, e] +
                    (1 + ξ1[i]) * (1 + ξ2[j]) * e2c[n, 4, e]
                ) / 4
        end
    end
    nothing
end

"""
    creategrid!(x1, x2, x3, elemtocoord, ξ1, ξ2, ξ3)

Create a 3-D tensor product grid using `elemtocoord` (see [`brickmesh`](@ref))
using the 1-D `(-1, 1)` reference coordinates `ξ1`. The element grids are filled
using trilinear interpolation of the element coordinates.

If `Nq = (length(ξ1), length(ξ2), length(ξ3))` and
`nelem = size(elemtocoord, 3)` then the preallocated arrays `x1`, `x2`, and `x3`
should be `prod(Nq) * nelem == size(x1) == size(x2) == size(x3)`.
"""
function creategrid!(x1, x2, x3, e2c, ξ1, ξ2, ξ3)
    (d, nvert, nelem) = size(e2c)
    @assert d == 3
    Nq = (length(ξ1), length(ξ2), length(ξ3))
    x1 = reshape(x1, (Nq..., nelem))
    x2 = reshape(x2, (Nq..., nelem))
    x3 = reshape(x3, (Nq..., nelem))

    # trilinear blend of corners
    @inbounds for (f, n) in zip((x1, x2, x3), 1:d)
        for e in 1:nelem, k in 1:Nq[3], j in 1:Nq[2], i in 1:Nq[1]
            f[i, j, k, e] =
                (
                    (1 - ξ1[i]) * (1 - ξ2[j]) * (1 - ξ3[k]) * e2c[n, 1, e] +
                    (1 + ξ1[i]) * (1 - ξ2[j]) * (1 - ξ3[k]) * e2c[n, 2, e] +
                    (1 - ξ1[i]) * (1 + ξ2[j]) * (1 - ξ3[k]) * e2c[n, 3, e] +
                    (1 + ξ1[i]) * (1 + ξ2[j]) * (1 - ξ3[k]) * e2c[n, 4, e] +
                    (1 - ξ1[i]) * (1 - ξ2[j]) * (1 + ξ3[k]) * e2c[n, 5, e] +
                    (1 + ξ1[i]) * (1 - ξ2[j]) * (1 + ξ3[k]) * e2c[n, 6, e] +
                    (1 - ξ1[i]) * (1 + ξ2[j]) * (1 + ξ3[k]) * e2c[n, 7, e] +
                    (1 + ξ1[i]) * (1 + ξ2[j]) * (1 + ξ3[k]) * e2c[n, 8, e]
                ) / 8
        end
    end
    nothing
end


function cutoff_matrix(T, N, N_max)
    if N_max < N
        ξ, _ = GaussQuadrature.legendre(T, N + 1, GaussQuadrature.both)
        a, b = GaussQuadrature.legendre_coefs(T, N)
        V = (N == 0 ? ones(T, 1, 1) : GaussQuadrature.orthonormal_poly(ξ, a, b))
        Σ = ones(T, N + 1)
        Σ[((N_max + 1):N) .+ 1] .= 0
        V * Diagonal(Σ) / V
    else
        Array{T}(I, N + 1, N + 1)
    end
end

"""
    computemetric!(x1, J, JcV, ξ1x1, sJ, n1, D, N_metric)

Compute the 1-D metric terms from the element grid arrays `x1`. All the arrays
are preallocated by the user and the (square) derivative matrix `D` should be
consistent with the reference grid `ξ1` used in [`creategrid!`](@ref).

If `Nq = size(D, 1)` and `nelem = div(length(x1), Nq)` then the volume arrays
`x1`, `J`, and `ξ1x1` should all have length `Nq * nelem`.  Similarly, the face
arrays `sJ` and `n1` should be of length `nface * nelem` with `nface = 2`.

`N_metric` is the max polynomial order to keep for polynomial representataion of
the metric terms.
"""
function computemetric!(x1, J, JcV, ξ1x1, sJ, n1, D, N_metric)
    Nq = size(D, 1)
    nelem = div(length(J), Nq)
    x1 = reshape(x1, (Nq, nelem))
    J = reshape(J, (Nq, nelem))
    JcV = reshape(JcV, (Nq, nelem))
    ξ1x1 = reshape(ξ1x1, (Nq, nelem))
    nface = 2
    n1 = reshape(n1, (1, nface, nelem))
    sJ = reshape(sJ, (1, nface, nelem))

    if N_metric[1] < Nq - 1
        T = eltype(x1)
        fM = cutoff_matrix(T, Nq - 1, N_metric[1])
        x1 .= fM * x1
    end
    @inbounds for e in 1:nelem
        JcV[:, e] = J[:, e] = D * x1[:, e]
    end
    ξ1x1 .= 1 ./ J

    n1[1, 1, :] .= -sign.(J[1, :])
    n1[1, 2, :] .= sign.(J[Nq, :])
    sJ .= 1
    nothing
end

"""
    computemetric!(x1, x2, J, JcV, ξ1x1, ξ2x1, ξ1x2, ξ2x2, sJ, n1, n2, D1, D2,
                   N_metric)

Compute the 2-D metric terms from the element grid arrays `x1` and `x2`. All the
arrays are preallocated by the user and the (square) derivative matrice `D1` and
D2 should be consistent with the reference grid `ξ1` and `ξ2` used in
[`creategrid!`](@ref).

If `Nq = (size(D1, 1), size(D2, 1))` and `nelem = div(length(x1), prod(Nq))`
then the volume arrays `x1`, `x2`, `J`, `ξ1x1`, `ξ2x1`, `ξ1x2`, and `ξ2x2`
should all be of size `(Nq..., nelem)`.  Similarly, the face arrays `sJ`, `n1`,
and `n2` should be of size `(maximum(Nq), nface, nelem)` with `nface = 4`

`N_metric` is the max polynomial order to keep for polynomial representataion of
the metric terms.
"""
function computemetric!(
    x1,
    x2,
    J,
    JcV,
    ξ1x1,
    ξ2x1,
    ξ1x2,
    ξ2x2,
    sJ,
    n1,
    n2,
    D1,
    D2,
    N_metric,
)
    T = eltype(x1)
    Nq = (size(D1, 1), size(D2, 1))
    N = Nq .- 1
    nelem = div(length(J), prod(Nq))
    x1 = reshape(x1, (Nq..., nelem))
    x2 = reshape(x2, (Nq..., nelem))
    J = reshape(J, (Nq..., nelem))
    JcV = reshape(JcV, (Nq..., nelem))
    ξ1x1 = reshape(ξ1x1, (Nq..., nelem))
    ξ2x1 = reshape(ξ2x1, (Nq..., nelem))
    ξ1x2 = reshape(ξ1x2, (Nq..., nelem))
    ξ2x2 = reshape(ξ2x2, (Nq..., nelem))
    nface = 4
    Nfp = div.(prod(Nq), Nq)
    n1 = reshape(n1, (maximum(Nfp), nface, nelem))
    n2 = reshape(n2, (maximum(Nfp), nface, nelem))
    sJ = reshape(sJ, (maximum(Nfp), nface, nelem))

    fM = ntuple(2) do i
        cutoff_matrix(T, N[i], N_metric[i])
    end

    function apply_filter!(fld, e)
        @inbounds if N_metric[1] < N[1]
            for j in 1:Nq[2]
                fld[:, j, e] = fM[1] * fld[:, j, e]
            end
        end
        @inbounds if N_metric[2] < N[2]
            for i in 1:Nq[1]
                fld[i, :, e] = fM[2] * fld[i, :, e]
            end
        end
    end

    @inbounds for e in 1:nelem
        apply_filter!(x1, e)
        apply_filter!(x2, e)
        for j in 1:Nq[2], i in 1:Nq[1]
            x1ξ1 = x1ξ2 = zero(T)
            x2ξ1 = x2ξ2 = zero(T)
            for n in 1:Nq[1]
                x1ξ1 += D1[i, n] * x1[n, j, e]
                x2ξ1 += D1[i, n] * x2[n, j, e]
            end
            for n in 1:Nq[2]
                x1ξ2 += D2[j, n] * x1[i, n, e]
                x2ξ2 += D2[j, n] * x2[i, n, e]
            end
            JcV[i, j, e] = hypot(x1ξ2, x2ξ2)
            J[i, j, e] = x1ξ1 * x2ξ2 - x2ξ1 * x1ξ2
            ξ1x1[i, j, e] = x2ξ2 / J[i, j, e]
            ξ2x1[i, j, e] = -x2ξ1 / J[i, j, e]
            ξ1x2[i, j, e] = -x1ξ2 / J[i, j, e]
            ξ2x2[i, j, e] = x1ξ1 / J[i, j, e]
        end

        for i in 1:maximum(Nfp)
            if i <= Nfp[1]
                n1[i, 1, e] = -J[1, i, e] * ξ1x1[1, i, e]
                n2[i, 1, e] = -J[1, i, e] * ξ1x2[1, i, e]
                n1[i, 2, e] = J[Nq[1], i, e] * ξ1x1[Nq[1], i, e]
                n2[i, 2, e] = J[Nq[1], i, e] * ξ1x2[Nq[1], i, e]
            else
                n1[i, 1:2, e] .= NaN
                n2[i, 1:2, e] .= NaN
            end
            if i <= Nfp[2]
                n1[i, 3, e] = -J[i, 1, e] * ξ2x1[i, 1, e]
                n2[i, 3, e] = -J[i, 1, e] * ξ2x2[i, 1, e]
                n1[i, 4, e] = J[i, Nq[2], e] * ξ2x1[i, Nq[2], e]
                n2[i, 4, e] = J[i, Nq[2], e] * ξ2x2[i, Nq[2], e]
            else
                n1[i, 3:4, e] .= NaN
                n2[i, 3:4, e] .= NaN
            end

            for n in 1:nface
                sJ[i, n, e] = hypot(n1[i, n, e], n2[i, n, e])
                n1[i, n, e] /= sJ[i, n, e]
                n2[i, n, e] /= sJ[i, n, e]
            end
        end
    end

    nothing
end

"""
    computemetric!(x1, x2, x3, J, JcV, ξ1x1, ξ2x1, ξ3x1, ξ1x2, ξ2x2, ξ3x2, ξ1x3,
                   ξ2x3, ξ3x3, sJ, n1, n2, n3, D1, D2, D3, N_metric)

Compute the 3-D metric terms from the element grid arrays `x1`, `x2`, and `x3`.
All the arrays are preallocated by the user and the (square) derivative matrix
`D` should be consistent with the reference grid `ξ1` used in
[`creategrid!`](@ref).

If `Nq = size(D, 1)` and `nelem = div(length(x1), Nq^3)` then the volume arrays
`x1`, `x2`, `x3`, `J`, `ξ1x1`, `ξ2x1`, `ξ3x1`, `ξ1x2`, `ξ2x2`, `ξ3x2`, `ξ1x3`,
`ξ2x3`, and `ξ3x3` should all be of length `Nq^3 * nelem`.  Similarly, the face
arrays `sJ`, `n1`, `n2`, and `n3` should be of size `Nq^2 * nface * nelem` with
`nface = 6`.

The curl invariant formulation of Kopriva (2006), equation 37, is used.

`N_metric` is the max polynomial order to keep for polynomial representataion of
the metric terms.

Reference:
 - [Kopriva2006](@cite)
"""
function computemetric!(
    x1,
    x2,
    x3,
    J,
    JcV,
    ξ1x1,
    ξ2x1,
    ξ3x1,
    ξ1x2,
    ξ2x2,
    ξ3x2,
    ξ1x3,
    ξ2x3,
    ξ3x3,
    sJ,
    n1,
    n2,
    n3,
    D1,
    D2,
    D3,
    N_metric,
)
    T = eltype(x1)

    Nq = (size(D1, 1), size(D2, 1), size(D3, 1))
    N = Nq .- 1
    Np = prod(Nq)
    Nfp = div.(Np, Nq)
    nelem = div(length(J), Np)

    x1 = reshape(x1, (Nq..., nelem))
    x2 = reshape(x2, (Nq..., nelem))
    x3 = reshape(x3, (Nq..., nelem))
    J = reshape(J, (Nq..., nelem))
    JcV = reshape(JcV, (Nq..., nelem))
    ξ1x1 = reshape(ξ1x1, (Nq..., nelem))
    ξ2x1 = reshape(ξ2x1, (Nq..., nelem))
    ξ3x1 = reshape(ξ3x1, (Nq..., nelem))
    ξ1x2 = reshape(ξ1x2, (Nq..., nelem))
    ξ2x2 = reshape(ξ2x2, (Nq..., nelem))
    ξ3x2 = reshape(ξ3x2, (Nq..., nelem))
    ξ1x3 = reshape(ξ1x3, (Nq..., nelem))
    ξ2x3 = reshape(ξ2x3, (Nq..., nelem))
    ξ3x3 = reshape(ξ3x3, (Nq..., nelem))

    nface = 6
    n1 = reshape(n1, maximum(Nfp), nface, nelem)
    n2 = reshape(n2, maximum(Nfp), nface, nelem)
    n3 = reshape(n3, maximum(Nfp), nface, nelem)
    sJ = reshape(sJ, maximum(Nfp), nface, nelem)

    (yzr, yzs, yzt) = (similar(J, Nq...), similar(J, Nq...), similar(J, Nq...))
    (zxr, zxs, zxt) = (similar(J, Nq...), similar(J, Nq...), similar(J, Nq...))
    (xyr, xys, xyt) = (similar(J, Nq...), similar(J, Nq...), similar(J, Nq...))

    ξ1x1 .= zero(T)
    ξ2x1 .= zero(T)
    ξ3x1 .= zero(T)
    ξ1x2 .= zero(T)
    ξ2x2 .= zero(T)
    ξ3x2 .= zero(T)
    ξ1x3 .= zero(T)
    ξ2x3 .= zero(T)
    ξ3x3 .= zero(T)

    fill!(n1, NaN)
    fill!(n2, NaN)
    fill!(n3, NaN)
    fill!(sJ, NaN)

    fM = ntuple(3) do i
        cutoff_matrix(T, N[i], N_metric[i])
    end

    function apply_filter!(fld)
        @inbounds if N_metric[1] < N[1]
            for k in Nq[3], j in 1:Nq[2]
                fld[:, j, k] = fM[1] * fld[:, j, k]
            end
        end
        @inbounds if N_metric[2] < N[2]
            for k in Nq[3], i in 1:Nq[1]
                fld[i, :, k] = fM[2] * fld[i, :, k]
            end
        end
        @inbounds if N_metric[3] < N[3]
            for j in 1:Nq[2], i in 1:Nq[1]
                fld[i, j, :] = fM[3] * fld[i, j, :]
            end
        end
    end

    @inbounds for e in 1:nelem
        apply_filter!(@view(x1[:, :, :, e]))
        apply_filter!(@view(x2[:, :, :, e]))
        apply_filter!(@view(x3[:, :, :, e]))
        for k in 1:Nq[3], j in 1:Nq[2], i in 1:Nq[1]
            x1ξ1 = x1ξ2 = x1ξ3 = zero(T)
            x2ξ1 = x2ξ2 = x2ξ3 = zero(T)
            x3ξ1 = x3ξ2 = x3ξ3 = zero(T)
            for n in 1:Nq[1]
                x1ξ1 += D1[i, n] * x1[n, j, k, e]
                x2ξ1 += D1[i, n] * x2[n, j, k, e]
                x3ξ1 += D1[i, n] * x3[n, j, k, e]
            end
            for n in 1:Nq[2]
                x1ξ2 += D2[j, n] * x1[i, n, k, e]
                x2ξ2 += D2[j, n] * x2[i, n, k, e]
                x3ξ2 += D2[j, n] * x3[i, n, k, e]
            end
            for n in 1:Nq[3]
                x1ξ3 += D3[k, n] * x1[i, j, n, e]
                x2ξ3 += D3[k, n] * x2[i, j, n, e]
                x3ξ3 += D3[k, n] * x3[i, j, n, e]
            end
            JcV[i, j, k, e] = hypot(x1ξ3, x2ξ3, x3ξ3)

            # We compute J here mainly so we can get the sign of the Jacobian
            # right below (depending on whether we have right- or left-handed
            # element
            J[i, j, k, e] = (
                x1ξ1 * (x2ξ2 * x3ξ3 - x3ξ2 * x2ξ3) +
                x2ξ1 * (x3ξ2 * x1ξ3 - x1ξ2 * x3ξ3) +
                x3ξ1 * (x1ξ2 * x2ξ3 - x2ξ2 * x1ξ3)
            )


            yzr[i, j, k] = x2[i, j, k, e] * x3ξ1 - x3[i, j, k, e] * x2ξ1
            yzs[i, j, k] = x2[i, j, k, e] * x3ξ2 - x3[i, j, k, e] * x2ξ2
            yzt[i, j, k] = x2[i, j, k, e] * x3ξ3 - x3[i, j, k, e] * x2ξ3
            zxr[i, j, k] = x3[i, j, k, e] * x1ξ1 - x1[i, j, k, e] * x3ξ1
            zxs[i, j, k] = x3[i, j, k, e] * x1ξ2 - x1[i, j, k, e] * x3ξ2
            zxt[i, j, k] = x3[i, j, k, e] * x1ξ3 - x1[i, j, k, e] * x3ξ3
            xyr[i, j, k] = x1[i, j, k, e] * x2ξ1 - x2[i, j, k, e] * x1ξ1
            xys[i, j, k] = x1[i, j, k, e] * x2ξ2 - x2[i, j, k, e] * x1ξ2
            xyt[i, j, k] = x1[i, j, k, e] * x2ξ3 - x2[i, j, k, e] * x1ξ3
        end

        # By making these polynomials of degree N_metric we can ensure that
        #    J ∂ ξ_{i} / ∂ x_{k}
        # are polynomials of degree N_metric below. This will ensure that we
        # have a geometric conservation law on the interpolation grid as well as
        # on the quadrature grid. (All other quantities are derived from these
        # so that the aliasing occurs in a consistent manner).
        apply_filter!.((
            @view(JcV[:, :, :, e]),
            yzr,
            yzs,
            yzt,
            zxr,
            zxs,
            zxt,
            xyr,
            xys,
            xyt,
        ))

        for k in 1:Nq[3], j in 1:Nq[2], i in 1:Nq[1]
            for n in 1:Nq[1]
                ξ2x1[i, j, k, e] -= D1[i, n] * yzt[n, j, k] / 2
                ξ3x1[i, j, k, e] += D1[i, n] * yzs[n, j, k] / 2
                ξ2x2[i, j, k, e] -= D1[i, n] * zxt[n, j, k] / 2
                ξ3x2[i, j, k, e] += D1[i, n] * zxs[n, j, k] / 2
                ξ2x3[i, j, k, e] -= D1[i, n] * xyt[n, j, k] / 2
                ξ3x3[i, j, k, e] += D1[i, n] * xys[n, j, k] / 2
            end
            for n in 1:Nq[2]
                ξ1x1[i, j, k, e] += D2[j, n] * yzt[i, n, k] / 2
                ξ3x1[i, j, k, e] -= D2[j, n] * yzr[i, n, k] / 2
                ξ1x2[i, j, k, e] += D2[j, n] * zxt[i, n, k] / 2
                ξ3x2[i, j, k, e] -= D2[j, n] * zxr[i, n, k] / 2
                ξ1x3[i, j, k, e] += D2[j, n] * xyt[i, n, k] / 2
                ξ3x3[i, j, k, e] -= D2[j, n] * xyr[i, n, k] / 2
            end
            for n in 1:Nq[3]
                ξ1x1[i, j, k, e] -= D3[k, n] * yzs[i, j, n] / 2
                ξ2x1[i, j, k, e] += D3[k, n] * yzr[i, j, n] / 2
                ξ1x2[i, j, k, e] -= D3[k, n] * zxs[i, j, n] / 2
                ξ2x2[i, j, k, e] += D3[k, n] * zxr[i, j, n] / 2
                ξ1x3[i, j, k, e] -= D3[k, n] * xys[i, j, n] / 2
                ξ2x3[i, j, k, e] += D3[k, n] * xyr[i, j, n] / 2
            end

            J_new = sqrt(abs(det([
                ξ1x1[i, j, k, e] ξ1x2[i, j, k, e] ξ1x3[i, j, k, e]
                ξ2x1[i, j, k, e] ξ2x2[i, j, k, e] ξ2x3[i, j, k, e]
                ξ3x1[i, j, k, e] ξ3x2[i, j, k, e] ξ3x3[i, j, k, e]
            ])))

            J[i, j, k, e] = J[i, j, k, e] > 0 ? J_new : -J_new

            ξ1x1[i, j, k, e] /= J[i, j, k, e]
            ξ2x1[i, j, k, e] /= J[i, j, k, e]
            ξ3x1[i, j, k, e] /= J[i, j, k, e]
            ξ1x2[i, j, k, e] /= J[i, j, k, e]
            ξ2x2[i, j, k, e] /= J[i, j, k, e]
            ξ3x2[i, j, k, e] /= J[i, j, k, e]
            ξ1x3[i, j, k, e] /= J[i, j, k, e]
            ξ2x3[i, j, k, e] /= J[i, j, k, e]
            ξ3x3[i, j, k, e] /= J[i, j, k, e]
        end

        # faces 1 & 2
        for k in 1:Nq[3], j in 1:Nq[2]
            n = j + (k - 1) * Nq[2]
            n1[n, 1, e] = -J[1, j, k, e] * ξ1x1[1, j, k, e]
            n2[n, 1, e] = -J[1, j, k, e] * ξ1x2[1, j, k, e]
            n3[n, 1, e] = -J[1, j, k, e] * ξ1x3[1, j, k, e]
            n1[n, 2, e] = J[Nq[1], j, k, e] * ξ1x1[Nq[1], j, k, e]
            n2[n, 2, e] = J[Nq[1], j, k, e] * ξ1x2[Nq[1], j, k, e]
            n3[n, 2, e] = J[Nq[1], j, k, e] * ξ1x3[Nq[1], j, k, e]
            for f in 1:2
                sJ[n, f, e] = hypot(n1[n, f, e], n2[n, f, e], n3[n, f, e])
                n1[n, f, e] /= sJ[n, f, e]
                n2[n, f, e] /= sJ[n, f, e]
                n3[n, f, e] /= sJ[n, f, e]
            end
        end
        # faces 3 & 4
        for k in 1:Nq[3], i in 1:Nq[1]
            n = i + (k - 1) * Nq[1]
            n1[n, 3, e] = -J[i, 1, k, e] * ξ2x1[i, 1, k, e]
            n2[n, 3, e] = -J[i, 1, k, e] * ξ2x2[i, 1, k, e]
            n3[n, 3, e] = -J[i, 1, k, e] * ξ2x3[i, 1, k, e]
            n1[n, 4, e] = J[i, Nq[2], k, e] * ξ2x1[i, Nq[2], k, e]
            n2[n, 4, e] = J[i, Nq[2], k, e] * ξ2x2[i, Nq[2], k, e]
            n3[n, 4, e] = J[i, Nq[2], k, e] * ξ2x3[i, Nq[2], k, e]
            for f in 3:4
                sJ[n, f, e] = hypot(n1[n, f, e], n2[n, f, e], n3[n, f, e])
                n1[n, f, e] /= sJ[n, f, e]
                n2[n, f, e] /= sJ[n, f, e]
                n3[n, f, e] /= sJ[n, f, e]
            end
        end
        # faces 5 & 6
        for j in 1:Nq[2], i in 1:Nq[1]
            n = i + (j - 1) * Nq[1]
            n1[n, 5, e] = -J[i, j, 1, e] * ξ3x1[i, j, 1, e]
            n2[n, 5, e] = -J[i, j, 1, e] * ξ3x2[i, j, 1, e]
            n3[n, 5, e] = -J[i, j, 1, e] * ξ3x3[i, j, 1, e]
            n1[n, 6, e] = J[i, j, Nq[3], e] * ξ3x1[i, j, Nq[3], e]
            n2[n, 6, e] = J[i, j, Nq[3], e] * ξ3x2[i, j, Nq[3], e]
            n3[n, 6, e] = J[i, j, Nq[3], e] * ξ3x3[i, j, Nq[3], e]
            for f in 5:6
                sJ[n, f, e] = hypot(n1[n, f, e], n2[n, f, e], n3[n, f, e])
                n1[n, f, e] /= sJ[n, f, e]
                n2[n, f, e] /= sJ[n, f, e]
                n3[n, f, e] /= sJ[n, f, e]
            end
        end
    end

    nothing
end

end # module
