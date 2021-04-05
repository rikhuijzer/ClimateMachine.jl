rad(x,y,z) = sqrt(x^2 + y^2 + z^2)
lat(x,y,z) = asin(z/rad(x,y,z)) # ϕ ∈ [-π/2, π/2] 
lon(x,y,z) = atan(y,x) # λ ∈ [-π, π) 

r̂ⁿᵒʳᵐ(x,y,z) = norm([x,y,z]) ≈ 0 ? 1 : norm([x, y, z])^(-1)
ϕ̂ⁿᵒʳᵐ(x,y,z) = norm([x,y,0]) ≈ 0 ? 1 : (norm([x, y, z]) * norm([x, y, 0]))^(-1)
λ̂ⁿᵒʳᵐ(x,y,z) = norm([x,y,0]) ≈ 0 ? 1 : norm([x, y, 0])^(-1)

r̂(x,y,z) = r̂ⁿᵒʳᵐ(x,y,z) * @SVector([x, y, z])
ϕ̂(x,y,z) = ϕ̂ⁿᵒʳᵐ(x,y,z) * @SVector [x*z, y*z, -(x^2 + y^2)]
λ̂(x,y,z) = λ̂ⁿᵒʳᵐ(x,y,z) * @SVector [-y, x, 0] 

rfunc(p, x...) = ρuʳᵃᵈ(p, lon(x...), lat(x...), rad(x...)) * r̂(x...)
ϕfunc(p, x...) = ρuˡᵃᵗ(p, lon(x...), lat(x...), rad(x...)) * ϕ̂(x...)
λfunc(p, x...) = ρuˡᵒⁿ(p, lon(x...), lat(x...), rad(x...)) * λ̂(x...)

ρu⃗(p, x...) = rfunc(p, x...) + ϕfunc(p, x...) + λfunc(p, x...)


function vectorfieldrepresentation(u⃗, grid::DiscontinuousSpectralElementGrid, rep::AbstractRepresentation)
    n_ijk, _, n_e = size(u⃗)
    uᴿ = copy(u⃗)
    v⃗ =  VectorField(data = (u⃗[:,1,:], u⃗[:,2,:], u⃗[:,3,:]), grid = grid)
    for ijk in 1:n_ijk, e in 1:n_e, s in 1:3
        uᴿ[ijk,s,e] = v⃗(rep)[ijk,e, verbose = false][s]
    end
    return uᴿ
end

function grabvelocities(Q, grid::DiscontinuousSpectralElementGrid, rep::AbstractRepresentation)
    n_ijk, _, n_e = size(Q)
    uᴿ = copy(Q[:,2:4,:])
    v⃗ =  VectorField(data = (Q[:,2,:] ./ Q[:,1,:], Q[:,3,:] ./ Q[:,1,:] , Q[:,4,:] ./ Q[:,1,:]), grid = grid)
    for ijk in 1:n_ijk, e in 1:n_e, s in 1:3
        uᴿ[ijk,s,e] = v⃗(rep)[ijk,e, verbose = false][s]
    end
    return uᴿ
end

vectorfieldrepresentation(simulation::Simulation, rep) = vectorfieldrepresentation(simulation.state.ρu, simulation.model.grid, rep)
                 
