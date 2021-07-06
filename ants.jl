using Agents
using Random

mutable struct Ants <: AbstractAgent
    id::Int             # The identifier number of the agent
    pos::Dims{2} # The x, y location of the agent on a 2D
    state::Int # 0 Look for food ; 1 Carrying Food
end

mutable struct Cell <: AbstractAgent
    id::Int
    pos::Dims{2}
    chemical::Float16
    food::Int # 1 / 0
    nest::Bool
end

function init_sugar_landscape(landscape, peaks, model)
    for (x,y) in peaks
        pos = random_position(model)
        landscape[pos[1], pos[2]] = 1
        neighbors = nearby_positions(pos , model, 3)
         for neighbor in neighbors
             landscape[neighbor[1], neighbor[2]] = 1
             #sugar_capacities[x, y]
         end
    end
    return landscape
end

function init_nest_landscape(nest_descent_landscape, is_nest_landscape, pos, model)
    is_nest_landscape[pos[1],pos[2]] = 1
    neighbors = nearby_positions(pos , model, 2)
     for neighbor in neighbors
         is_nest_landscape[neighbor[1],neighbor[2]] = 1
     end

     for p in positions(model)
         nest_descent_landscape[p...] =
         edistance(pos, p, model)
     end

end

function setup_ants_world(;
    dims = (30, 30),
    nest = (20, 20),
    peaks = ((20,20),(10,10)),
    metric = :chebyshev,
    population = 5,
    evaporationRate = 10,
    diffusionRate = 50,
    seed = 42,)

    myRng = Random.MersenneTwister(seed)
    space = GridSpace(dims, periodic = false)

    sugar_landscape = zeros(Int, dims)
    is_nest_landscape = zeros(Int, dims)

    chemical_landscape = zeros(Float16, dims)

    nest_descent_landscape = zeros(Float16,dims)

    properties = Dict(
    :diffusionRate => diffusionRate,
    :evaporationRate => evaporationRate,
    :sugar_landscape => sugar_landscape,
    :chemical_landscape => chemical_landscape,
    :nest_descent_landscape => nest_descent_landscape,
    :is_nest_landscape => is_nest_landscape
    )

    model = ABM(
    Ants,
    space;
    scheduler = Schedulers.randomly,
    properties = properties,
    rng = myRng)

    #populate with sugar
    init_sugar_landscape(model.sugar_landscape, peaks, model)

    #init nest and gradient to nest
    init_nest_landscape(model.nest_descent_landscape, model.is_nest_landscape, nest,model)

    for ag in 1:population
        pos = (rand(model.rng, 1:100, 2)..., 1)
        add_agent_single!(model, 0)
    end

    return model

end

## DIFFUSE

function evaporate_chemical!(pos,model)
    model.chemical_landscape[pos...] =
    model.chemical_landscape[pos...] * (100 - model.evaporationRate) / 100
end

function diffuse_chemical!(pos, model)
    ratio = model.diffusionRate / 100
    npos = nearby_positions(pos, model)
    model.chemical_landscape[pos...] =
        (1 - ratio) * model.chemical_landscape[pos...] +
        # Each neighbor is giving up 1/8 of the diffused
        # amount to each of *its* neighbors
        sum(model.chemical_landscape[p...] for p in npos) * 0.125 * ratio
end

## STEP ##

function model_step!(model)
    for p in positions(model)
        diffuse_chemical!(p,model)
        evaporate_chemical!(p,model)
    end
end


function check_right_chemical()
end

function check_left_chemical()
end

function get_best_path(from_pos, model)
    neighbors = nearby_positions(from_pos, model, 1)
    val_landscape_neighbors = ((model.nest_descent_landscape[x,y], (x,y)) for (x, y) in neighbors)
    #min_neighbors = minimum(val_landscape_neighbors)

    # get min
    result = reduce( (x,y) -> x[1] < y[1] ? x : y , val_landscape_neighbors)
    return result[2]

    #print("from pos agent $from_pos[1] / $from_pos[2] = $min_neighbors \n")

    #for p in position(model):
    #    nest_descent_landscape[p[1],p[2]]
    #end
end

function agent_step!(ant, model)
    if ant.state == 0
        walk!(ant, rand, model)
        pos_x, pos_y = ant.pos
        #@show model.sugar_landscape[pos_x, pos_y]
        if model.sugar_landscape[pos_x, pos_y] == 1
            @show "found !"
            model.sugar_landscape[pos_x, pos_y] = 0
            model.chemical_landscape[pos_x, pos_y] = 1
            ant.state = 1
        end
    else
       ant.state = 1
       pos = get_best_path(ant.pos , model)
       move_agent!(ant,pos,model)
       pos_x, pos_y = ant.pos
       if model.is_nest_landscape[pos_x,pos_y] == 1
           ant.state = 0
       end
    end
    # evaporate
    #tick

end



## MODEL ##

model = setup_ants_world()

using CairoMakie
using InteractiveDynamics


## DISPLAY ##

#const ants_polygon = Polygon(Point2f0[(-0.5, -0.5), (1, 0), (-0.5, 0.5)])
#function ants_marker(b::Ants)
#    φ = atan(b.vel[2], b.vel[1]) #+ π/2 + π
#    scale(rotate2D(ants_polygon, φ), 2)
#end

plotkwargs = (
    am = :diamond,
)
fig, abmstepper = abm_plot(model; resolution = (800, 600), plotkwargs...)
obs_sugar = Observable(model.sugar_landscape)
obs_chemical = Observable(model.chemical_landscape)
obs_descent = Observable(model.nest_descent_landscape)

ax, hm = heatmap(fig[1,2], obs_sugar; colormap=cgrad(:thermal))
ax.aspect = AxisAspect(1)

ax2, hm2 = heatmap(fig[2,1], obs_chemical; colormap=cgrad(:thermal))
ax2.aspect = AxisAspect(1)

ax3, hm3 = heatmap(fig[2,2], obs_descent; colormap=cgrad(:thermal))
ax3.aspect = AxisAspect(1)

s = Observable(0) # counter of current step, also observable
Colorbar(fig[1, 3], hm, width = 20,tellheight=false)
rowsize!(fig.layout, 1 , ax.scene.px_area[].widths[2])
fig

## MOVE ##

record(fig, "ants.mp4"; framerate = 3) do io
    for j in 0:100 # = total number of frames
        recordframe!(io) # save current state
        # This updates the abm plot:
        Agents.step!(abmstepper, model, agent_step!, model_step!, 1)
        # This updates the heatmap:
        obs_sugar[] = model.sugar_landscape
        obs_chemical[] = model.chemical_landscape
    end
end
