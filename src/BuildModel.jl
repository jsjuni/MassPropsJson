module Main

using ArgParse
using JSON3
using OrderedCollections
using Logging
using OMLCodeAPI

const RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
const RDFS_LABEL = "http://www.w3.org/2000/01/rdf-schema#label"
const DC_CREATOR = "http://purl.org/dc/elements/1.1/creator"
const DC_RIGHTS = "http://purl.org/dc/elements/1.1/rights"
const HAS_CANONICAL_NAME = "http://imce.jpl.nasa.gov/foundation/base#hasCanonicalName"
const CONTAINS = "http://imce.jpl.nasa.gov/foundation/base#contains"
const PRESENTS = "http://imce.jpl.nasa.gov/foundation/mission#presents"
const AUTHORIZES = "http://imce.jpl.nasa.gov/foundation/project#authorizes"
const WORK_PACKAGE = "http://imce.jpl.nasa.gov/foundation/project#WorkPackage"
const PROJECT = "http://imce.jpl.nasa.gov/foundation/project#Project"
const COMPONENT = "http://imce.jpl.nasa.gov/foundation/mission#Component"
const ITEM = "http://imce.jpl.nasa.gov/foundation/mission#Item"
const INTERFACE = "http://imce.jpl.nasa.gov/foundation/mission#Interface"
const JUNCTION = "http://imce.jpl.nasa.gov/foundation/mission#Junction"
const SUPPLIES = "http://imce.jpl.nasa.gov/foundation/project#supplies"
const HAS_NUMBER = "http://bipm.org/jcgm/vim3-v#hasNumber"
const HAS_POI_CONVENTION = "http://studioj.us/mass-properties-v#hasPoiConvention>"
const IS_POINT_MASS = "http://studioj.us/mass-properties-v#isPointMass"
const HAS_COMPONENT_IDENTIFIER = "http://studioj.us/base#hasComponentIdentifier"
const HAS_INTERFACE_IDENTIFIER = "http://studioj.us/base#hasInterfaceIdentifier"
const HAS_JUNCTION_IDENTIFIER = "http://studioj.us/base#hasJunctionIdentifier"
const HAS_ITEM_IDENTIFIER = "http://studioj.us/base#hasItemIdentifier"
const HAS_WORK_PACKAGE_IDENTIFIER = "http://studioj.us/base#hasWorkPackageIdentifier"
const HAS_PROJECT_IDENTIFIER = "http://studioj.us/base#hasProjectIdentifier"
const HAS_QUANTITY_IDENTIFIER = "http://bipm.org/jcgm/vim3-v#hasQuantityIdentifier"
const KG_UNIT = "http://iso.org/iso-80000/4.1-d#kilogram"
const METRE_UNIT = "http://iso.org/iso-80000/3.1-d#metre"
const KG_METRE_SQUARED_UNIT = "http://iso.org/iso-80000/4.7-d#kilogram_metre_squared"
const HAS_SORT_KEY = "<http://imce.jpl.nasa.gov/foundation/base#hasSortKey>"
const TRANSFERS_IN = "http://imce.jpl.nasa.gov/foundation/mission#transfersIn"
const TRANSFERS_OUT = "http://imce.jpl.nasa.gov/foundation/mission#transfersOut"
const TRAVERSES = "http://imce.jpl.nasa.gov/foundation/mission#traverses"
const HAS_IDENTIFIER = "http://imce.jpl.nasa.gov/foundation/base#hasIdentifier"
const JOINS1 = "http://imce.jpl.nasa.gov/foundation/mission#joins1"
const JOINS2 = "http://imce.jpl.nasa.gov/foundation/mission#joins2"
const STUDIOJ_BUNDLE_D = "http://studioj.us/bundle-d#"
const STUDIOJ_BUNDLE_V = "http://studioj.us/bundle-v#"
const IS_PROPERTY_OF = "http://bipm.org/jcgm/vim3-v#isPropertyOf"
const IS_MASS_OF = "http://studioj.us/mass-properties-v#isMassOf"
const IS_CENTER_OF_MASS_COORDINATE_OF = "http://studioj.us/mass-properties-v#isCenterOfMassCoordinateOf"
const IS_MOMENT_OF_INERTIA_OF = "http://studioj.us/mass-properties-v#isMomentOfInertiaOf"
const IS_PRODUCT_OF_INERTIA_OF = "http://studioj.us/mass-properties-v#isProductOfInertiaOf"
const EXPRESSES_MAGNITUDE_OF = "http://bipm.org/jcgm/vim3-v#expressesMagnitudeOf"
const HAS_REFERENCE = "http://bipm.org/jcgm/vim3-v#hasReference"

const MULTI_LEVEL = Dict(
    "C.1.2.2" => Dict(
        "C.1.2.2.A" => ["C.1.2.2.1", "C.1.2.2.2"],
        "C.1.2.2.B" => ["C.1.2.2.3", "C.1.2.2.4", "C.1.2.2.5"]
    )
)

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
        "--multi-level"
            help = "Multi-level SBS"
            action = :store_true
    end
    return parse_args(s)
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

function add_authorization(iri, authorizer)
    add_annotation(iri, iri, DC_CREATOR, Dict("datatypeIri" => "http://www.w3.org/2001/XMLSchema#anyURI", "value" => authorizer))
end

function add_rights(iri, grantee)
    add_annotation(iri, iri, DC_RIGHTS, Dict("datatypeIri" => "http://www.w3.org/2001/XMLSchema#anyURI", "value" => grantee))
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

    quantity_map = OrderedDict(
        "mass" => "Mass",
        "Cx" => "CenterOfMassCoordinate",
        "Cy" => "CenterOfMassCoordinate",
        "Cz" => "CenterOfMassCoordinate",
        "Ixx" => "MomentOfInertia",
        "Iyy" => "MomentOfInertia",
        "Izz" => "MomentOfInertia",
        "Ixy" => "ProductOfInertia",
        "Ixz" => "ProductOfInertia",
        "Iyz" => "ProductOfInertia",
        "sigma_mass" => "Mass",
        "sigma_Cx" => "CenterOfMassCoordinate",
        "sigma_Cy" => "CenterOfMassCoordinate",
        "sigma_Cz" => "CenterOfMassCoordinate",
        "sigma_Ixx" => "MomentOfInertia",
        "sigma_Iyy" => "MomentOfInertia",
        "sigma_Izz" => "MomentOfInertia",
        "sigma_Ixy" => "ProductOfInertia",
        "sigma_Ixz" => "ProductOfInertia",
        "sigma_Iyz" => "ProductOfInertia"
    )

    is_property_map = Dict(
        "Mass" => IS_MASS_OF,
        "CenterOfMassCoordinate" => IS_CENTER_OF_MASS_COORDINATE_OF,
        "MomentOfInertia" => IS_MOMENT_OF_INERTIA_OF,
        "ProductOfInertia" => IS_PRODUCT_OF_INERTIA_OF
    )

    unit_map = Dict(
        "Mass" => KG_UNIT,
        "CenterOfMassCoordinate" => METRE_UNIT,
        "MomentOfInertia" => KG_METRE_SQUARED_UNIT,
        "ProductOfInertia" => KG_METRE_SQUARED_UNIT
    )

    scale_map = Dict(
        "Mass" => 1.0,
        "CenterOfMassCoordinate" => 1.0e-3,
        "MomentOfInertia" => 1.0e-6,
        "ProductOfInertia" => 1.0e-6
    )

    args = parse_commandline()

    start_time = time()

    vl = JSON3.read(args["input"])

    server = args["server"]

    if !is_alive(server)
        @info "Server is not alive at " args["server"]
        exit(1)
    end

    deferred = []

    multi_level_parent = Dict()
    for (s, sh) in MULTI_LEVEL
        multi_level_parent[s] = d = Dict()
        for (p, cl) in sh
            for c in cl
                d[c] = p
            end
        end
    end

    # create description bundle

    (db_iri, db_ns) = description_iri_ns(args["namespace-base"], "bundle", args["separator"])
    db_prefix = "description-bundle"

    push!(deferred, add_description_bundle(db_ns, db_prefix, args["path-base"]))
    push!(deferred, add_import(db_ns, STUDIOJ_BUNDLE_V))
    push!(deferred, add_import(db_ns, STUDIOJ_BUNDLE_D))

    for (i, v) in enumerate(vl)
        if args["limit"] > 0 && i > args["limit"]
            @info "Reached limit of $(args["limit"]) components. Stopping."
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

            supplied_comp = authority_data["supplies"]
            (supplied_comp_d_iri, supplied_comp_d_ns) = description_iri_ns(args["namespace-base"], "$authorizer/C/" * supplied_comp, args["separator"])
            supplied_comp_iri = instance_iri(supplied_comp_d_ns, supplied_comp)

            (supplied_comp_qd_iri, supplied_comp_qd_ns) = description_iri_ns(args["namespace-base"], "$authorizer/Q/" * supplied_comp, args["separator"])
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
            push!(operations, add_authorization(authorizing_d_iri, authorizing_iri))
            push!(deferred, add_import(db_ns, authorizing_d_ns))
            
        end

        if length(authority_data["authorizes"]) > 0

            # description for system breakdown structure

            (sbsd_iri, sbsd_ns) = description_iri_ns(args["namespace-base"], "$authority/SBS", args["separator"])
            sbsd_prefix = authority * "_SBS"

            # description for work breakdown structure

            (wbsd_iri, wbsd_ns) = description_iri_ns(args["namespace-base"], "$authority/WBS", args["separator"])
            wbsd_prefix = authority * "_WBS"

            # description for system interconnect structure

            (sisd_iri, sisd_ns) = description_iri_ns(args["namespace-base"], "$authority/SIS", args["separator"])
            sisd_prefix = authority * "_SIS"

            # create descriptions

            push!(operations, add_description(sbsd_ns, sbsd_prefix, args["path-base"]))
            push!(deferred, add_import(db_ns, sbsd_ns))
            push!(operations, add_description(wbsd_ns, wbsd_prefix, args["path-base"]))
            push!(deferred, add_import(db_ns, wbsd_ns))
            push!(operations, add_description(sisd_ns, sisd_prefix, args["path-base"]))
            push!(deferred, add_import(db_ns, sisd_ns))

           # add authorization annotations to descriptions

            push!(operations, add_authorization(sbsd_iri, authorizing_iri))
            push!(operations, add_authorization(wbsd_iri, authorizing_iri))
            push!(operations, add_authorization(sisd_iri, authorizing_iri))
            
            if is_supplier

                # create ref for "contains" assertions

                push!(operations, create_instance_ref(sbsd_iri, supplied_comp_iri))

                # apply multi-level elaboration if requested

                if args["multi-level"] && haskey(MULTI_LEVEL, supplied_comp)
                    for sub in ["A", "B"]
                        sub_comp = "$supplied_comp.$sub"
                        push!(operations, create_instance(sbsd_iri, sub_comp))
                        sub_comp_iri = instance_iri(sbsd_ns, sub_comp)
                        push!(operations, add_assertion(sbsd_iri, sub_comp_iri, RDF_TYPE, COMPONENT))
                        push!(operations, add_assertion(sbsd_iri, sub_comp_iri, HAS_COMPONENT_IDENTIFIER, sub_comp))
                        push!(operations, add_assertion(sbsd_iri, sub_comp_iri, HAS_CANONICAL_NAME, sub_comp))
                        push!(operations, add_assertion(sbsd_iri, supplied_comp_iri, CONTAINS, sub_comp_iri))
                    end
                end
        
            end

            # create ref for "authorizes" assertions

            push!(operations, create_instance_ref(wbsd_iri, authorizing_iri))

            # create items descriptions

            for item in authority_data["items"]
                (child_itd_iri, child_itd_ns) = description_iri_ns(args["namespace-base"], "$authority/IT/$item", args["separator"])
                child_itd_prefix = "$item"

                push!(operations, add_description(child_itd_ns, child_itd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_itd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_itd_ns))

                # add item

                item_iri = instance_iri(child_itd_ns, item)
                push!(operations, create_instance(child_itd_iri, item))
                push!(operations, add_assertion(child_itd_iri, item_iri, RDF_TYPE, ITEM))
                push!(operations, add_assertion(child_itd_iri, item_iri, HAS_ITEM_IDENTIFIER, item))
            end
            
            iri_from_name = Dict{String, String}()

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
                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, HAS_SORT_KEY, authority_data["hasSortKey"][wp]))
                push!(operations, add_assertion(wbsd_iri, authorizing_iri, AUTHORIZES, child_wp_iri))

                # add rights for authorized work package

                push!(operations, add_rights(child_wpd_iri, child_wp_iri))

                # create component description

                (child_cd_iri, child_cd_ns) = description_iri_ns(args["namespace-base"], "$authority/C/$comp", args["separator"])
                child_cd_prefix = comp
                push!(operations, add_description(child_cd_ns, child_cd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_cd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_cd_ns))

                # add rights for authorized work package
                
                push!(operations, add_rights(child_cd_iri, child_wp_iri))

                # create component

                push!(operations, create_instance(child_cd_iri, comp))
                child_comp_iri = instance_iri(child_cd_ns, comp)
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, RDF_TYPE, COMPONENT))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_CANONICAL_NAME, authority_data["hasName"][comp]))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_COMPONENT_IDENTIFIER, comp))
                push!(operations, add_assertion(child_cd_iri, child_comp_iri, HAS_SORT_KEY, authority_data["hasSortKey"][comp]))
                if (is_supplier)
                    if args["multi-level"] && haskey(MULTI_LEVEL, supplied_comp)
                        parent_comp = multi_level_parent[supplied_comp][comp]
                        parent_comp_iri = instance_iri(sbsd_ns, parent_comp)
                    else
                        parent_comp_iri = supplied_comp_iri
                    end
                    push!(operations, add_assertion(sbsd_iri, parent_comp_iri, CONTAINS, child_comp_iri))
                end

                 # add supplies relation from work package to component

                push!(operations, add_assertion(child_wpd_iri, child_wp_iri, SUPPLIES, child_comp_iri))

                # create interface description

                (child_ifd_iri, child_ifd_ns) = description_iri_ns(args["namespace-base"], "$authority/IF/$comp", args["separator"])
                child_ifd_prefix = "$(comp)_IF"
                push!(operations, add_description(child_ifd_ns, child_ifd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_ifd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_ifd_ns))

                # add rights for authorized work package
                
                push!(operations, add_rights(child_ifd_iri, child_wp_iri))

                # create interfaces

                push!(operations, create_instance_ref(child_ifd_ns, child_comp_iri))
                for i in ("in", "out")
                    if_name = "IF.$(comp)_$i"
                    push!(operations, create_instance(child_ifd_iri, if_name))
                    if_iri = instance_iri(child_ifd_ns, if_name)
                    push!(operations, add_assertion(child_ifd_iri, if_iri, RDF_TYPE, INTERFACE))
                    push!(operations, add_assertion(child_ifd_iri, if_iri, HAS_INTERFACE_IDENTIFIER, if_name))
                    push!(operations, add_assertion(child_ifd_iri, child_comp_iri, PRESENTS, if_iri))
                    item = authority_data["transfers"][comp][i]
                    transfers = i == "in" ? TRANSFERS_IN : TRANSFERS_OUT
                    it_name = item in authority_data["items"] ? "$authority/IT/$item" : "$authorizer/IT/$item"
                    (child_itd_iri, child_itd_ns) = description_iri_ns(args["namespace-base"], it_name, args["separator"])
                    item_iri = instance_iri(child_itd_ns, item)
                    push!(operations, add_assertion(child_ifd_iri, if_iri, transfers, item_iri))
                    if item in authority_data["items"]
                        push!(operations, add_rights(child_itd_iri, child_wp_iri))
                    end
                    iri_from_name[if_name] = if_iri
                    iri_from_name[item] = item_iri
                 end

                # create quantities description

                (child_qd_iri, child_qd_ns) = description_iri_ns(args["namespace-base"], "$authority/Q/$comp", args["separator"])
                child_qd_prefix = "$(comp)_Q"
                push!(operations, add_description(child_qd_ns, child_qd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_qd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_qd_ns))

                # add rights for authorized work package
                
                push!(operations, add_rights(child_qd_iri, child_wp_iri))

                # create mass property quantities

                for (quantity, kind) in quantity_map
                    q_name = comp * "_" * quantity
                    q_iri = instance_iri(child_qd_ns, q_name)
                    is_property_of = is_property_map[kind]
                    push!(operations, create_instance(child_qd_iri, q_name))
                    push!(operations, add_annotation(child_qd_iri, q_iri, RDFS_LABEL, quantity))
                    push!(operations, add_assertion(child_qd_iri, q_iri, HAS_QUANTITY_IDENTIFIER, q_name))
                    push!(operations, add_assertion(child_qd_iri, q_iri, RDF_TYPE, "http://studioj.us/mass-properties-v#$kind"))
                    push!(operations, add_assertion(child_qd_iri, q_iri, is_property_of, child_comp_iri))
                end

                # create quantity value description for child work package

                (child_qvd_iri, child_qvd_ns) = description_iri_ns(args["namespace-base"], "$wp/QV", args["separator"])
                child_qvd_prefix = String(wp) * "_QV"
                push!(operations, add_description(child_qvd_ns, child_qvd_prefix, args["path-base"]))
                push!(operations, add_authorization(child_qvd_iri, child_wp_iri))
                push!(deferred, add_rights(child_qvd_iri, authorizing_iri))
                push!(deferred, add_import(db_ns, child_qvd_ns))

            end

            # add junctions to system interconnection structure

            for (j_name, jh) in authority_data["junctions"]
                push!(operations, create_instance(sisd_iri, j_name))
                j_iri = instance_iri(sisd_ns, j_name)
                push!(operations, add_assertion(sisd_iri, j_iri, HAS_JUNCTION_IDENTIFIER, j_name))
                push!(operations, add_assertion(sisd_iri, j_iri, RDF_TYPE, JUNCTION))
                for (n, if_name) in jh
                    if_iri = iri_from_name[if_name]
                    joins = Dict("1" => JOINS1, "2" => JOINS2)[string(n)]
                    push!(operations, add_assertion(sisd_iri, j_iri, joins, if_iri))
                end
                it_name = replace(jh["1"], r"^IF" => "IT")
                it_iri = iri_from_name[it_name]
                push!(operations, create_instance_ref(sisd_ns, it_iri))
                push!(operations, add_assertion(sisd_iri, it_iri, TRAVERSES, j_iri))
            end

         end

        if is_supplier

            # add quantity values

            for (quantity, kind) in quantity_map
                q_name = supplied_comp * "_" * quantity
                qv_name = q_name * "_value"
                q_iri = instance_iri(supplied_comp_qd_ns, q_name)
                qv_iri = instance_iri(supplied_comp_qvd_ns, qv_name)
                qtype = "$(kind)Value"
                push!(operations, create_instance(supplied_comp_qvd_iri, qv_name))
                push!(operations, add_annotation(supplied_comp_qvd_iri, qv_iri, RDFS_LABEL, quantity))
                push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, RDF_TYPE, "http://studioj.us/mass-properties-v#$qtype"))
                push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, EXPRESSES_MAGNITUDE_OF, q_iri))

                if haskey(authority_data, "hasValues") && haskey(authority_data["hasValues"], quantity)
                    value = parse(Float64, authority_data["hasValues"][quantity]) * scale_map[kind]
                    push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, HAS_NUMBER, Dict("\$type" => "DoubleLiteral", "value" => value)))
                    push!(operations, add_assertion(supplied_comp_qvd_iri, qv_iri, HAS_REFERENCE, unit_map[kind]))
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
        @info "Updated server for $authority ($i): $(length(operations)) in operations in $(round(t2 - t1, digits=2)) s"

    end

    t1 = time()
    update(server, deferred, args["defer-diagnostics"])
    t2 = time()
    @info "Updated server for description bundle: $(length(deferred)) operations in $(round(t2 - t1, digits=2)) s"
    end_time = time()
    @info "finished in $(round(end_time - start_time, digits=2)) s"

    exit(0)
end

end # module
