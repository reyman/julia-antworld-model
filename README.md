# README

## Toy model Ants

For this example we use an existing framework for multi-agent in Julia : Agent.jl. 

This model try to replicate the Ants model created by Uri Wilensky in Netlogo : 

> Wilensky, U. (1997). NetLogo Ants model. http://ccl.northwestern.edu/netlogo/models/Ants. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

According to Netlogo website this model is described as 

> In this project, a colony of ants forages for food. Though each ant follows a set of simple rules, the colony as a whole acts in a sophisticated way. When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves. When other ants “sniff” the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail. 
 
We use this toy model to explain different part of the HPC distributed exploration methods used by OpenMOLE software https://openmole.org/ 

## Ants using Julia

Ants move on a continous space (`ContinuousSpace`), but food, nest, and pheromone are located on discrete space (`GridSpace)` 

### Setup 

#### Ants World

The julia file `ants.jl` contain all the code to define and update Ants on a continuous space. 

The `setup_ants_world` init the model for Ants : 

- a [`ContinuousSpace`](https://juliadynamics.github.io/Agents.jl/stable/api/#Agents.ContinuousSpace) function that take in input a spacing and extent properties
- a  [`ABM`](https://juliadynamics.github.io/Agents.jl/stable/tutorial/#Agents.AgentBasedModel) function taking an `AgentType` , a space, a scheduler, properties, and random generator

We define an `AgentType` Ants as a `Struct` with this properties : 

- Id 
- Position 
- Vector of Velocity
- Speed
- State
- Color

The `properties` given to Abm model is a dictionnary accessible later by using `model.properties`. By passing `sugar_model` to `ants_model` properties we create a ref to obtain Sugar model by calling `ant_space.sugar_model`

``` julia
properties = Dict(
    :sugar_model => sugar_model,
    :tick => 1,
)
```

Finally `setup_ants_world` return the Ants model after ants population initialisation (`!add_agent`).

#### Sugar World

The file `sugar.jl` contain all the code to define and update the discrete environment that contain food and pheromone  accessible to Ants. 

We first initialize the `ABM` object model  that contain the sugarscape and his accessible properties.

``` julia
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
```

`Sugar space is a `GridSpace` of dims `(70, 70)` and the Agent are  `Cell` defined as a struct with : 

- an id 
- a pos x,y

The `setup_sugar_world` function create and init the : 

- `sugar landscape`  array populated by `init_sugar_landscape` function
- a nest landscape, two grid initialized and populated by `init_nest_landscape()` using `chemical landscape` and `nest_descent_landscape` array.
 
The function `init_sugar_landscape()` take a list of peaks `(x,y)` coordinates that represent food center on our grid landscape. We use a radius of 2 and set 1 unit of food in `sugar_landscape` array (initialized at 0)

The function `init_nest_landscape()` create the gradient descent used by Ants to go back to nest. We iterate on `Cell`   using `[positions]`(https://juliadynamics.github.io/Agents.jl/stable/api/#Agents.positions) function and we compute the distance between Cell position and Nest position (`pos`) using  `edistance` 

### Main function

#### Stop condition 

We define two reporting function that count existing sugar ``(value==1)` into `sugar_landscape` array  : 
- a function `rununtil(model,s)` that return `False` if sum of sugar is equel to stop condition variable (`stopWhenSugarEqual`)
- a function `count_sugar` that report the sum

The main data collection loop is based on `run!` equivalent defined [here](https://juliadynamics.github.io/Agents.jl/stable/api/#Data-collection-1)

We use this `while` loop architecture to manage the synchronized stepping of our two ABM model until the `rununtil()` function return `False`. Counter of step `s`  initalized at zero is incremented by 1 each while turn.

```julia
while Agents.untils(s, rununtil, model)
    ...
    # collecting data to store into dataframe
    ...
    # stepping both ants and sugar models
    ...
    # get observable from models
    s += 1
end
```

#### Observable


We first  `init_agent_dataframe(model,adata)` and `init_model_dataframe(model.sugar_model,mdata)`  to collect data at every step. We define a vector of Symbols for the agent fields that we want to collect as data. 

-  `adata[:state]`return state info of Ants, stored into Ants model `properties` at step t. 
- `mdata[count_sugar()]` is a function reporting sum of sugar in sugar landscape at step t

The corresponding collecting functions that store data into dataframe at each step are defined here in this simplified block extracted from main loop into `main.jl` : 

``` julia
while Agents.untils(s, rununtil, model)
    ...
    Agents.collect_agent_data!(df_agent,model,adata,s)
    Agents.collect_model_data!(df_model,model.sugar_model,adata,s)
    ...
    step!(abmobs,1)
    step!(model.sugar_model, sugar_agent_step!, sugar_model_step!, 1)
    ...
end
```

#### Plotting 

Plot is managed by the `init_fig(model,observable)` function. This function use the `InteractiveDynamics` library and `abmplot` function to wrap our (Ants) `model` into an [`Observable`](https://makie.juliaplots.org/stable/documentation/nodes/) used by [Makie](https://makie.juliaplots.org/stable/) library to manage both plotting and/or interactivity.

`[abmplot](https://juliadynamics.github.io/InteractiveDynamics.jl/dev/agents/#Interactive-ABM-Applications-1)` function encapsulate our Abm model into [`AbmObservable`](https://juliadynamics.github.io/InteractiveDynamics.jl/dev/agents/#InteractiveDynamics.ABMObservable). We get the ref `abmobs` of object `AbmObserable` in return. 

``` julia
    fig, axis, abmobs = abmplot(model; agent_step! = ants_agent_step!,model_step! = ants_model_step!, am= ants_marker, ac=ants_color)
```

#### Stepping

The stepping is defined by `agent_step!` and `model_step!` , both for AbmObservable or Abm object. These function are called each time we call `step!`

We defined step for each Agent Based Model : 
- `sugar_model_step!`, in `sugar.jl` manage the diffusion and the evaporation of chemical in Sugar World. 
- `sugar_agent_step!`  in `sugar.jl` do nothing, because `Cell` do nothing, don't move, and the food value contained in the `Cell` is fixed at initialization.
- `ants_model_step!`, in `ants.jl` only store a copy of tick (step fo model).
- `ants_agent_step!`, in `ants.jl` manage all the behavior of Ants : moving, eating, all of this in interaction with SugarWorld ( the ref to SugarWorld is stored into `sugar_model` , initialized during setup of  `ants_model` ).

We have two model to manage in parallel, so there are two stepping function, one for Ants and one for Sugar world called by the main loop.

If we go back to main loop, we see that two `!step` function that define behavior of our agents are called into main  (see `main.jl` file) like this  : 

```julia
while Agents.untils(s, rununtil, model)
    ...
    step!(abmobs,1)
    step!(model.sugar_model, sugar_agent_step!, sugar_model_step!, 1)
    ...
end
```

As you see, the `step!` functions differs in their signature, but both do the same thing, the first using an AbmObservable wrapping of Ants model, the second calling directly `step!` on `model.sugar`
