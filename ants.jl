using Agents
using Random

# sugar world is another ABM.
include("sugar.jl")

mutable struct Ants <: AbstractAgent
    id::Int             # The identifier number of the agent
    pos::NTuple{2, Float64} # The x, y location of the agent on a 2D
    vel::NTuple{2,Float64} # Velocity vector
    speed::Float64
    state::Int # 0 Look for food ; 1 Carrying Food
    color::Symbol
end

## SETUP ##
function setup_ants_world(
    myRng::MersenneTwister,
    sugar_model,
    population;
    visual_distance = 5,
    speed = 0.2,
    spacing = visual_distance / 1.5,
    extent = (70, 70),)

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
        vel = Tuple((0,0))
        pos = Tuple(sugar_model.nest)
        add_agent!(pos, model, vel, speed, 0, :black )
    end

    return model

end


## ANT STEP ##

function ants_model_step!(model)
    model.tick += 1
    #print("step $(model.tick)")
end


function ants_agent_step!(ant, model)
    sugar_model = model.sugar_model

    ipos = to_grid(ant.pos, sugar_model)
    ipos_x =  ipos[1]
    ipos_y = ipos[2]

    dims_x = sugar_model.dims[1] - 1
    dims_y = sugar_model.dims[2] - 1

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
            # TODO : free value, need to be parametred            
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
                    new_pos = get_any_xy(ipos,sugar_model,model.rng).+ rand(model.rng, Float64)
                    ant.vel = new_pos .- ant.pos
                end
                if ipos_y >= dims_y || ipos_y <= 1 || ipos_x <= 1 || ipos_x >= dims_x
                    if ipos_x <= 1
                        ant.vel = (-ant.vel[1],ant.vel[2])
                    end
                    if ipos_x >= dims_x
                        ant.vel = (-ant.vel[1],ant.vel[2])
                    end
                    if ipos_y <= 1
                        ant.vel = (ant.vel[1],-ant.vel[2])
                    end
                    if ipos_y >= dims_y
                        ant.vel = (ant.vel[1],-ant.vel[2])
                    end
                end

            end

            #print(" Before = Ant $(ant.id) move at step $(model.tick) and speed $(ant.speed) to $(ant.pos)\n")
            if ant.pos[1] <= ant.speed + 1
                ant.pos = (1.0, ant.pos[2])
            end
            if ant.pos[2] <= ant.speed + 1
                ant.pos = (ant.pos[1], 1.0)
            end

            if ant.pos[1] >= Float64.(dims_x) - ant.speed
                ant.pos = ( Float64.(dims_x) , ant.pos[2])
            end
            if ant.pos[2] >= Float64.(dims_y) - ant.speed
                ant.pos = (ant.pos[1], Float64.(dims_y))
            end
            #print("After = Ant $(ant.id) move at step $(model.tick) and speed $(ant.speed) to $(ant.pos)\n")

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
end
