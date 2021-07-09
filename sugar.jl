mutable struct Cell <: AbstractAgent
    id::Int
    pos::Dims{2}
    #chemical::Float16
    #food::Int # 1 / 0
    #nest::Bool
end

## BUILD LANDSCAPES

function init_sugar_landscape(landscape, peaks, model)
    for (x,y) in peaks
        landscape[x, y] = 1
        neighbors = nearby_positions((x,y) , model, 2)
         for neighbor in neighbors
             landscape[neighbor[1], neighbor[2]] = 1
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

## HELPERS FUNCTION GRID <-> CONTINUE

function to_continue(grid_pos,sugar_model)
    float_pos = Float64.(grid_pos).- 1.0
    return float_pos
end

function to_grid(ant_pos, sugar_model)
    discrete_x = floor(ant_pos[1]) + 1
    discrete_y = floor(ant_pos[2]) + 1
    return (Int(discrete_x), Int(discrete_y))
end

## HELPERS FUNCTION LOCAL SPACE

function get_any_xy(discrete_pos,sugar_model, rng)
    neighbors = nearby_positions(discrete_pos, sugar_model, 1)
    collected_neighbors = collect(neighbors)
    #print("neighbors = $(collected_neighbors)")
    return to_continue(first(shuffle!(rng, collected_neighbors)),sugar_model)
end

## GRADIENT DESCENT

function pos_on_chemical_descent(discrete_pos,sugar_model)
    front_neighbors = nearby_positions(discrete_pos, sugar_model, 1)
    #print("front_neighbors =  $front_neighbors \n")
    val_landscape_neighbors = ((sugar_model.chemical_landscape[x,y], (x,y)) for (x, y) in front_neighbors)
    result = reduce( (x,y) -> x[1] > y[1] ? x : y , val_landscape_neighbors)
    #print("Max chemical for $(discrete_pos) is =  $(result[2]) with $(result[1]) \n")
    return to_continue(result[2], sugar_model)
end

function pos_on_nest_descent(discrete_pos, sugar_model)
    neighbors = nearby_positions(discrete_pos, sugar_model, 1)
    val_landscape_neighbors = ((sugar_model.nest_descent_landscape[x,y], (x,y)) for (x, y) in neighbors)
    #min_neighbors = minimum(val_landscape_neighbors)

    # get min
    result = reduce( (x,y) -> x[1] < y[1] ? x : y , val_landscape_neighbors)
    # result in discrete coordinate
    return to_continue(result[2],sugar_model)
end

## DIFFUSE and EVAPORATE

function evaporate_chemical!(pos,model)
    model.chemical_landscape[pos...] =
    model.chemical_landscape[pos...] * (100 - model.evaporationRate) / 100
end

function diffuse_chemical!(pos, model)
    ratio = model.diffusionRate / 100
    npos = nearby_positions(pos, model)
    # Each neighbor is giving up 1/8 of the diffused
    # amount to each of *its* neighbors
    model.chemical_landscape[pos...] =
        (1 - ratio) * model.chemical_landscape[pos...] +
        sum(model.chemical_landscape[p...] for p in npos) * 0.125 * ratio
end

## SETUP ##

function setup_sugar_world(myRng::MersenneTwister,
    peaks,
    nest,
    dims,
    evaporationRate,
    diffusionRate,
    )

    sugar_space = GridSpace(dims, periodic = false)

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
    :is_nest_landscape => is_nest_landscape,
    :dims => dims,
    :nest => nest,
    )

    model = ABM(
    Cell,
    sugar_space;
    scheduler = Schedulers.randomly,
    properties = properties,
    rng = myRng)

    #populate with sugar
    init_sugar_landscape(model.sugar_landscape, peaks, model)

    #init nest and gradient to nest
    init_nest_landscape(model.nest_descent_landscape, model.is_nest_landscape, nest, model)

    return model

end

## SUGAR STEP ##
function sugar_model_step!(sugar_model)
    for p in positions(sugar_model)
        diffuse_chemical!(p, sugar_model)
        evaporate_chemical!(p, sugar_model)
    end
end

function sugar_agent_step!(cell,sugar_model)
#    @show "sugar agent step"
end
