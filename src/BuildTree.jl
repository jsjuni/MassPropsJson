module Main

    using ArgParse
    using MetaGraphsNext
    using Graphs
    using JSON3
    using Logging
    using DataStructures
    using Random
    using OrderedCollections
    using Printf
    using CSV
    using DataFrames
    using Base.Iterators

    LEVELS = [ "System", "Segment", "Element", "Subsystem", "Assembly", "Subassembly", "Part" ]

    function parse_commandline()
        s = ArgParseSettings()
        @add_arg_table s begin
            "--max-depth"
                help = "Maximum depth of tree"
                arg_type = Int32
                default = 7
            "--max-width"
                help = "Maximum width of decomposition"
                arg_type = Int32
                default = 5
            "--decomp-prob"
                help = "Probabiliy of decomposition"
                arg_type = Float32
                default = 0.9
            "--seed"
                help = "RNG seed (default 0)"
                arg_type = Int32
                default = 0
           "--output"
                help = "Output JSON file (default: output.json)"
                arg_type = String
                default = ""
            "--table"
                help = "Input table (CSV)"
                arg_type = String
                required = true
        end
        return parse_args(s)
    end

    function decompose(prob)
        rand() < prob
    end

    function choose_n_children(depth, max_width)
        (depth == 1) ? max_width : Integer(3 + floor(rand() * (max_width - 2)))
    end

    function comp_from_wp(wp)
        replace(wp, r"^WP\.4" =>"C.1")
    end

    function assign_name(depth, last_assigned)
        ns = string(last_assigned[LEVELS[depth]] += 1)
        "$(LEVELS[depth]) $ns"
    end

    function authorizer(g, wp)
        pl = collect(inneighbor_labels(g, wp))
        isempty(pl) ? wp : pl[1]
    end

    function sample_props(table)
        row = table[rand(1:nrow(table)), :]
        OrderedDict(
            "mass" => string(row["mass"]),
            "Cx" => string(row["Cx"]),
            "Cy" => string(row["Cy"]),
            "Cz" => string(row["Cz"]),
            "Ixx" => string(row["Ixx"]),
            "Iyy" => string(row["Iyy"]),
            "Izz" => string(row["Izz"]),
            "Ixy" => string(row["Ixy"]),
            "Ixz" => string(row["Ixz"]),
            "Iyz" => string(row["Iyz"]),
            "Ipoint" => row["Ipoint"],
            "sigma_mass" => string(row["sigma_mass"]),
            "sigma_Cx" => string(row["sigma_Cx"]),
            "sigma_Cy" => string(row["sigma_Cy"]),
            "sigma_Cz" => string(row["sigma_Cz"]),
            "sigma_Ixx" => string(row["sigma_Ixx"]),
            "sigma_Iyy" => string(row["sigma_Iyy"]),
            "sigma_Izz" => string(row["sigma_Izz"]),
            "sigma_Ixy" => string(row["sigma_Ixy"]),
            "sigma_Ixz" => string(row["sigma_Ixz"]),
            "sigma_Iyz" => string(row["sigma_Iyz"])
                    )
    end

    function (@main)(ARGS)
        
        @info "begin BuildTree"
        args = parse_commandline()
    
        @info "load property table"
        table = subset(CSV.read(open(args["table"], "r"), DataFrame; missingstring = "NA"), :mass => m -> .!ismissing.(m))
    
        @info "seed rng" args["seed"]
        Random.seed!(args["seed"])

        @info "initalize levels"
        last_assigned = Dict{String, Integer}()
        for l in LEVELS
            last_assigned[l] = 0
        end
        assigned_name = Dict{String, String}()

        @info "create graph"
        g = tree = MetaGraphsNext.MetaGraph(Graphs.DiGraph(), label_type = String)

        project = "P.1"
        assigned_name[project] = "Project"
        add_vertex!(g, project)

        todo = Queue{String}()
        next_batch = Queue{String}()

        top_wp = "WP.4"
        add_vertex!(g, top_wp)
        add_edge!(g, project, top_wp)
        push!(todo, top_wp)
        depth = 1
        assigned_name[top_wp] = assign_name(1, last_assigned)

        while depth < args["max-depth"]
            depth += 1
            while !isempty(todo)
                parent_id = popfirst!(todo)
               if decompose(args["decomp-prob"])
                    n_children = choose_n_children(depth, args["max-width"])
                    @info "decomposing" parent_id n_children
                    for child_index in 1:n_children
                        child_id = "$parent_id.$child_index"
                        @info "adding child" child_id
                        add_vertex!(g, child_id)
                        add_edge!(g, parent_id, child_id)
                        if child_index != 1 && child_index != n_children
                            push!(next_batch, child_id)
                        end
                        assigned_name[child_id] = assign_name(depth, last_assigned)
                     end
                end
            end
            while !isempty(next_batch)
                push!(todo, popfirst!(next_batch))
            end
        end

        @info "graph metrics" nv(g) depth

        @info "build dictionary"
        order = topological_sort(tree)
        wpl = map(v -> label_for(tree, v), order)
        wpd = OrderedCollections.OrderedDict{String, OrderedDict{String, Any}}()
        for wp in wpl
            wpd[wp] = d = OrderedDict{String, Any}()
            if wp != project
                d["supplies"] = comp_from_wp(wp)
            end
            children = outneighbor_labels(g, wp)
            d["isAuthorizedBy"] = authorizer(g, wp)
            d["authorizes"] = reduce(
                merge,
                map(
                    p -> OrderedDict(p => comp_from_wp(p)),
                    children
                ),
                init = OrderedDict()
            )
            d["hasName"] = reduce(
                    merge,
                    map(
                        p -> OrderedDict(comp_from_wp(p) => assigned_name[p]),
                        children
                    ),
                init = OrderedDict()
            )
            d["transfers"] = if wp == project
                    d["hasName"][project] = assigned_name[project]
                    comp = comp_from_wp(collect(children)[1])
                    OrderedDict(comp => OrderedDict("in" => "IT.$(comp)_in", "out" => "IT.$(comp)_out"))
                else
                    id = OrderedDict{String, OrderedDict{String, String}}()
                    if !isempty(children)
                        cc = map(w -> comp_from_wp(w), children)
                        first_comp = first(cc)
                        last_comp = last(cc)
                        id[first_comp] = OrderedDict("in" => wpd[d["isAuthorizedBy"]]["transfers"][d["supplies"]]["in"])
                        while length(cc) > 1
                            l = popfirst!(cc)
                            r = first(cc)
                            id[l]["out"] = "IT.$(l)_out"
                            id[r] = OrderedDict("in" => "IT.$(l)_out")
                        end
                        id[last_comp]["out"] = wpd[d["isAuthorizedBy"]]["transfers"][d["supplies"]]["out"]
                    end
                    id
                end
            d["junctions"] = begin
                jd = OrderedDict{String, OrderedDict{String, String}}()
                cc = collect(keys(d["transfers"]))
                jc = 0
                while length(cc) > 1
                    l = popfirst!(cc)
                    r = first(cc)
                    j_name = "J.IF.$(l)_out.IF.$(r)_in"
                    jd[j_name] = OrderedDict{String, String}("1" => "IF.$(l)_out", "2" => "IF.$(r)_in")
                    jd
\                end
                jd
            end
            my_items = collect(Base.Iterators.flatten(map(d -> collect(values(d)), values(d["transfers"]))))
            d["items"] = if wp == project
                my_items
            else
                setdiff(my_items, wpd[d["isAuthorizedBy"]]["items"])
            end
            d["hasSortKey"] = reduce(
                merge, 
                map(
                    p -> OrderedDict(
                        comp_from_wp(p) => join(
                            map(
                                x -> @sprintf("%02d", parse(Int, x)), split(comp_from_wp(p), ".")[2:end]
                            )
                        ),
                        p => join(
                            map(
                               x -> @sprintf("%02d", parse(Int, x)), split(p, ".")[2:end] 
                            )
                        )
                    ),
                    children
                ),
                init = OrderedDict()
            )
            if haskey(d, "supplies")
                d["hasPOIconv"] = "-"
                d["isPointMass"] = false
            end
            if isempty(d["authorizes"])
                d["hasValues"] = sample_props(table)
            end
        end

        @info "serialize dictionary"
        f = args["output"] == "" ? stdout : open(args["output"], "w")
        JSON3.pretty(f, JSON3.write(wpd))

        @info "end BuildTree"
        exit(0)
    end

end # module
