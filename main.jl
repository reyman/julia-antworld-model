## MAIN

include("ants.jl")
include("sugar.jl")

using Agents
using CairoMakie
using InteractiveDynamics
using Makie.GeometryBasics

CairoMakie.activate!()

## Const
const ants_polygon = Polygon(Point2f0[(-0.2, -0.2), (0.5, 0), (-0.2, 0.2)])

# TIPS
# map tuple julia> map( t -> ((z,(x,y)) = t; (Float16(x), Float16(y))), u)

function init_fig(model, observable)

    function ants_marker(b::Ants)
        ^f = atan(b.vel[2], b.vel[1]) #+  ^`/2 +  ^`
       scale(rotate2D(ants_polygon,  ^f), 2)
    end

    function ants_color(b::Ants)
       return b.color
    end

    fig, abmstepper, abmobs = abmplot(model; agent_step! = ants_agent_step!,model_step! = ants_model_step!, am= ants_marker, ac=ants_color)


    ax, hm = heatmap(fig[1,2], observable[1]; colormap=cgrad(:thermal))
    ax.aspect = AxisAspect(1)

    ax2, hm2 = heatmap(fig[2,2][1,1], observable[2]; colormap=cgrad(:thermal))
    ax2.aspect = AxisAspect(1)

    ax3, hm3 = heatmap(fig[2,2][1,2], observable[3]; colormap=cgrad(:thermal))
    ax3.aspect = AxisAspect(1)

    s = Observable(0) # counter of current step, also observable
    Colorbar(fig[1, 3], hm, width = 20,tellheight=false)
    rowsize!(fig.layout, 1 , ax.scene.px_area[].widths[2])

    return (fig, abmstepper, abmobs)

end

function myrun(model,observable,stopWhenSugarEqual, dorecord)

    # Stop condition
    rununtil(model, s) = sum(model.sugar_model.sugar_landscape) == stopWhenSugarEqual
    count_sugar(model) = sum(model.sugar_landscape)

    fig, abmstepper, abmobs = init_fig(model, observable)
    adata = [:state]
    mdata = [count_sugar]
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model.sugar_model, mdata)

    s = 0
    n = rununtil
    record(fig, "ants.mp4"; framerate = 20) do io

        while Agents.until(s, rununtil, model)
            print("sugar remaining on world =  $(sum(model.sugar_model.sugar_landscape)) \n")
            recordframe!(io) # save current state

            if Agents.should_we_collect(s, model, true)
                Agents.collect_agent_data!(df_agent, model, adata, s)
            end
            if Agents.should_we_collect(s, model.sugar_model, true)
                Agents.collect_model_data!(df_model, model.sugar_model, mdata, s)
            end
            step!(abmobs,1)
            step!(model.sugar_model, sugar_agent_step!, sugar_model_step!, 1)

            s += 1

            observable[1][] = model.sugar_model.sugar_landscape
            observable[2][] = model.sugar_model.chemical_landscape
        end
    end

    return mdata

end


function main_ants(population, evaporationRate, diffusionRate, seed, stopWhenSugarEqual)

    myGlobalRandomG = Random.MersenneTwister(seed)

    sugar_model = setup_sugar_world(myGlobalRandomG, ((50,45), (15,15), (15,45)), (35, 35), (70,70),  evaporationRate,  diffusionRate)
    ant_model = setup_ants_world(myGlobalRandomG, sugar_model, population)

    obs_sugar = Observable(sugar_model.sugar_landscape)
    obs_chemical = Observable(sugar_model.chemical_landscape)
    obs_descent = Observable(sugar_model.nest_descent_landscape)
    observable = [obs_sugar,obs_chemical,obs_descent]

    data = myrun(ant_model, observable, stopWhenSugarEqual, true)

    return data

end

# Testing
main_ants(ARGS[1], ARGS[2], ARGS[3], ARGS[4], ARGS[5] )
