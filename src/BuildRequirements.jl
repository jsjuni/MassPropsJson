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
    using CSV
    using Distributions
    using Printf
    using OMLCodeAPI

    const RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    const REQUIREMENT = "http://imce.jpl.nasa.gov/foundation/mission#Requirement"
    const QUANTITY_VALUE_CONSTRAINT = "http://imce.jpl.nasa.gov/foundation/analysis#QuantityValueConstraint"
    const HAS_QUANTITY_VALUE_RELATION = "http://imce.jpl.nasa.gov/foundation/analysis#hasQuantityValueRelation"
    const HAS_REQUIREMENT_IDENTIFIER = "<http://studioj.us/base#hasRequirementIdentifier>"
    const HAS_DESCRIPTION = "http://imce.jpl.nasa.gov/foundation/base#hasDescription"
    const DC_CREATOR = "http://purl.org/dc/elements/1.1/creator"
    const ANALYZES = "http://imce.jpl.nasa.gov/foundation/analysis#analyzes"
    const EXPLAINS = "http://imce.jpl.nasa.gov/foundation/analysis#explains"
    const REQUIRES = "http://imce.jpl.nasa.gov/foundation/analysis#requires"
    const DC_RIGHTS = "http://purl.org/dc/elements/1.1/rights"
    const HAS_NUMBER = "http://bipm.org/jcgm/vim3-v#hasNumber>"
    const HAS_REFERENCE = "http://bipm.org/jcgm/vim3-v#hasReference>"
    const KG_UNIT = "<http://iso.org/iso-80000/4.1-d#kilogram>"
    const MM_UNIT = "<http://iso.org/iso-80000/3.1-d#millimetre>"
    const KG_MM_2_UNIT = "<http://iso.org/iso-80000/4.7-v#kilogram-metre-squared>"
    const MASS_VALUE = "<http://studioj.us/mass-properties-v#MassValue>"
    const CENTER_OF_MASS_COORDINATE = "<http://studioj.us/mass-properties-v#CenterOfMassCoordinate>"

    const DESC_QUERY = """
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX oml: <http://opencaesar.io/oml#>
        PREFIX base: <http://imce.jpl.nasa.gov/foundation/base#>
        PREFIX analysis: <http://imce.jpl.nasa.gov/foundation/analysis#>
        PREFIX mission: <http://imce.jpl.nasa.gov/foundation/mission#>
        PREFIX project: <http://imce.jpl.nasa.gov/foundation/project#>
        PREFIX metrology: <http://studioj.us/metrology#>
        PREFIX mass-properties-v: <http://studioj.us/mass-properties-v#>

        SELECT ?id ?name ?g ?creator ?rights
        WHERE {

            ?component a mission:Component ;
                base:hasIdentifier ?id ;
                base:hasCanonicalName ?name .
            GRAPH ?g {
                ?mq mass-properties-v:isMassOf ?component ;
                    rdfs:label "mass" .
            }
            ?g dc:creator ?creator ;
                dc:rights ?rights .

        }
    """
    
    unit_map = Dict(
        "mass" => KG_UNIT,
        "Cx" => MM_UNIT,
        "Cy" => MM_UNIT,
        "Cz" => MM_UNIT
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
        "--path-base"
            help = "OML source path base (default: src/oml/model)"
            arg_type = String
            default = "src/model/oml"
        "--separator"
            help = "Namespace separator (default: #)"
            arg_type = String
            default = "#"
        "--input"
            help = "Input file name (default: /tmp/rollup-mass-props.csv)"
            arg_type = String
            default = "/tmp/rollup-mass-props.csv"
        "--bundle"
            help = "Description bundle (default: http://studioj.us/mass-props-oml/bundle)"
            arg_type = String
            default = "http://studioj.us/mass-props-oml/bundle"
        end
        return parse_args(s)
    end

    function is_alive(server)
        resp = HTTP.get("$server/health")
        return resp.status == 200
    end

    function update(server, operations, defer_diagnostics=false)
        body = Dict("operations" => operations, "deferDiagnostics" => defer_diagnostics)
        resp = HTTP.post("$server/v0/update", headers=Dict("Content-Type" => "application/json"), body=JSON3.write(body))
        # open("/tmp/log.txt", "a") do log
        #     println(log, "Response: ", resp.status, " - ", String(resp.body))
        # end
        return resp.status == 200
    end

    function delete_description(namespace)
        Dict(
            "deleteOntology" => Dict(
                "ontologyIri" => namespace
            )
        )
    end

    function add_description(namespace, prefix, path)
        Dict(
            "createOntology" => Dict(
                "ontologyKind" => "description",
                "ontologyNamespace" => namespace,
                "ontologyPrefix" => prefix,
                "targetFolder" => path
            )
        )
    end

    function add_import(importing, imported)
        Dict(
            "addImport" => Dict(
                "importingIri" => importing,
                "importedIri" => imported,
            )
        )
    end

    function add_assertion(description_iri, subject_iri, predicate_iri, object_iri)
        Dict(
            "addAssertion" => Dict(
                "descriptionIri" => description_iri,
                "subjectIri" => subject_iri,
                "predicateIri" => predicate_iri,
                "object" => object_iri
            )
        )
    end

    function add_annotation(ontologyIri, subjectIri, predicateIri, object)
        Dict(
            "addAnnotation" => Dict(
                "ontologyIri" => ontologyIri,
                "subjectIri" => subjectIri,
                "predicateIri" => predicateIri,
                "object" => object
            )
        )
    end

    function add_authorization(iri, authorizer)
        add_annotation(iri, iri, DC_CREATOR, Dict("datatypeIri" => "http://www.w3.org/2001/XMLSchema#anyURI", "value" => authorizer))
    end

    function add_rights(iri, grantee)
        add_annotation(iri, iri, DC_RIGHTS, Dict("datatypeIri" => "http://www.w3.org/2001/XMLSchema#anyURI", "value" => grantee))
    end

    function create_instance(description_iri, name)
        Dict(
            "createInstance" => Dict(
                "descriptionIri" => description_iri,
                "instanceName" => name
            )
        )
    end

    function (@main)(ARGS)
        
        @info "begin BuildRequirements"
        args = parse_commandline()
    
        server = args["server"]
        model_id = args["model-id"]
        separator = args["separator"]
        input = args["input"]
        bundle = args["bundle"]

        if !is_alive(server)
            @error "server is not alive: $server"
            exit(1)
        end

        # Load mass properties.

        f = CSV.File(input)
        df = DataFrame(f)
        @info "loaded $(nrow(df)) rows from $input"

        # Find mapping to descriptions.

        desc_query_result = run_query(server, model_id, DESC_QUERY)
        if desc_query_result === nothing
            @error "failed to run description query"
            exit(1)
        end

        desc_query_result_json = JSON3.read(String(desc_query_result.body))
        desc_map = Dict{String, Dict{String, String}}()
        for row in desc_query_result_json["results"]["bindings"]
            id = row["id"]["value"]
            name = row["name"]["value"]
            g = row["g"]["value"]
            creator = row["creator"]["value"]
            rights = row["rights"]["value"]
            desc_map[id] = Dict("name" => name, "g" => g, "creator" => creator, "rights" => rights)
        end
        @info "desc_map has $(length(desc_map)) entries"

        deferred = []

        # Create requirements.

        for (id, map) in desc_map
            @info "processing $id"
            operations = []

            # Create description.

            desc_iri = replace(map["g"], "/Q/" => "/R/")
            push!(operations, delete_description(desc_iri))
            push!(operations, add_description(desc_iri, "$(id)_R", args["path-base"]))

            push!(operations, add_authorization(desc_iri, map["creator"]))
            push!(operations, add_rights(desc_iri, map["rights"]))

            push!(deferred, add_import(bundle, desc_iri))

            # Get bound values for mass.

            mass = df[df.id .== id, "mass"][1]
            sigma_mass = df[df.id .== id, "sigma_mass"][1]
            upper_mass = @sprintf("%.2f", rand(Normal(mass, sigma_mass), 1)[1] + 2.0 * sigma_mass)

            # Create mass upper bound requirement.

            mr_id = "$(id)_R.1"
            mr_name = "$(id)_mass_max"
            mr_iri = "$(desc_iri)$separator$mr_name"
            mr_desc = "The $(desc_map[id]["name"]) mass shall not exceed $upper_mass kg."

            push!(operations, create_instance(desc_iri, mr_name))
            push!(operations, add_assertion(desc_iri, mr_iri, RDF_TYPE, REQUIREMENT))
            push!(operations, add_assertion(desc_iri, mr_iri, HAS_REQUIREMENT_IDENTIFIER, mr_id))
            push!(operations, add_assertion(desc_iri, mr_iri, HAS_DESCRIPTION, mr_desc))

            # Create mass max constraint.

            mc_name = "$(id)_mass_max_constraint"
            mc_iri = "$(desc_iri)$separator$mc_name"

            push!(operations, create_instance(desc_iri, mc_name))
            push!(operations, add_assertion(desc_iri, mc_iri, RDF_TYPE, QUANTITY_VALUE_CONSTRAINT))
            push!(operations, add_assertion(desc_iri, mc_iri, HAS_QUANTITY_VALUE_RELATION, "le"))
            push!(operations, add_assertion(desc_iri, mr_iri, REQUIRES, mc_iri))

            # Assert explanation of mass quantity by constraint.
            
            q_desc_iri = map["g"]
            mq_name = "$(id)_mass"
            mq_iri = "$(q_desc_iri)$separator$mq_name"

            push!(operations, add_assertion(desc_iri, mc_iri, EXPLAINS, mq_iri))

            # Create bounding mass value.

            mv_name = "$(id)_mass_max_value"
            mv_iri = "$(desc_iri)$separator$mv_name"
            push!(operations, create_instance(desc_iri, mv_name))
            push!(operations, add_assertion(desc_iri, mv_iri, RDF_TYPE, MASS_VALUE))
            push!(operations, add_assertion(desc_iri, mc_iri, ANALYZES, mv_iri))
            push!(operations, add_assertion(desc_iri, mv_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => upper_mass)))
            push!(operations, add_assertion(desc_iri, mv_iri, HAS_REFERENCE, KG_UNIT))

            nr = 1
            for c in ["Cx", "Cy", "Cz"]

                # Create range requirement for each center of mass coordinate.

                nr += 1
                cr_id = "$(id)_R.$(c)_R.$nr"
                cr_name = "$(id)_$(c)_range"
                cr_iri = "$(desc_iri)$separator$cr_name"

                cv = df[df.id .== id, c][1]
                sigma_cv = df[df.id .== id, "sigma_$c"][1]
                cv_center = rand(Normal(cv, sigma_cv), 1)[1]
                cv_lower = @sprintf("%.2f", cv_center - 2.0 * sigma_cv)
                cv_upper = @sprintf("%.2f", cv_center + 2.0 * sigma_cv)
                cv_desc = "The $(desc_map[id]["name"]) $c shall lie in the interval [$cv_lower, $cv_upper] mm."

                push!(operations, create_instance(desc_iri, cr_name))

                push!(operations, add_assertion(desc_iri, cr_iri, RDF_TYPE, REQUIREMENT))
                push!(operations, add_assertion(desc_iri, cr_iri, HAS_REQUIREMENT_IDENTIFIER, cr_id))
                push!(operations, add_assertion(desc_iri, cr_iri, HAS_DESCRIPTION, cv_desc))

                # Create min and max constraints for each center of mass coordinate.

                cc_min_name = "$(id)_$(c)_min_constraint"
                cc_min_iri = "$(desc_iri)$separator$cc_min_name"
                push!(operations, create_instance(desc_iri, cc_min_name))
                push!(operations, add_assertion(desc_iri, cc_min_iri, RDF_TYPE, QUANTITY_VALUE_CONSTRAINT))
                push!(operations, add_assertion(desc_iri, cc_min_iri, HAS_QUANTITY_VALUE_RELATION, "ge"))
                push!(operations, add_assertion(desc_iri, cr_iri, REQUIRES, cc_min_iri))

                cc_max_name = "$(id)_$(c)_max_constraint"
                cc_max_iri = "$(desc_iri)$separator$cc_max_name"
                push!(operations, create_instance(desc_iri, cc_max_name))
                push!(operations, add_assertion(desc_iri, cc_max_iri, RDF_TYPE, QUANTITY_VALUE_CONSTRAINT))
                push!(operations, add_assertion(desc_iri, cc_max_iri, HAS_QUANTITY_VALUE_RELATION, "le"))
                push!(operations, add_assertion(desc_iri, cr_iri, REQUIRES, cc_max_iri))

                # Assert explanation of each center of mass quantity by min and max constraints.

                cq_name = "$(id)_$(c)"
                cq_iri = "$(q_desc_iri)$separator$cq_name"

                push!(operations, add_assertion(desc_iri, cc_min_iri, EXPLAINS, cq_iri))
                push!(operations, add_assertion(desc_iri, cc_max_iri, EXPLAINS, cq_iri))

                # Create bounding values for each center of mass coordinate.

                cmv_min_name = "$(id)_$(c)_min_value"
                cmv_min_iri = "$(desc_iri)$separator$cmv_min_name"
                push!(operations, create_instance(desc_iri, cmv_min_name))
                push!(operations, add_assertion(desc_iri, cmv_min_iri, RDF_TYPE, CENTER_OF_MASS_COORDINATE))
                push!(operations, add_assertion(desc_iri, cmv_min_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => cv_lower)))
                push!(operations, add_assertion(desc_iri, cmv_min_iri, HAS_REFERENCE, MM_UNIT))
                push!(operations, add_assertion(desc_iri, cc_min_iri, ANALYZES, cmv_min_iri))

                cmv_max_name = "$(id)_$(c)_max_value"
                cmv_max_iri = "$(desc_iri)$separator$cmv_max_name"
                push!(operations, create_instance(desc_iri, cmv_max_name))
                push!(operations, add_assertion(desc_iri, cmv_max_iri, RDF_TYPE, CENTER_OF_MASS_COORDINATE))
                push!(operations, add_assertion(desc_iri, cmv_max_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => cv_upper)))
                push!(operations, add_assertion(desc_iri, cmv_max_iri, HAS_REFERENCE, MM_UNIT))
                push!(operations, add_assertion(desc_iri, cc_max_iri, ANALYZES, cmv_max_iri))
            
            end
        
            update(server, operations, true)
        end

        update(server, deferred, true)
        @info "description bundle $bundle updated"
        
        @info "end BuildRequirements"
        exit(0)
    end
end # module
