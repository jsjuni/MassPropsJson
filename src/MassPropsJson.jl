module Main

    using ArgParse
    using CSV
    using DataFrames
    using MetaGraphsNext
    using Graphs
    using MassProps
    using OrderedCollections
    using JSON3

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
            return c
        else
            return error("Multiple parents found for $c: ", parents)
        end
    end

    function customer(c, tree)
        return supplier(parent(c, tree))
    end

    function supplier(c)
        return replace(c, r"^C" => "WP")
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

        for c in cl
            cust = customer(c, tree)
            supp = supplier(c)
            if !haskey(wpd, supp)
                wpd[supp] = Dict("isAuthorizedBy" => cust, "authorizes" => Dict{String, String}(), "hasName" => Dict{String, String}())
            end
            cwp = wpd[cust]
            cwp["authorizes"][supp] = c
            swp = wpd[supp]
            swp["supplies"] = c
        end

        for row in eachrow(table)
            c = row["id"]
            supp = supplier(c)
            if haskey(wpd, supp)
                wp = wpd[supp]
                wp["hasPOIconv"] = row["POIconv"]
                if !ismissing(row["mass"])
                    wp["hasValues"] = [
                       Dict("mass" => string(row["mass"])),
                        Dict("Cx" => string(row["Cx"])),
                        Dict("Cy" => string(row["Cy"])),
                        Dict("Cz" => string(row["Cz"])),
                        Dict("Ixx" => string(row["Ixx"])),
                        Dict("Iyy" => string(row["Iyy"])),
                        Dict("Izz" => string(row["Izz"])),
                        Dict("Ixy" => string(row["Ixy"])),
                        Dict("Ixz" => string(row["Ixz"])),
                        Dict("Iyz" => string(row["Iyz"])),
                        Dict("Ipoint" => row["Ipoint"]),
                        Dict("sigma_mass" => string(row["sigma_mass"])),
                        Dict("sigma_Cx" => string(row["sigma_Cx"])),
                        Dict("sigma_Cy" => string(row["sigma_Cy"])),
                        Dict("sigma_Cz" => string(row["sigma_Cz"])),
                        Dict("sigma_Ixx" => string(row["sigma_Ixx"])),
                        Dict("sigma_Iyy" => string(row["sigma_Iyy"])),
                        Dict("sigma_Izz" => string(row["sigma_Izz"])),
                        Dict("sigma_Ixy" => string(row["sigma_Ixy"])),
                        Dict("sigma_Ixz" => string(row["sigma_Ixz"])),
                        Dict("sigma_Iyz" => string(row["sigma_Iyz"]))
                    ]
                end
            end
            p_supp = supplier(parent(c, tree))
            if haskey(wpd, p_supp)
                pwp = wpd[p_supp]
                pwp["hasName"][c] = row["name"]
            end
        end

        f = args["output"] == "" ? stdout : open(args["output"], "w")
        JSON3.pretty(f, JSON3.write(wpd))

        exit(0)
    end

end # module
