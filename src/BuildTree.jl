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

    function (@main)(ARGS)
        
        @info "begin BuildTree"
        args = parse_commandline()
    
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
        wpd = OrderedCollections.OrderedDict{String, Dict{String, Any}}()
        for wp in wpl
            wpd[wp] = d = Dict{String, Any}()
            d["supplies"] = comp_from_wp(wp)
            children = outneighbor_labels(g, wp)
            d["authorizes"] = reduce(merge, map(p -> Dict(p => comp_from_wp(p)), children), init = OrderedDict())
            d["hasName"] = reduce(merge, map(p -> Dict(comp_from_wp(p) => assigned_name[p]), children), init = OrderedDict())
            d["hasSortKey"] = reduce(merge, 
                map(p -> Dict(comp_from_wp(p) => join(map(x -> @sprintf("%02d", parse(Int, x)), split(comp_from_wp(p), ".")[2:end]))), children),
                init = OrderedDict()
            )
            d["isAuthorizedBy"] = authorizer(g, wp)
            d["hasPOIconv"] = "-"
            d["isPointMass"] = false
        end

        @info "serialize dictionary"
        f = args["output"] == "" ? stdout : open(args["output"], "w")
        JSON3.pretty(f, JSON3.write(wpd))

        @info "end BuildTree"
        exit(0)
    end

end # module
