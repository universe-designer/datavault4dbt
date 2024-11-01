{#
    This macro creates an effectivity satellite version 0 for a link entity, based on the stage data. It can handle multiple loads and
    is therefor ready for both initial loads on persistent staging areas, and incremental loads on transient staging areas.
    This version is the 0 version, because it does not include virtualized effectivity time ranges. For that you should create
    one version 1 effectivity satellite for each version 0 effectivity satellite using the eff_sat_link_v1 macro.
    This version is meant specially for views that can be used to load tables in one on one mappings. The code is identical with the
    incremental materialization.

    Features:
        - Calculates an 'is_active' flag, based on the assumption that only one relationship per driving key can be active at the same time
        - Delivers the base to calculate effectivity ranges in the version 1 effectivity satellite
        - Supports multiple updates per batch and therefor initial loading
        - Using a dynamic high-water-mark to optimize loading performance of multiple loads
        - Allows the driving key to hold mutliple keys of a relationship

    Parameters:

    link_hashkey::string                        Name of the hashkey column inside the stage, that represents the primary key of the link.

                                                Examples:
                                                    'hk_account_contact_l'  This hashkey belongs to the link between account and contact and
                                                                            was calculated before in the staging area by the stage macro.

    driving_key::string | list of strings       Name(s) of the driving key column(s) inside staging model. Based on this column one active row
                                                per ldts is set.

                                                Examples:
                                                    'hk_account_h'                      With this configuration, inside the link an account
                                                                                        is always only connected to one contact at a time.

                                                    ['hk_account_h', 'hk_contact_h']    Now the combination of the account hashkey and the
                                                                                        contact hashkey would be used as a driving key. Therefor
                                                                                        for each combination of account and contact, only one
                                                                                        relationship to other objects exists.

    secondary_fks::string | list of strings     Name(s) of all other foreign keys inside the link, called secondary foreign keys. A link ´
                                                that connects two hubs usually has one driving key and one secondary foreign key. All foreign keys
                                                inside a link are either the driving key, or a secondary foreign key.

                                                Examples:
                                                    'hk_contact_h'                          Contact is the secondary foreign key in the link. That indicates
                                                                                            that multiple accounts could be connected to the same contacts.

                                                    ['hk_contact_h', 'hk_opportunity_h']    The link now connects three objects, out of them contact and
                                                                                            opporunity are the secondary foreign objects.

    source_model::string                        Name of the source model that is available inside dbt. Usually this would be a staging model
                                                that was created via the stage macro.

                                                Examples:
                                                    'stage_account'         The effectivity satellite is based on the staging model for account.

    src_ldts::string                            Name of the ldts column inside the source models. Is optional, will use the global variable 'datavault4dbt.ldts_alias'.
                                                Needs to use the same column name as defined as alias inside the staging model.

    src_rsrc::string                            Name of the rsrc column inside the source models. Is optional, will use the global variable 'datavault4dbt.rsrc_alias'.
                                                Needs to use the same column name as defined as alias inside the staging model.

#}

{%- macro eff_sat_link_v0_view(link_hashkey, driving_key, secondary_fks, source_model, src_ldts=none, src_rsrc=none) -%}

    {# Applying the default aliases as stored inside the global variables, if src_ldts and src_rsrc are not set. #}

    {%- set src_ldts = datavault4dbt.replace_standard(src_ldts, 'datavault4dbt.ldts_alias', 'ldts') -%}
    {%- set src_rsrc = datavault4dbt.replace_standard(src_rsrc, 'datavault4dbt.rsrc_alias', 'rsrc') -%}

    {{ adapter.dispatch('eff_sat_link_v0_view', 'datavault4dbt')(link_hashkey=link_hashkey,
                                                                    driving_key=driving_key,
                                                                    secondary_fks=secondary_fks,
                                                                    src_ldts=src_ldts,
                                                                    src_rsrc=src_rsrc,
                                                                    source_model=source_model) }}

{%- endmacro -%}
