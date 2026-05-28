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
    body = Dict("operations" => operations)
    resp = HTTP.post("$server/v0/update", headers=Dict("Content-Type" => "application/json"), body=JSON3.write(body))
    # println("Response: ", resp.status, " - ", String(resp.body))
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

function add_authorization(iri, authorizer)
    Dict(
        "addAnnotation" => Dict(
            "ontologyIri" => iri,
            "subjectIri" => iri,
            "predicateIri" => "http://purl.org/dc/elements/1.1/creator",
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

    args = parse_commandline()

    vl = JSON3.read(args["input"])

    server = args["server"]

    if !is_alive(server)
        println("Server is not alive at ", args["server"])
        exit(1)
    end

    deferred = []

    for (i, v) in enumerate(vl)
        if args["limit"] > 0 && i > args["limit"]
            println("Reached limit of ", args["limit"], " components. Stopping.")
            break
        end
        wp = String(v.first)
        wpd = v.second

        if length(wpd["authorizes"]) == 0
            continue
        end

        operations = []

        # description for quantities

        qd_iri = args["namespace-base"] * "/" * wp * "/Q"
        qd_ns = qd_iri * args["separator"]
        qd_prefix = wp * "_Q"

        # description for quantity values

        qvd_iri = args["namespace-base"] * "/" * wp * "/QV"
        qvd_ns = qvd_iri * args["separator"]
        qvd_prefix = wp * "_QV"

        # parent iris and namespaces

        parent_wp_iri_frag = args["namespace-base"] * "/" * wpd["isAuthorizedBy"]

        cont_comp_d_iri = parent_wp_iri_frag * "/C"
        cont_comp_d_ns = cont_comp_d_iri * args["separator"]

        cont_comp_qd_iri = parent_wp_iri_frag * "/Q"
        cont_comp_qd_ns = cont_comp_qd_iri * args["separator"]

        authorizer = wpd["isAuthorizedBy"]

        # delete existing descriptions

        # push!(operations, delete_description(qd_ns))
        # push!(operations, delete_description(qvd_ns))

        # create descriptions

        push!(operations, add_description(qd_ns, qd_prefix, args["path-base"]))
        push!(operations, add_description(qvd_ns, qvd_prefix, args["path-base"]))

        # add authorization annotations to descriptions

        push!(operations, add_authorization(qd_iri, authorizer))
        push!(operations, add_authorization(qvd_iri, authorizer))

        # add imports

        if wp != authorizer
            push!(operations, add_import(qvd_ns, cont_comp_qd_ns))
        end

        if length(wpd["authorizes"]) > 0

            # description for components

            cd_iri = args["namespace-base"] * "/" * wp * "/C"
            cd_ns = cd_iri * args["separator"]
            cd_prefix = wp * "_C"

            # description for work packages

            wpd_iri = args["namespace-base"] * "/" * wp * "/WP"
            wpd_ns = wpd_iri * args["separator"]
            wpd_prefix = wp * "_WP"

            # delete existing descriptions

            push!(operations, delete_description(cd_ns))
            push!(operations, delete_description(wpd_ns))

            # create descriptions

            push!(operations, add_description(cd_ns, cd_prefix, args["path-base"]))
            push!(operations, add_description(wpd_ns, wpd_prefix, args["path-base"]))

            # add authorization annotations to descriptions

            push!(operations, add_authorization(cd_iri, authorizer))
            push!(operations, add_authorization(wpd_iri, authorizer))

            # add imports

            push!(operations, add_import(wpd_ns, cd_ns))
            push!(operations, add_import(qd_ns, cd_ns))

            if wp != authorizer
                push!(operations, add_import(cd_ns, cont_comp_d_ns))
            end

            for (wp, comp) in wpd["authorizes"]

                # create work package

                push!(operations, create_instance(wpd_iri, wp))
                wp_iri = wpd_ns * String(wp)
                push!(operations, add_assertion(wpd_iri, wp_iri, RDF_TYPE, WORK_PACKAGE))
                push!(operations, add_assertion(wpd_iri, wp_iri, HAS_CANONICAL_NAME, wpd["hasName"][comp]))

                # create component

                push!(operations, create_instance(cd_iri, comp))
                comp_iri = cd_ns * String(comp)
                push!(operations, add_assertion(cd_iri, comp_iri, RDF_TYPE, COMPONENT))
                push!(operations, add_assertion(cd_iri, comp_iri, HAS_CANONICAL_NAME, wpd["hasName"][comp]))
                cont_comp_iri = cont_comp_d_ns * wpd["supplies"]
                if (cont_comp_iri != comp_iri)
                    push!(operations, add_assertion(cd_iri, comp_iri, IS_CONTAINED_IN, cont_comp_iri))
                end

                # add supplies relation from work package to component

                push!(operations, add_assertion(wpd_iri, wp_iri, SUPPLIES, comp_iri))

                # create mass property quantities

                for (quantity, kind) in quantity_map
                    q_name = comp * "_" * quantity
                    q_iri = qd_ns * String(q_name)
                    push!(operations, create_instance(qd_iri, q_name))
                    push!(operations, add_annotation(qd_iri, q_iri, RDFS_LABEL, quantity))
                    push!(operations, add_assertion(qd_iri, q_iri, RDF_TYPE, "http://studioj.us/metrology#$kind"))
                    push!(operations, add_assertion(qd_iri, q_iri, CHARACTERIZES, comp_iri))
                end

            end
        end

        if args["deferred"]
            push!(deferred, operations...)
            println("Deferred update for ", wp, " with ", length(operations), " operations")
        else
            t1 = time()
            update(server, operations)
            t2 = time()
            println("Updated server for ", wp, " ", length(operations), " operations in ", round(t2 - t1, digits=2), " s")
            sleep(1)
        end

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

    exit(0)
end

end # module
