using Agents
using Random

include("sugar.jl")

mutable struct Ants <: AbstractAgent
    id::Int             # The identifier number of the agent
    pos::NTuple{2, Float64} # The x, y location of the agent on a 2D
    vel::NTuple{2,Float64}
    speed::Float64
    state::Int # 0 Look for food ; 1 Carrying Food
    color::Symbol
end

function setup_ants_world(;
    population = 125,
    speed = 0.2,
    spacing = visual_distance / 1.5,
    extent = (30, 30),
    seed = 42,
    sugar_model = setup_sugar_world())

    myRng = Random.MersenneTwister(seed)
    ant_space = ContinuousSpace(extent, spacing, periodic = false )

    properties = Dict(
    :sugar_model => sugar_model,
    :tick => 1,
    )

    model = ABM(
    Ants,
    ant_space;
    scheduler = Schedulers.randomly,
    properties = properties,
    rng = myRng)

    for ag in 1:population
        #vel = Tuple(rand(model.rng, 2) * 2 .- 1)
        vel = Tuple((0,0))
        pos = Tuple((15.0,15.0))
        add_agent!(pos, model, vel, speed, 0, :black )
    end

    return model

end


## STEP ##

function all_model_step!(ants_model, sugar_model, abmstepper)
    Agents.step!(abmstepper, ants_model, ants_agent_step!, ants_model_step!, 1)
    Agents.step!( sugar_model, sugar_agent_step!, sugar_model_step!, 1)
end

# ANTS AGENT STEP
function ants_model_step!(model)
    model.tick += 1
    #print("step $(model.tick)")
end


function ants_agent_step!(ant, model)
    sugar_model = model.sugar_model

    ipos = to_grid(ant.pos, sugar_model)
    ipos_x =  ipos[1]
    ipos_y = ipos[2]

    # Random walk to search food or pheromone
    if ant.state == 0
        #print("move $(ant.pos) transformed to ($ipos_x $ipos_y) \n")
        # Look for food on patch
        if sugar_model.sugar_landscape[ipos_x, ipos_y] == 1
            ant.color = :red
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
                ant.color = :orange
                new_pos = pos_on_chemical_descent(ipos,sugar_model).+ rand(model.rng, Float64)
                ant.vel = (new_pos .- ant.pos)
            else
                ant.color = :black
                # pos = random move
                if mod(model.tick, 10) == 0
                    #print("modulo tick = $(model.tick) \n")
                    new_pos = get_any_xy(ipos,sugar_model).+ rand(model.rng, Float64)
                    ant.vel = new_pos .- ant.pos
                end
                if ipos_y >= 29 || ipos_y <= 1 || ipos_x <= 1 || ipos_x >= 29
                    if ipos_x <= 1
                        ant.vel = (-ant.vel[1],ant.vel[2])
                    end
                    if ipos_x >= 29
                        ant.vel = (-ant.vel[1],ant.vel[2])
                    end
                    if ipos_y <= 1
                        ant.vel = (ant.vel[1],-ant.vel[2])
                    end
                    if ipos_y >= 29
                        ant.vel = (ant.vel[1],-ant.vel[2])
                    end
                end

            end

            print(" Before = Ant $(ant.id) move at step $(model.tick) and speed $(ant.speed) to $(ant.pos)\n")
            if ant.pos[1] <= ant.speed + 1
                ant.pos = (1.0, ant.pos[2])
            end
            if ant.pos[2] <= ant.speed + 1
                ant.pos = (ant.pos[1], 1.0)
            end

            if ant.pos[1] >= 29.0 - ant.speed
                ant.pos = ( 29.0 , ant.pos[2])
            end
            if ant.pos[2] >= 29.0 - ant.speed
                ant.pos = (ant.pos[1], 29.0)
            end
            print("After = Ant $(ant.id) move at step $(model.tick) and speed $(ant.speed) to $(ant.pos)\n")

            move_agent!(ant, model, ant.speed)
        end
    else
        new_pos = pos_on_nest_descent(ipos, sugar_model).+ rand(model.rng, Float64)
        ant.vel = sign.(new_pos .- ant.pos)
        #if (atan(ant.vel[2], ant.vel[1])) != 0.0
        #    print("rotate to angle :  $(atan(ant.vel[2], ant.vel[1])) \n")
        #end
        sugar_model.chemical_landscape[ipos_x, ipos_y] += 60.0
        move_agent!(ant, model, ant.speed)
       #pos_x, pos_y = ant.pos

       if sugar_model.is_nest_landscape[ipos_x,ipos_y] == 1
          #print("I'm back to nest \n")
          ant.color = :black
          ant.state = 0
       end
    end
    # evaporate
    #tick

end



## MODEL ##

using CairoMakie
using InteractiveDynamics

## DISPLAY ##

const ants_polygon = Polygon(Point2f0[(-0.2, -0.2), (0.5, 0), (-0.2, 0.2)])

# TIPS
# map tuple julia> map( t -> ((z,(x,y)) = t; (Float16(x), Float16(y))), u)

## MAIN

function init_fig(model, observable)

    function ants_marker(b::Ants)
       φ = atan(b.vel[2], b.vel[1]) #+ π/2 + π
       scale(rotate2D(ants_polygon, φ), 2)
    end

    function ants_color(b::Ants)
       return b.color
    end

    plotkwargs = (
        am = ants_marker,
        ac = ants_color,
    )

    fig, abmstepper = abm_plot(model; resolution = (800, 600), plotkwargs...)

    ax, hm = heatmap(fig[1,2], observable[1]; colormap=cgrad(:thermal))
    ax.aspect = AxisAspect(1)

    ax2, hm2 = heatmap(fig[2,1], observable[2]; colormap=cgrad(:thermal))
    ax2.aspect = AxisAspect(1)

    ax3, hm3 = heatmap(fig[2,2], observable[3]; colormap=cgrad(:thermal))
    ax3.aspect = AxisAspect(1)

    s = Observable(0) # counter of current step, also observable
    Colorbar(fig[1, 3], hm, width = 20,tellheight=false)
    rowsize!(fig.layout, 1 , ax.scene.px_area[].widths[2])

    return (fig, abmstepper)

end

function run(model,observable,dorecord)

    # Stop condition
    rununtil(model, s) = sum(model.sugar_model.sugar_landscape) == 10
    count_sugar(model) = sum(model.sugar_landscape)

    fig, abmstepper = init_fig(model, observable)

    adata = [:state]
    mdata = [count_sugar]
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model.sugar_model, mdata)

    s = 0
    n = rununtil
    record(fig, "ants.mp4"; framerate = 20) do io

        while Agents.until(s, rununtil, model)
            recordframe!(io) # save current state
            if Agents.should_we_collect(s, model, true)
                Agents.collect_agent_data!(df_agent, model, adata, s)
            end
            if Agents.should_we_collect(s, model.sugar_model, true)
                Agents.collect_model_data!(df_model, model.sugar_model, mdata, s)
            end
            step!(abmstepper, model, ants_agent_step!, ants_model_step!, 1)
            step!(model.sugar_model, sugar_agent_step!, sugar_model_step!, 1)
            s += 1

            observable[1][] = model.sugar_model.sugar_landscape
            observable[2][] = model.sugar_model.chemical_landscape
        end
    end

    return df_agent, df_model

    print("mdata = $(mdata)")
end

model = setup_ants_world()

obs_sugar = Observable(model.sugar_model.sugar_landscape)
obs_chemical = Observable(model.sugar_model.chemical_landscape)
obs_descent = Observable(model.sugar_model.nest_descent_landscape)
observable = [obs_sugar,obs_chemical,obs_descent]

run(model,observable,true)
