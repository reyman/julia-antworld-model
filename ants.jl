using Agents
using Random

include("sugar.jl")

mutable struct Ants <: AbstractAgent
    id::Int             # The identifier number of the agent
    pos::NTuple{2, Float64} # The x, y location of the agent on a 2D
    vel::NTuple{2,Float64}
    speed::Float64
    state::Int # 0 Look for food ; 1 Carrying Food
end

function setup_ants_world(;
    visual_distance = 5.0,
    population = 5,
    speed = 1.0,
    spacing = visual_distance / 1.5,
    extent = (30, 30),
    seed = 42,
    sugar_model = setup_sugar_world())

    myRng = Random.MersenneTwister(seed)
    ant_space = ContinuousSpace(extent, spacing)

    properties = Dict(
    :sugar_model => sugar_model,
    )


    model = ABM(
    Ants,
    ant_space;
    scheduler = Schedulers.randomly,
    properties = properties,
    rng = myRng)
    for ag in 1:population
        vel = Tuple(rand(model.rng, 2) * 2 .- 1)
        pos = (rand(model.rng, 1:100, 2)..., 1)
        add_agent!(model, vel, speed, 0,  )
    end

    return model

end


## STEP ##

function all_model_step!(ants_model, sugar_model)
    Agents.step!(abmstepper, ants_model, ants_agent_step!, ants_model_step!, 1)
    Agents.step!( sugar_model, sugar_agent_step!, sugar_model_step!, 1)
end

function check_right_chemical()
end

function check_left_chemical()
end

# ANTS AGENT STEP
function ants_model_step!( model)
end

function ants_agent_step!(ant, model)
    sugar_model = model.sugar_model

    ipos = to_grid(ant.pos, sugar_model)
    ipos_x =  ipos[1]
    ipos_y = ipos[2]

    if ant.state == 0

        #print("move $(ant.pos) transformed to ($ipos_x $ipos_y) \n")

        # Look for food
        if sugar_model.sugar_landscape[ipos_x, ipos_y] == 1
            #print("Found sugar at  $(sugar_model.sugar_landscape[pos_x, pos_y])")
            sugar_model.sugar_landscape[ipos_x, ipos_y] = 0
            sugar_model.chemical_landscape[ipos_x, ipos_y] += 60.0
            #print("add 1.0 chemical at  $(sugar_model.chemical_landscape[ipos_x, ipos_y])")
            ant.state = 1
        else
            # food not found, try to follow some chemical path based on value here
            chemical = sugar_model.chemical_landscape[ipos_x, ipos_y]
            if (chemical >= 0.05) && (chemical < 2)
                # pos = go to strongest value
            else
                # pos = random move
                move_agent!(ant, model)
            end
        end

    else

        new_pos = pos_on_descent(ipos, sugar_model)
        move_agent!(ant, new_pos, model)
       #pos_x, pos_y = ant.pos
       if sugar_model.is_nest_landscape[ipos_x,ipos_y] == 1
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

const ants_polygon = Polygon(Point2f0[(-0.5, -0.5), (1, 0), (-0.5, 0.5)])
function ants_marker(b::Ants)
   φ = atan(b.vel[2], b.vel[1]) #+ π/2 + π
   scale(rotate2D(ants_polygon, φ), 2)
end

plotkwargs = (
    am = ants_marker,
)
fig, abmstepper = abm_plot(model; resolution = (800, 600), plotkwargs...)
obs_sugar = Observable(model.sugar_model.sugar_landscape)
obs_chemical = Observable(model.sugar_model.chemical_landscape)
obs_descent = Observable(model.sugar_model.nest_descent_landscape)

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

# TIPS
# map tuple julia> map( t -> ((z,(x,y)) = t; (Float16(x), Float16(y))), u)

record(fig, "ants.mp4"; framerate = 3) do io
    for j in 0:100 # = total number of frames
        recordframe!(io) # save current state
        # This updates the abm plot:
        all_model_step!(model, model.sugar_model)
        # This updates the heatmap:
        obs_sugar[] = model.sugar_model.sugar_landscape
        obs_chemical[] = model.sugar_model.chemical_landscape
    end
end
