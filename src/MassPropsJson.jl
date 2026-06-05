module Main

    using ArgParse
    using CSV
    using DataFrames
    using MetaGraphsNext
    using Graphs
    using MassProps
    using OrderedCollections
    using JSON3
    using Printf

    function parse_commandline()
        s = ArgParseSettings()
        @add_arg_table s begin
            "--id"
                help = "Column name for node ID (default: id)"
                arg_type = String
                default = "id"
            "--pid"
                help = "Column name for parent ID (default: pid)"
                arg_type = String
                default = "pid"
            "--table"
                help = "Input table (CSV)"
                arg_type = String
                required = true
            "--edgelist"
                help = "Input edge list (CSV)"
                arg_type = String
                required = true
            "--output"
                help = "Output JSON file (default: output.json)"
                arg_type = String
                default = ""
            "--reject"
                help = "Pattern to reject identifiers (default: r\"^\$\")"
                arg_type = String
                default = "^\$"
        end
        return parse_args(s)
    end

    read_data(input) = CSV.read(input, DataFrame; missingstring = "NA")

    tree_from_edgelist(el, id, pid) = begin
        tree = MetaGraphsNext.MetaGraph(Graphs.DiGraph(), label_type = String)
        for row in eachrow(el)
            Graphs.add_vertex!(tree, row[id])
            if !ismissing(row[pid])
                Graphs.add_vertex!(tree, row[pid])
                Graphs.add_edge!(tree, row[id], row[pid])
            end
        end
        tree
    end

    function parent(c, tree)
        parents = collect(String, outneighbor_labels(tree, c))
        if length(parents) == 1
            return parents[1]
        elseif length(parents) == 0
            return nothing
        else
            return error("Multiple parents found for $c: ", parents)
        end
    end

    function customer(c, tree, default)
        p = parent(c, tree)
        return p === nothing ? default : supplier(p)
    end

    function supplier(c)
        return replace(c, r"^C\.1" => "WP.4")
    end

    function (@main)(ARGS)
        
        args = parse_commandline()
    
        table_csv = open(args["table"], "r")
        table = read_data(table_csv)

        edgelist_csv = open(args["edgelist"], "r")
        edgelist = read_data(edgelist_csv)
        tree = tree_from_edgelist(edgelist, args["id"], args["pid"])

        order = reverse(topological_sort(tree))
        cl = map(v -> label_for(tree, v), order)

        wpd = OrderedCollections.OrderedDict{String, Dict{String, Any}}()

        project_id = "P.1"
        wpd[project_id] = Dict(
            "isAuthorizedBy" => "P.1",
            "authorizes" => Dict("WP.4" => "C.1"),
            "hasName" => Dict("C.1" => "System 1", "P.1" => "Project 1"),
            "hasSortKey" => Dict("C.1" => "01")
        )

        for c in cl
            if occursin(Regex(args["reject"]), c)
                continue
            end
            cust = customer(c, tree, project_id)
            supp = supplier(c)
            if !haskey(wpd, supp)
                wpd[supp] = Dict(
                    "isAuthorizedBy" => cust,
                    "authorizes" => Dict{String, String}(),
                    "hasName" => Dict{String, String}(),
                    "hasSortKey" => Dict{String, String}()
                )
            end
            cwp = wpd[cust]
            cwp["authorizes"][supp] = c
            swp = wpd[supp]
            swp["supplies"] = c
       end

        for row in eachrow(table)
            c = row["id"]
            if occursin(Regex(args["reject"]), c)
                continue
            end
            supp = supplier(c)
            if haskey(wpd, supp)
                wp = wpd[supp]
                wp["hasPOIconv"] = row["POIconv"]
                wp["isPointMass"] = false
                if !ismissing(row["mass"])
                    wp["hasValues"] = Dict(
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
            end
            if (p = parent(c, tree)) !== nothing
                p_supp = supplier(parent(c, tree))
                if haskey(wpd, p_supp)
                    pwp = wpd[p_supp]
                    pwp["hasName"][c] = row["name"]
                    pwp["hasSortKey"][c] = join(map(x -> @sprintf("%02d", parse(Int, x)), split(c, ".")[2:end]))
                end
            end
        end

        f = args["output"] == "" ? stdout : open(args["output"], "w")
        JSON3.pretty(f, JSON3.write(wpd))

        exit(0)
    end

end # module
