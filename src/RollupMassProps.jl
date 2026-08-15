module Main

    using OMLCodeAPI
    using ArgParse
    using Logging
    using HTTP
    using JSON3
    using Graphs
    using MetaGraphsNext
    using DataFrames
    using DataStructures
    using MassProps
    using CSV

    const HAS_NUMBER = "http://bipm.org/jcgm/vim3-v#hasNumber"
    const HAS_UNIT = "http://bipm.org/jcgm/vim3-v#hasReference"
    const KG_UNIT = "http://iso.org/iso-80000/4.1-d#kilogram"
    const MM_UNIT = "http://iso.org/iso-80000/3.1-d#metre"
    const KG_MM_2_UNIT = "http://iso.org/iso-80000/4.7-d#kilogram_metre_squared"

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
	    PREFIX vim3-v: <http://bipm.org/jcgm/vim3-v#>
        PREFIX mass-properties-v: <http://studioj.us/mass-properties-v#>
        SELECT ?id ?mass ?Cx ?Cy ?Cz ?Ixx ?Iyy ?Izz ?Ixy ?Ixz ?Iyz
                    ?sigma_mass ?sigma_Cx ?sigma_Cy ?sigma_Cz ?sigma_Ixx ?sigma_Iyy ?sigma_Izz ?sigma_Ixy ?sigma_Ixz ?sigma_Iyz

        WHERE {

            ?component a mission:Component ;
                base:hasIdentifier ?id .

            # get mass properties

                [ a mass-properties-v:MassValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:Mass ;
                        rdfs:label "mass" ;
                        mass-properties-v:isMassOf ?component
                    ] ;
                    vim3-v:hasNumber ?mass 
                ] .
		
                [ a mass-properties-v:CenterOfMassCoordinateValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:CenterOfMassCoordinate ;
                        rdfs:label "Cx" ;
                        mass-properties-v:isCenterOfMassCoordinateOf ?component
                    ] ;
                    vim3-v:hasNumber ?Cx
                ] .
                [ a mass-properties-v:CenterOfMassCoordinateValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:CenterOfMassCoordinate ;
                        rdfs:label "Cy" ;
                        mass-properties-v:isCenterOfMassCoordinateOf ?component
                    ] ;
                    vim3-v:hasNumber ?Cy
                ] .
                [ a mass-properties-v:CenterOfMassCoordinateValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:CenterOfMassCoordinate ;
                        rdfs:label "Cz" ;
                        mass-properties-v:isCenterOfMassCoordinateOf ?component
                    ] ;
                    vim3-v:hasNumber ?Cz
                ] .
                [ a mass-properties-v:MomentOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:MomentOfInertia ;
                        rdfs:label "Ixx" ;
                        mass-properties-v:isMomentOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Ixx
                ] .
                [ a mass-properties-v:MomentOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:MomentOfInertia ;
                        rdfs:label "Iyy" ;
                        mass-properties-v:isMomentOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Iyy
                ] .
                [ a mass-properties-v:MomentOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:MomentOfInertia ;
                        rdfs:label "Izz" ;
                        mass-properties-v:isMomentOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Izz
                ] .
                [ a mass-properties-v:ProductOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:ProductOfInertia ;
                        rdfs:label "Ixy" ;
                        mass-properties-v:isProductOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Ixy
                ] .
                [ a mass-properties-v:ProductOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:ProductOfInertia ;
                        rdfs:label "Ixz" ;
                        mass-properties-v:isProductOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Ixz
                ] .
                [ a mass-properties-v:ProductOfInertiaValue ;
                    vim3-v:expressesMagnitudeOf [
                        a mass-properties-v:ProductOfInertia ;
                        rdfs:label "Iyz" ;
                        mass-properties-v:isProductOfInertiaOf ?component
                    ] ;
                    vim3-v:hasNumber ?Iyz
                ] .
                
                    [ a mass-properties-v:MassValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:Mass ;
                            rdfs:label "sigma_mass" ;
                            mass-properties-v:isMassOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_mass
                    ] .
                    [ a mass-properties-v:CenterOfMassCoordinateValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:CenterOfMassCoordinate ;
                            rdfs:label "sigma_Cx" ;
                            mass-properties-v:isCenterOfMassCoordinateOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Cx
                    ] .
                    [ a mass-properties-v:CenterOfMassCoordinateValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:CenterOfMassCoordinate ;
                            rdfs:label "sigma_Cy" ;
                            mass-properties-v:isCenterOfMassCoordinateOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Cy
                    ] .
                    [ a mass-properties-v:CenterOfMassCoordinateValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:CenterOfMassCoordinate ;
                            rdfs:label "sigma_Cz" ;
                            mass-properties-v:isCenterOfMassCoordinateOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Cz
                    ] .
                    [ a mass-properties-v:MomentOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:MomentOfInertia ;
                            rdfs:label "sigma_Ixx" ;
                            mass-properties-v:isMomentOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Ixx
                    ] .
                    [ a mass-properties-v:MomentOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:MomentOfInertia ;
                            rdfs:label "sigma_Iyy" ;
                            mass-properties-v:isMomentOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Iyy
                    ] .
                    [ a mass-properties-v:MomentOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:MomentOfInertia ;
                            rdfs:label "sigma_Izz" ;
                            mass-properties-v:isMomentOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Izz
                    ] .
                    [ a mass-properties-v:ProductOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:ProductOfInertia ;
                            rdfs:label "sigma_Ixy" ;
                            mass-properties-v:isProductOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Ixy
                    ] .
                    [ a mass-properties-v:ProductOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:ProductOfInertia ;
                            rdfs:label "sigma_Ixz" ;
                            mass-properties-v:isProductOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Ixz
                    ] .
                    [ a mass-properties-v:ProductOfInertiaValue ;
                        vim3-v:expressesMagnitudeOf [
                            a mass-properties-v:ProductOfInertia ;
                            rdfs:label "sigma_Iyz" ;
                            mass-properties-v:isProductOfInertiaOf ?component
                        ] ;
                        vim3-v:hasNumber ?sigma_Iyz
                    ] .
            
        }
    """

    const DESC_QUERY = """
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX oml: <http://opencaesar.io/oml#>
        PREFIX base: <http://imce.jpl.nasa.gov/foundation/base#>
        PREFIX analysis: <http://imce.jpl.nasa.gov/foundation/analysis#>
        PREFIX mission: <http://imce.jpl.nasa.gov/foundation/mission#>
        PREFIX project: <http://imce.jpl.nasa.gov/foundation/project#>
	    PREFIX vim3-v: <http://bipm.org/jcgm/vim3-v#>
        SELECT ?id ?g

        WHERE {

            ?component a mission:Component ;
                base:hasIdentifier ?id .

            GRAPH ?g {
                ?mv vim3-v:expressesMagnitudeOf ?mq ;
                    rdfs:label "mass" .
            }
            ?mq vim3-v:isPropertyOf ?component .
        }
    """

    unit_map = Dict(
        "mass" => KG_UNIT,
        "Cx" => MM_UNIT,
        "Cy" => MM_UNIT,
        "Cz" => MM_UNIT,
        "Ixx" => KG_MM_2_UNIT,
        "Iyy" => KG_MM_2_UNIT,
        "Izz" => KG_MM_2_UNIT,
        "Ixy" => KG_MM_2_UNIT,
        "Ixz" => KG_MM_2_UNIT,
        "Iyz" => KG_MM_2_UNIT,
        "sigma_mass" => KG_UNIT,
        "sigma_Cx" => MM_UNIT,
        "sigma_Cy" => MM_UNIT,
        "sigma_Cz" => MM_UNIT,
        "sigma_Ixx" => KG_MM_2_UNIT,
        "sigma_Iyy" => KG_MM_2_UNIT,
        "sigma_Izz" => KG_MM_2_UNIT,
        "sigma_Ixy" => KG_MM_2_UNIT,
        "sigma_Ixz" => KG_MM_2_UNIT,
        "sigma_Iyz" => KG_MM_2_UNIT
    )

    function parse_commandline()
        s = ArgParseSettings()
        @add_arg_table s begin
        "--server"
            help = "Column name for server URL (default: http://127.0.0.1:8080)"
            arg_type = String
            default = "http://127.0.0.1:8080"
        "--model-id"
            help = "Model ID for query (default: studioj.us/mass-props-oml/bundle)"
            arg_type = String
            default = "studioj.us/mass-props-oml/bundle"
        "--separator"
            help = "Namespace separator (default: #)"
            arg_type = String
            default = "#"
        "--output"
            help = "Output file name (default: /tmp/rollup-mass-props.csv)"
            arg_type = String
            default = "/tmp/rollup-mass-props.csv"
        end
        return parse_args(s)
    end

    function (@main)(ARGS)
        
        @info "begin RollupMassProps"
        args = parse_commandline()
    
        server = args["server"]
        model_id = args["model-id"]
        separator = args["separator"]
        output = args["output"]

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
        @info " constructed with $(nv(graph)) vertices and $(ne(graph)) edges"

        # Build data frame.

        for vertex in map(v -> label_for(graph, v), vertices(graph))
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
        @info "DataFrame constructed with $(nrow(table)) rows and $(ncol(table)) columns"
        
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
        @info "Leaf vertices populated with mass properties"

        # Roll up mass properties.

        mp_table = rollup_mass_props_and_unc(graph, table)
        @info "Mass properties rolled up to parent vertices"

        # Save rolled up mass properties to CSV.
        f = args["output"] == "" ? stdout : open(args["output"], "w")
        CSV.write(f, mp_table)
        close(f)

        # Look up QV description for each component.

        desc_query_result = run_query(server, model_id, DESC_QUERY)
        desc_query_result_json = JSON3.read(String(desc_query_result.body))
        desc_map = Dict(x["id"]["value"] => x["g"]["value"] for x in desc_query_result_json["results"]["bindings"])
        for (id, desc) in desc_map
            if (inneighbors(graph, code_for(graph, id)) |> collect |> length) > 0
                operations = []
                @info "update values for $id"
                desc_iri = "$desc#"
                for prop in MASS_PROPS
                    if !ismissing(table[table.id .== id, prop][1])
                        subject_iri = "$desc$separator$(id)_$(prop)_value"
                        number = mp_table[mp_table.id .== id, prop][1]
                        unit = unit_map[prop]
                        push!(operations, add_assertion(desc_iri, subject_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => number)))
                        push!(operations, add_assertion(desc, subject_iri, HAS_UNIT, unit))
                    end
                end
                update(server, operations, true)
            end
       end

        @info "end RollupMassProps"
        exit(0)
 

   end
end # module
