module Main

using ArgParse
using JSON3
using HTTP

const RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
const RDFS_LABEL = "http://www.w3.org/2000/01/rdf-schema#label"
const DC_CREATOR = "http://purl.org/dc/elements/1.1/creator"
const HAS_CANONICAL_NAME = "http://imce.jpl.nasa.gov/foundation/base#hasCanonicalName"
const IS_CONTAINED_IN = "http://imce.jpl.nasa.gov/foundation/base#isContainedIn"
const CHARACTERIZES = "http://imce.jpl.nasa.gov/foundation/analysis#characterizes"
const WORK_PACKAGE = "http://imce.jpl.nasa.gov/foundation/project#WorkPackage"
const COMPONENT = "http://imce.jpl.nasa.gov/foundation/mission#Component"
const SUPPLIES = "http://imce.jpl.nasa.gov/foundation/project#supplies"
const HAS_NUMBER = "<http://studioj.us/metrology#hasNumber>"
const HAS_UNIT = "<http://studioj.us/metrology#hasUnit>"
const HAS_POI_CONVENTION = "<http://studioj.us/metrology#hasPoiConvention>"
const IS_POINT_MASS = "<http://studioj.us/metrology#isPointMass>"
const HAS_COMPONENT_IDENTIFIER = "<http://studioj.us/base#hasComponentIdentifier"
const HAS_WORK_PACKAGE_IDENTIFIER = "<http://studioj.us/base#hasWorkPackageIdentifier"
const KG_UNIT = "<http://studioj.us/units#kg>"
const MM_UNIT = "<http://studioj.us/units#mm>"
const KG_MM_2_UNIT = "<http://studioj.us/units#kg_mm_2"
const HAS_SORT_KEY = "<http://imce.jpl.nasa.gov/foundation/base#hasSortKey>"

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--input"
        help = "Input file (JSON)"
        arg_type = String
        required = true
        "--limit"
        help = "Limit number of components to process (default: no limit)"
        arg_type = Int64
        default = 0
        "--server"
        help = "Column name for server URL (default: http://127.0.0.1:8080)"
        arg_type = String
        default = "http://127.0.0.1:8080"
        "--path-base"
        help = "OML source path base (default: src/oml/model)"
        arg_type = String
        default = "src/model/oml"
        "--namespace-base"
        help = "Base namespace for OML (default: http://studioj.us/mass-props-oml)"
        arg_type = String
        default = "http://studioj.us/mass-props-oml"
        "--separator"
        help = "Namespace separator (default: #)"
        arg_type = String
        default = "#"
        "--deferred"
        help = "Defer updates until the end (default: false)"
        action = :store_true
    end
    return parse_args(s)
end

function is_alive(server)
    resp = HTTP.get("$server/health")
    return resp.status == 200
end

function update(server, operations)
    body = Dict("operations" => operations, "deferDiagnostics" => true)
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

function add_description_bundle(namespace, prefix, path)
    Dict(
        "createOntology" => Dict(
            "ontologyKind" => "description bundle",
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

function add_authorization(iri, authorizer)
    Dict(
        "addAnnotation" => Dict(
            "ontologyIri" => iri,
            "subjectIri" => iri,
            "predicateIri" => DC_CREATOR,
            "object" => authorizer
        )
    )
end

function create_instance(description_iri, name)
    Dict(
        "createInstance" => Dict(
            "descriptionIri" => description_iri,
            "instanceName" => name
        )
    )
end

function create_instance_ref(description_iri, iri)
    Dict(
        "createInstanceRef" => Dict(
            "descriptionIri" => description_iri,
            "instanceIri" => iri
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

function xsd_double(value)
    "$value"
end

function (@main)(ARGS)

    quantity_map = Dict(
        "mass" => "MassQuantity",
        "Cx" => "CenterOfMassQuantity",
        "Cy" => "CenterOfMassQuantity",
        "Cz" => "CenterOfMassQuantity",
        "Ixx" => "MomentOfInertiaQuantity",
        "Iyy" => "MomentOfInertiaQuantity",
        "Izz" => "MomentOfInertiaQuantity",
        "Ixy" => "ProductOfInertiaQuantity",
        "Ixz" => "ProductOfInertiaQuantity",
        "Iyz" => "ProductOfInertiaQuantity",
        "sigma_mass" => "MassQuantity",
        "sigma_Cx" => "CenterOfMassQuantity",
        "sigma_Cy" => "CenterOfMassQuantity",
        "sigma_Cz" => "CenterOfMassQuantity",
        "sigma_Ixx" => "MomentOfInertiaQuantity",
        "sigma_Iyy" => "MomentOfInertiaQuantity",
        "sigma_Izz" => "MomentOfInertiaQuantity",
        "sigma_Ixy" => "ProductOfInertiaQuantity",
        "sigma_Ixz" => "ProductOfInertiaQuantity",
        "sigma_Iyz" => "ProductOfInertiaQuantity"
    )

    unit_map = Dict(
        "MassQuantity" => KG_UNIT,
        "CenterOfMassQuantity" => MM_UNIT,
        "MomentOfInertiaQuantity" => KG_MM_2_UNIT,
        "ProductOfInertiaQuantity" => KG_MM_2_UNIT
    )

    args = parse_commandline()

    start_time = time()

    vl = JSON3.read(args["input"])

    server = args["server"]

    if !is_alive(server)
        println("Server is not alive at ", args["server"])
        exit(1)
    end

    deferred = []
    updates = []

    # create description bundle

    db_iri = args["namespace-base"] * "/bundle"
    db_ns = db_iri = db_iri * args["separator"]
    db_prefix = "description-bundle"

    bundled = [add_description_bundle(db_ns, db_prefix, args["path-base"])]

    for (i, v) in enumerate(vl)
        if args["limit"] > 0 && i > args["limit"]
            println("Reached limit of ", args["limit"], " components. Stopping.")
            break
        end
        wp = String(v.first)
        wpd = v.second

        operations = []

        authorizer = wpd["isAuthorizedBy"]

        # description for quantity values

        qvd_iri = args["namespace-base"] * "/" * wp * "/QV"
        qvd_ns = qvd_iri * args["separator"]
        qvd_prefix = wp * "_QV"

        # parent iris and namespaces

        parent_wp_iri_frag = args["namespace-base"] * "/" * authorizer

        comp_d_iri = parent_wp_iri_frag * "/C"
        comp_d_ns = comp_d_iri * args["separator"]
        comp_iri = comp_d_ns * wpd["supplies"]
 
        comp_qd_iri = parent_wp_iri_frag * "/Q"
        comp_qd_ns = comp_qd_iri * args["separator"]

        parent_wp_iri = parent_wp_iri_frag * "/WP" * args["separator"] * wp

        # description for quantities

        qd_iri = args["namespace-base"] * "/" * wp * "/Q"
        qd_ns = qd_iri * args["separator"]
        qd_prefix = wp * "_Q"

        push!(operations, add_description(qvd_ns, qvd_prefix, args["path-base"]))
        push!(bundled, add_import(db_ns, qvd_ns))

        if length(wpd["authorizes"]) > 0

            # description for components

            cd_iri = args["namespace-base"] * "/" * wp * "/C"
            cd_ns = cd_iri * args["separator"]
            cd_prefix = wp * "_C"

            # description for work packages

            wpd_iri = args["namespace-base"] * "/" * wp * "/WP"
            wpd_ns = wpd_iri * args["separator"]
            wpd_prefix = wp * "_WP"

             # create descriptions

            push!(operations, add_description(cd_ns, cd_prefix, args["path-base"]))
            push!(bundled, add_import(db_ns, cd_ns))
            push!(operations, add_description(wpd_ns, wpd_prefix, args["path-base"]))
            push!(bundled, add_import(db_ns, wpd_ns))
            push!(operations, add_description(qd_ns, qd_prefix, args["path-base"]))
            push!(bundled, add_import(db_ns, qd_ns))

            for (wp, comp) in wpd["authorizes"]

                # create work package

                push!(operations, create_instance(wpd_iri, wp))
                child_wp_iri = wpd_ns * String(wp)
                push!(operations, add_assertion(wpd_iri, child_wp_iri, RDF_TYPE, WORK_PACKAGE))
                push!(operations, add_assertion(wpd_iri, child_wp_iri, HAS_CANONICAL_NAME, wpd["hasName"][comp]))
                push!(operations, add_assertion(wpd_iri, child_wp_iri, HAS_WORK_PACKAGE_IDENTIFIER, wp))
                push!(operations, add_assertion(wpd_iri, child_wp_iri, HAS_SORT_KEY, wpd["hasSortKey"][comp]))

                # create component

                push!(operations, create_instance(cd_iri, comp))
                child_comp_iri = cd_ns * String(comp)
                push!(operations, add_assertion(cd_iri, child_comp_iri, RDF_TYPE, COMPONENT))
                push!(operations, add_assertion(cd_iri, child_comp_iri, HAS_CANONICAL_NAME, wpd["hasName"][comp]))
                push!(operations, add_assertion(cd_iri, child_comp_iri, HAS_COMPONENT_IDENTIFIER, comp))
                push!(operations, add_assertion(cd_iri, child_comp_iri, HAS_SORT_KEY, wpd["hasSortKey"][comp]))
                if (comp_iri != child_comp_iri)
                    push!(operations, add_assertion(cd_iri, child_comp_iri, IS_CONTAINED_IN, comp_iri))
                end

                # add supplies relation from work package to component

                push!(operations, add_assertion(wpd_iri, child_wp_iri, SUPPLIES, child_comp_iri))

                # create mass property quantities and quantity values

                for (quantity, kind) in quantity_map
                    q_name = comp * "_" * quantity
                    q_iri = qd_ns * q_name
                    push!(operations, create_instance(qd_iri, q_name))
                    push!(operations, add_annotation(qd_iri, q_iri, RDFS_LABEL, quantity))
                    push!(operations, add_assertion(qd_iri, q_iri, RDF_TYPE, "http://studioj.us/metrology#$kind"))
                    push!(operations, add_assertion(qd_iri, q_iri, CHARACTERIZES, child_comp_iri))
                end

            end

            # add authorization annotations to descriptions

            push!(operations, add_authorization(cd_iri, parent_wp_iri))
            push!(operations, add_authorization(wpd_iri, parent_wp_iri))
            push!(operations, add_authorization(qd_iri, parent_wp_iri))

        end

        # add quantity values

        for (quantity, kind) in quantity_map
            q_name = wpd["supplies"] * "_" * quantity
            qv_name = q_name * "_value"
            q_iri = comp_qd_ns * q_name
            qv_iri = qvd_ns * qv_name
            qtype = replace(kind, "Quantity" => "Value")
            push!(operations, create_instance(qvd_iri, qv_name))
            push!(operations, add_annotation(qvd_iri, qv_iri, RDFS_LABEL, quantity))
            push!(operations, add_assertion(qvd_iri, qv_iri, RDF_TYPE, "http://studioj.us/metrology#$qtype"))
            push!(operations, add_assertion(qvd_iri, qv_iri, CHARACTERIZES, q_iri))

            if haskey(wpd, "hasValues") && haskey(wpd["hasValues"], quantity)
                value = parse(Float64, wpd["hasValues"][quantity])
                push!(operations, add_assertion(qvd_iri, qv_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => value)))
                push!(operations, add_assertion(qvd_iri, qv_iri, HAS_UNIT, unit_map[kind]))
             end
        end

        # add related property values

        push!(operations, create_instance_ref(qvd_iri, comp_iri))
        push!(operations, add_assertion(qvd_iri, comp_iri, HAS_POI_CONVENTION, wpd["hasPOIconv"]))
        push!(operations, add_assertion(qvd_iri, comp_iri, IS_POINT_MASS, wpd["isPointMass"]))

        # add authorization annotations to descriptions

        push!(operations, add_authorization(qvd_iri, parent_wp_iri))

        # update server
        
        if args["deferred"]
            push!(deferred, operations...)
            println("Deferred update for ", wp, " with ", length(operations), " operations")
        else
            t1 = time()
            update(server, operations)
            t2 = time()
            println("Updated server for ", wp, " (", i, ") ", length(operations), " operations in ", round(t2 - t1, digits=2), " s")
            # sleep(1)
            push!(updates, operations)
        end

    end

    if args["deferred"]
        push!(deferred, bundled)
        println("Deferred update for description bundle with ", length(bundled), " operations")
    else
        t1 = time()
        update(server, bundled)
        t2 = time()
        println("Updated server for description bundle with ", length(bundled), " operations in ", round(t2 - t1, digits=2), " s")
    end

    if args["deferred"] && length(deferred) > 0
        t1 = time()
        update(server, deferred)
        t2 = time()
        println("Updated server with ", length(deferred), " operations in ", round(t2 - t1, digits=2), " s")
        open("/tmp/operations.json", "w") do file
            JSON3.pretty(file, deferred)
        end
    end

    open("/tmp/updates.json", "w") do file
        JSON3.pretty(file, updates)
    end

    end_time = time()
    println("finished in ", round(end_time - start_time, digits=2), " s")

    exit(0)
end

end # module
