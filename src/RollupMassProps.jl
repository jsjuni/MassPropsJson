module Main

    using ArgParse
    using Logging
    using HTTP
    using JSON3
    using Graphs
    using MetaGraphsNext
    using DataFrames
    using DataStructures
    using MassProps

    const MASS_PROPS = [
        "mass",
        "Cx", "Cy", "Cz",
        "Ixx", "Ixy", "Ixz",
        "Iyy", "Iyz", "Izz",
        "sigma_mass",
        "sigma_Cx", "sigma_Cy", "sigma_Cz",
        "sigma_Ixx", "sigma_Ixy", "sigma_Ixz",
        "sigma_Iyy", "sigma_Iyz", "sigma_Izz"
    ]

    const EDGE_QUERY = """
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX oml: <http://opencaesar.io/oml#>
        PREFIX base: <http://imce.jpl.nasa.gov/foundation/base#>
        PREFIX analysis: <http://imce.jpl.nasa.gov/foundation/analysis#>
        PREFIX mission: <http://imce.jpl.nasa.gov/foundation/mission#>
        PREFIX project: <http://imce.jpl.nasa.gov/foundation/project#>
        PREFIX metrology: <http://studioj.us/metrology#>
        SELECT ?id ?pid

        WHERE {
            ?wp project:supplies ?supplied_component .
            ?supplied_component base:hasIdentifier ?sid .
            GRAPH ?g {
                ?component oml:type oml:ConceptInstance .
            }
            ?g dc:creator ?creator .
            FILTER(?wp = IRI(STR(?creator)))
            ?component a mission:Component ;
                base:hasIdentifier ?id .
            ?supplied_component base:contains+ ?component .
            OPTIONAL { ?component ^base:contains [ base:hasIdentifier ?pid ] }
        }
    """
    
    const MP_QUERY = """
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX oml: <http://opencaesar.io/oml#>
        PREFIX base: <http://imce.jpl.nasa.gov/foundation/base#>
        PREFIX analysis: <http://imce.jpl.nasa.gov/foundation/analysis#>
        PREFIX mission: <http://imce.jpl.nasa.gov/foundation/mission#>
        PREFIX project: <http://imce.jpl.nasa.gov/foundation/project#>
        PREFIX metrology: <http://studioj.us/metrology#>
        SELECT ?id ?mass ?Cx ?Cy ?Cz ?Ixx ?Iyy ?Izz ?Ixy ?Ixz ?Iyz
                    ?sigma_mass ?sigma_Cx ?sigma_Cy ?sigma_Cz ?sigma_Ixx ?sigma_Iyy ?sigma_Izz ?sigma_Ixy ?sigma_Ixz ?sigma_Iyz

        WHERE {

            ?component a mission:Component ;
                base:hasIdentifier ?id .

            # get mass properties

                [ a metrology:MassValue ;
                    analysis:characterizes [
                        a metrology:MassQuantity ;
                        rdfs:label "mass" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?mass 
                ] .
                [ a metrology:CenterOfMassValue ;
                    analysis:characterizes [
                        a metrology:CenterOfMassQuantity ;
                        rdfs:label "Cx" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Cx
                ] .
                [ a metrology:CenterOfMassValue ;
                    analysis:characterizes [
                        a metrology:CenterOfMassQuantity ;
                        rdfs:label "Cy" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Cy
                ] .
                [ a metrology:CenterOfMassValue ;
                    analysis:characterizes [
                        a metrology:CenterOfMassQuantity ;
                        rdfs:label "Cz" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Cz
                ] .
                [ a metrology:MomentOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:MomentOfInertiaQuantity ;
                        rdfs:label "Ixx" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Ixx
                ] .
                [ a metrology:MomentOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:MomentOfInertiaQuantity ;
                        rdfs:label "Iyy" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Iyy
                ] .
                [ a metrology:MomentOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:MomentOfInertiaQuantity ;
                        rdfs:label "Izz" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Izz
                ] .
                [ a metrology:ProductOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:ProductOfInertiaQuantity ;
                        rdfs:label "Ixy" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Ixy
                ] .
                [ a metrology:ProductOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:ProductOfInertiaQuantity ;
                        rdfs:label "Ixz" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Ixz
                ] .
                [ a metrology:ProductOfInertiaValue ;
                    analysis:characterizes [
                        a metrology:ProductOfInertiaQuantity ;
                        rdfs:label "Iyz" ;
                        analysis:characterizes ?component
                    ] ;
                    metrology:hasNumber ?Iyz
                ] .
                
                    [ a metrology:MassValue ;
                        analysis:characterizes [
                            a metrology:MassQuantity ;
                            rdfs:label "sigma_mass" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_mass
                    ] .
                    [ a metrology:CenterOfMassValue ;
                        analysis:characterizes [
                            a metrology:CenterOfMassQuantity ;
                            rdfs:label "sigma_Cx" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Cx
                    ] .
                    [ a metrology:CenterOfMassValue ;
                        analysis:characterizes [
                            a metrology:CenterOfMassQuantity ;
                            rdfs:label "sigma_Cy" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Cy
                    ] .
                    [ a metrology:CenterOfMassValue ;
                        analysis:characterizes [
                            a metrology:CenterOfMassQuantity ;
                            rdfs:label "sigma_Cz" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Cz
                    ] .
                    [ a metrology:MomentOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:MomentOfInertiaQuantity ;
                            rdfs:label "sigma_Ixx" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Ixx
                    ] .
                    [ a metrology:MomentOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:MomentOfInertiaQuantity ;
                            rdfs:label "sigma_Iyy" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Iyy
                    ] .
                    [ a metrology:MomentOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:MomentOfInertiaQuantity ;
                            rdfs:label "sigma_Izz" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Izz
                    ] .
                    [ a metrology:ProductOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:ProductOfInertiaQuantity ;
                            rdfs:label "sigma_Ixy" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Ixy
                    ] .
                    [ a metrology:ProductOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:ProductOfInertiaQuantity ;
                            rdfs:label "sigma_Ixz" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Ixz
                    ] .
                    [ a metrology:ProductOfInertiaValue ;
                        analysis:characterizes [
                            a metrology:ProductOfInertiaQuantity ;
                            rdfs:label "sigma_Iyz" ;
                            analysis:characterizes ?component
                        ] ;
                        metrology:hasNumber ?sigma_Iyz
                    ] .
            
        }
    """

    function parse_commandline()
        s = ArgParseSettings()
        @add_arg_table s begin
        "--server"
            help = "Column name for server URL (default: http://127.0.0.1:8080)"
            arg_type = String
            default = "http://127.0.0.1:8080"
        "--path-base"
            help = "OML source path base (default: src/oml/model)"
            arg_type = String
            default = "src/model/oml"
        "--model-id"
            help = "Model ID for query (default: studioj.us/mass-props-oml/bundle)"
            arg_type = String
            default = "studioj.us/mass-props-oml/bundle"
        "--separator"
            help = "Namespace separator (default: #)"
            arg_type = String
            default = "#"
        end
        return parse_args(s)
    end

    function is_alive(server)
        resp = HTTP.get("$server/health")
        return resp.status == 200
    end

    function run_query(server, model_id, query)
       resp = HTTP.post("$server/v0/sparql/$model_id", body = query, headers = Dict("Content-Type" => "application/sparql-query"))
        if resp.status != 200
            @error "Query failed: $server/v0/sparql/$model_id"
            @error "Response: $(resp.status) - $(String(resp.body))"
            return nothing
        end
        return resp
    end

    function update(server, operations, defer_diagnostics=false)
        body = Dict("operations" => operations, "deferDiagnostics" => defer_diagnostics)
        resp = HTTP.post("$server/v0/update", headers=Dict("Content-Type" => "application/json"), body=JSON3.write(body))
        # open("/tmp/log.txt", "a") do log
        #     println(log, "Response: ", resp.status, " - ", String(resp.body))
        # end
        return resp.status == 200
    end

    function (@main)(ARGS)
        
        @info "begin RollupMassProps"
        args = parse_commandline()
    
        server = args["server"]
        model_id = args["model-id"]

        if !is_alive(server)
            @error "server is not alive: $server"
            exit(1)
        end

        mp_names_dict = OrderedDict()
        for name in MASS_PROPS
            mp_names_dict[name] = Union{Float64, Nothing}[]
        end
        table = DataFrame(merge(mp_names_dict, OrderedDict("id" => String[], "Ipoint" => Bool[], "POIconv" => String[])))
 
        graph_query_result = run_query(server, model_id, EDGE_QUERY)
        graph_query_result_json = JSON3.read(String(graph_query_result.body))
        graph_map = map(x -> (x["id"]["value"], x["pid"]["value"]), graph_query_result_json["results"]["bindings"])
        graph = MetaGraphsNext.MetaGraph(Graphs.DiGraph(), label_type = String)
        for edge in graph_map
            add_vertex!(graph, edge[1])
            add_vertex!(graph, edge[2])
            add_edge!(graph, edge[1], edge[2])
        end
        @info "Graph constructed with $(nv(graph)) vertices and $(ne(graph)) edges"

        # Build data frame.

        for vertex in map(v -> label_for(graph, v), vertices(graph))
            @info "Processing vertex: $(vertex)"
            mp_vals_dict = OrderedDict{String, Union{Float64, Nothing}}()
            for name in MASS_PROPS
                mp_vals_dict[name] = nothing
            end
            append!(
                table,
                DataFrame(
                    merge(
                        OrderedDict("id" => vertex, "Ipoint" => false, "POIconv" => "-"),
                        mp_vals_dict
                    )
                )
            )
        end
        
        # Populate leaf vertices with mass properties.

        mp_query_result = run_query(server, model_id, MP_QUERY)
        mp_query_result_json = JSON3.read(String(mp_query_result.body))
        for row in mp_query_result_json["results"]["bindings"]
            id = row["id"]["value"]
            for name in MASS_PROPS
                if haskey(row, name)
                    table[table.id .== id, name] .= parse(Float64, row[name]["value"])
                end
            end
        end
        @info "table $table"

        # Roll up mass properties.

        mp_table = rollup_mass_props_and_unc(graph, table)
        @info "Rollup results: $mp_table"

        @info "end RollupMassProps"
        exit(0)
    end

end # module
