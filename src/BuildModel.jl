module Main

using ArgParse
using JSON3
using HTTP

const RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
const RDFS_LABEL = "http://www.w3.org/2000/01/rdf-schema#label"
const DC_CREATOR = "http://purl.org/dc/elements/1.1/creator"
const DC_RIGHTS = "http://purl.org/dc/elements/1.1/rights"
const HAS_CANONICAL_NAME = "http://imce.jpl.nasa.gov/foundation/base#hasCanonicalName"
const CONTAINS = "http://imce.jpl.nasa.gov/foundation/base#contains"
const PRESENTS = "http://imce.jpl.nasa.gov/foundation/mission#presents"
const AUTHORIZES = "http://imce.jpl.nasa.gov/foundation/project#authorizes"
const CHARACTERIZES = "http://imce.jpl.nasa.gov/foundation/analysis#characterizes"
const WORK_PACKAGE = "http://imce.jpl.nasa.gov/foundation/project#WorkPackage"
const PROJECT = "http://imce.jpl.nasa.gov/foundation/project#Project"
const COMPONENT = "http://imce.jpl.nasa.gov/foundation/mission#Component"
const INTERFACE = "http://imce.jpl.nasa.gov/foundation/mission#Interface"
const SUPPLIES = "http://imce.jpl.nasa.gov/foundation/project#supplies"
const HAS_NUMBER = "<http://studioj.us/metrology#hasNumber>"
const HAS_UNIT = "<http://studioj.us/metrology#hasUnit>"
const HAS_POI_CONVENTION = "<http://studioj.us/metrology#hasPoiConvention>"
const IS_POINT_MASS = "<http://studioj.us/metrology#isPointMass>"
const HAS_COMPONENT_IDENTIFIER = "<http://studioj.us/base#hasComponentIdentifier>"
const HAS_WORK_PACKAGE_IDENTIFIER = "<http://studioj.us/base#hasWorkPackageIdentifier>"
const HAS_PROJECT_IDENTIFIER = "<http://studioj.us/base#hasProjectIdentifier>"
const HAS_QUANTITY_IDENTIFIER = "<http://studioj.us/metrology#hasQuantityIdentifier>"
const KG_UNIT = "<http://studioj.us/units#kg>"
const MM_UNIT = "<http://studioj.us/units#mm>"
const KG_MM_2_UNIT = "<http://studioj.us/units#kg_mm_2>"
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
        "--defer-diagnostics"
        help = "Defer diagnostics until the end (default: false)"
        action = :store_true
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

function description_iri_ns(base, path, separator)
    iri = base * replace("/$path", r"\/+" => "/")
    ns = iri * separator
    (iri, ns)
end

function instance_iri(namespace, name)
    namespace * String(name)
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

    # create description bundle

    (db_iri, db_ns) = description_iri_ns(args["namespace-base"], "bundle", args["separator"])
    db_prefix = "description-bundle"

    push!(deferred, add_description_bundle(db_ns, db_prefix, args["path-base"]))

    for (i, v) in enumerate(vl)
        if args["limit"] > 0 && i > args["limit"]
            println("Reached limit of ", args["limit"], " components. Stopping.")
            break
        end
        authority = String(v.first)
        authority_data = v.second

        operations = []

        authorizer = authority_data["isAuthorizedBy"]

        # parent iris and namespaces

        authorizing_iri_frag = args["namespace-base"] * "/" * authorizer

        if (is_supplier = haskey(authority_data, "supplies"))

            authorizing_iri = authorizing_iri_frag * "/WP/" * authority * args["separator"] * authority

            # supplied component details

            (supplied_comp_d_iri, supplied_comp_d_ns) = description_iri_ns(args["namespace-base"], "$authorizer/C/" * authority_data["supplies"], args["separator"])
            supplied_comp_iri = instance_iri(supplied_comp_d_ns, authority_data["supplies"])

            (supplied_comp_qd_iri, supplied_comp_qd_ns) = description_iri_ns(args["namespace-base"], "$authorizer/Q", args["separator"])

            (supplied_comp_qvd_iri, supplied_comp_qvd_ns) = description_iri_ns(args["namespace-base"], "$authority/QV", args["separator"])

        else

            # top=level project description

            (authorizing_d_iri, authorizing_d_ns) = description_iri_ns(args["namespace-base"], "$authorizer/P", args["separator"])
            authorizing_d_prefix = authority * "_P"

            authorizing_iri = instance_iri(authorizing_d_ns, authority)

            push!(operations, add_description(authorizing_d_ns, authorizing_d_prefix, args["path-base"]))
            push!(operations, create_instance(authorizing_d_iri, authority))
            push!(operations, add_assertion(authorizing_d_iri, authorizing_iri, RDF_TYPE, PROJECT))
            push!(operations, add_assertion(authorizing_d_iri, authorizing_iri, HAS_PROJECT_IDENTIFIER, authority))
            push!(operations, add_assertion(authorizing_d_iri, authorizing_iri, HAS_CANONICAL_NAME, authority_data["hasName"][authority]))
            push!(operations, add_assertion(authorizing_d_iri, authorizing_iri, HAS_SORT_KEY, "00"))
            push!(deferred, add_import(db_ns, authorizing_d_ns))
            
        end

        if length(authority_data["authorizes"]) > 0

            # description for components

            (sbsd_iri, sbsd_ns) = description_iri_ns(args["namespace-base"], "$authority/SBS", args["separator"])
            sbsd_prefix = authority * "_SBS"

            # description for work packages

            (wbsd_iri, wbsd_ns) = description_iri_ns(args["namespace-base"], "$authority/WBS", args["separator"])
            wbsd_prefix = authority * "_WBS"

            # create descriptions

            push!(operations, add_description(sbsd_ns, sbsd_prefix, args["path-base"]))
            push!(deferred, add_import(db_ns, sbsd_ns))
            push!(operations, add_description(wbsd_ns, wbsd_prefix, args["path-base"]))
            push!(deferred, add_import(db_ns, wbsd_ns))

            if is_supplier

                # create ref for "contains" assertions

                push!(operations, create_instance_ref(sbsd_iri, supplied_comp_iri))
            end

            # create ref for "authorizes" assertions

            push!(operations, create_instance_ref(wbsd_iri, authorizing_iri))

            for (wp, comp) in authority_data["authorizes"]

                # create work package description

                (child_wpd_iri, child_wpd_ns) = description_iri_ns(args["namespace-base"], "$authority/WP/$wp", args["separator"])
                child_wpd_prefix = wp
                push!(operations, add_description(child_wpd_ns, child_wpd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_wpd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_wpd_ns))

                # create work package

                push!(operations, create_instance(child_wpd_iri, wp))
                child_wp_iri = instance_iri(child_wpd_ns, wp)
                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, RDF_TYPE, WORK_PACKAGE))
                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, HAS_CANONICAL_NAME, authority_data["hasName"][comp]))
                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, HAS_WORK_PACKAGE_IDENTIFIER, wp))
                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, HAS_SORT_KEY, authority_data["hasSortKey"][comp]))
                push!(operations, add_assertion(wbsd_iri, authorizing_iri, AUTHORIZES, child_wp_iri))

                # add rights for authorized work package

                push!(operations, add_rights(child_wpd_iri, child_wp_iri))

                # create component description

                (child_cd_iri, child_cd_ns) = description_iri_ns(args["namespace-base"], "$authority/C/$comp", args["separator"])
                child_cd_prefix = comp
                push!(operations, add_description(child_cd_ns, child_cd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_cd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_cd_ns))

                # create component

                push!(operations, create_instance(child_cd_iri, comp))
                child_comp_iri = instance_iri(child_cd_ns, comp)
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, RDF_TYPE, COMPONENT))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_CANONICAL_NAME, authority_data["hasName"][comp]))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_COMPONENT_IDENTIFIER, comp))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_SORT_KEY, authority_data["hasSortKey"][comp]))
                if (is_supplier)
                    push!(operations, add_assertion(sbsd_iri, supplied_comp_iri, CONTAINS, child_comp_iri))
                end

                # add rights for authorized work package
                
                push!(operations, add_rights(child_cd_iri, child_wp_iri))

                # add supplies relation from work package to component

                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, SUPPLIES, child_comp_iri))

                # create interfaces

                for i in ("in", "out")
                    if_name = "IF.$(comp)_$i"
                    push!(operations, create_instance(child_cd_iri, if_name))
                    if_iri = instance_iri(child_cd_ns, if_name)
                    push!(operations, add_assertion(child_cd_iri, if_iri, RDF_TYPE, INTERFACE))
                    push!(operations, add_assertion(child_cd_iri, if_iri, HAS_COMPONENT_IDENTIFIER, if_name))
                    push!(operations, add_assertion(child_cd_iri, child_comp_iri, PRESENTS, if_iri))
                end

                # create items description

                (child_itd_iri, child_itd_ns) = description_iri_ns(args["namespace-base"], "$authority/IT/IT.$comp", args["separator"])
                child_itd_prefix = "IT.$comp"

                push!(operations, add_description(child_itd_ns, child_itd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_itd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_itd_ns))

                # add rights for items description
                
                push!(operations, add_rights(child_itd_iri, child_wp_iri))

                # create mass property quantities

                for (quantity, kind) in quantity_map
                    q_name = comp * "_" * quantity
                    q_iri = instance_iri(child_cd_ns, q_name)
                    push!(operations, create_instance(child_cd_iri, q_name))
                    push!(operations, add_annotation(child_cd_iri, q_iri, RDFS_LABEL, quantity))
                    push!(operations, add_assertion(child_cd_iri, q_iri, HAS_QUANTITY_IDENTIFIER, q_name))
                    push!(operations, add_assertion(child_cd_iri, q_iri, RDF_TYPE, "http://studioj.us/metrology#$kind"))
                    push!(operations, add_assertion(child_cd_iri, q_iri, CHARACTERIZES, child_comp_iri))
                end

                # create quantity value description for child workpackage

                (child_qvd_iri, child_qvd_ns) = description_iri_ns(args["namespace-base"], "$wp/QV", args["separator"])
                child_qvd_prefix = String(wp) * "_QV"
                push!(operations, add_description(child_qvd_ns, child_qvd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_qvd_iri, child_wp_iri))
                push!(deferred, add_rights(child_qvd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_qvd_ns))

            end

            # add authorization annotations to descriptions

            push!(operations, add_authorization(sbsd_iri, authorizing_iri))
            push!(operations, add_authorization(wbsd_iri, authorizing_iri))

        end

        if is_supplier

            # add quantity values

            for (quantity, kind) in quantity_map
                q_name = authority_data["supplies"] * "_" * quantity
                qv_name = q_name * "_value"
                q_iri = instance_iri(supplied_comp_d_ns, q_name)
                qv_iri = instance_iri(supplied_comp_qvd_ns, qv_name)
                qtype = replace(kind, "Quantity" => "Value")
                push!(operations, create_instance(supplied_comp_qvd_iri, qv_name))
                push!(operations, add_annotation(supplied_comp_qvd_iri, qv_iri, RDFS_LABEL, quantity))
                push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, RDF_TYPE, "http://studioj.us/metrology#$qtype"))
                push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, CHARACTERIZES, q_iri))

                if haskey(authority_data, "hasValues") && haskey(authority_data["hasValues"], quantity)
                    value = parse(Float64, authority_data["hasValues"][quantity])
                    push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => value)))
                    push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, HAS_UNIT, unit_map[kind]))
                end
            end

            # add related property values

            push!(operations, create_instance_ref(supplied_comp_qvd_iri, supplied_comp_iri))
            push!(operations, add_assertion(supplied_comp_qvd_iri, supplied_comp_iri, HAS_POI_CONVENTION, authority_data["hasPOIconv"]))
            push!(operations, add_assertion(supplied_comp_qvd_iri, supplied_comp_iri, IS_POINT_MASS, authority_data["isPointMass"]))

        end

        # update server
        
        t1 = time()
        update(server, operations, args["defer-diagnostics"])
        t2 = time()
        println("Updated server for ", authority, " (", i, ") ", length(operations), " operations in ", round(t2 - t1, digits=2), " s")

    end

    t1 = time()
    update(server, deferred, args["defer-diagnostics"])
    t2 = time()
    println("Updated server for description bundle with ", length(deferred), " operations in ", round(t2 - t1, digits=2), " s")
    end_time = time()
    println("finished in ", round(end_time - start_time, digits=2), " s")

    exit(0)
end

end # module
