# DESC: test if GN export_oo.cor_etude_module_dataset exists
#       and if id_dataset are not NULL
# ARGS: NONE
# OUTS: 0 if true
function test_jdd() {

    log SQL "Test JDD"
        
    if ! table_exists ${db_gn_name} export_oo cor_dataset; then
        log SQL "La table GN export_oo cor_dataset n existe pas"
        exitScript 'La table GN export_oo cor_dataset n existe pas' 2
    fi

    export PGPASSWORD=${user_pg_pass};\
        res_pe=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} -c "\
            SELECT libelle_protocole, nom_etude, nom_structure,\
                nb_protocole, nb_protocole_etude, nb_protocole_etude_structure \
                FROM export_oo.cor_dataset WHERE id_dataset IS NULL \
                ORDER BY nb_protocole DESC, nb_protocole_etude DESC, nb_protocole_etude_structure DESC \
                ")

        res_ep=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} -c "\
            SELECT nom_etude, libelle_protocole, nom_structure,\
                nb_etude, nb_protocole_etude, nb_protocole_etude_structure \
                FROM export_oo.cor_dataset WHERE id_dataset IS NULL \
                ORDER BY nb_etude DESC, nb_protocole_etude DESC, nb_protocole_etude_structure DESC \
                ")

    if [ "${cadre_aquisition}" = "etude" ] ; then 
        res=$res_ep
    else
        res=$res_pe
        ca_name="Protocole"; jdd_name="Etude"
    fi

    if [ -n "$res" ] ; then

        print_format="%-50s %10s     %-50s %10s     %-50s %10s" 
        echo "Dans la table export_oo.cor_dataset, il n y a pas de JDD associé pour les lignes suivantes"
        echo        
        echo $res | sed -e "s/;/\n/g" -e "s/|/\t/g" \
            | awk -F $'\t' '
            BEGIN { 
                protcole="";
                etude="";
                printf "'"${print_format}"'\n","'${ca_name}'", "", "'${jdd_name}'", "", "Organisme", ""
            }
            {
                if ( $1!=protocole ) {
                    printf "\n'"${print_format}"'\n",$1, $4, $2, $5, $3, $6 ;
                    protocole=$1;
                    etude=$2;
                    n_structure=0
                }
                else if ( $2!=etude ) {
                    if (n_structure != 0) {
                        printf "'"${print_format}"'\n","", "", "", "", "-", "";
                    };
                    printf "'"${print_format}"'\n","", "", $2, $5, $3, $6;
                    etude=$2;
                    n_structure=0
                }
                else {
                    printf "'"${print_format}"'\n", "", "", "", "", $3, $6
                    n_structure=1
                };

            }
            END {
                printf "\n"
            }
            '
        exitScript "Veuillez completer la table export_oo.cor_dataset avant de continuer" 2 
        return 1
    fi

    return 0
}

test_geometry() {

    log SQL "Test geometrie"

    export PGPASSWORD=${user_pg_pass};\
    res=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} \
     -c "SELECT COUNT(*) 
     FROM export_oo.saisie_observation s 
     WHERE NOT ST_ISVALID(geometrie)" 
    )

    if [ ! "$res" = "0" ] ; then
        exitScript "Il y a ${res} lignes avec une géométrie invalide dans les observations ObsOcc.\n
Veuillez corriger ces geométries (ou bien relancer le script avec l'option -c" 1
    fi

}


test_taxonomy() {

    log SQL "Test taxonomie"

    export PGPASSWORD=${user_pg_pass};\
    res=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} \
     -c "SELECT DISTINCT o.cd_nom, o.nom_complet 
     FROM export_oo.saisie_observation o 
     LEFT JOIN taxonomie.taxref t ON t.cd_nom = o.cd_nom
     LEFT JOIN export_oo.t_taxonomie_synonymes s ON s.cd_nom_invalid = o.cd_nom 
     WHERE t.cd_nom IS NULL AND s.cd_nom_valid IS NULL")

    if [ -n "${res}" ] ; then
        pretty_res=$(echo $res | sed -e "s/;/\n/g" -e "s/|/\t/g" | awk -F $'\t' '{printf "%-15s %s\n", $1, $2}')
        exitScript "Dans la table saisie.observation, il y a des lignes avec le champ 'cd_nom' sans correspondance dans TaxRef\n\n${pretty_res} \n 
Veuillez au choix:
    - les corriger dans la base départ
    - compléter le fichier data/csv/taxonomie_custom.csv
    - les ignorer et relancer le script avec l'option -p TAX (pour ne pas en tenir compte) 
" 2
    fi
}


test_date() {
    log SQL "Test date"

    export PGPASSWORD=${user_pg_pass};\
    res=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} \
     -c "SELECT id_obs 
     FROM export_oo.saisie_observation s 
     WHERE date_min IS NULL or date_max IS NULL OR date_max < date_min"
    )

    if [ -n "$res" ] ; then
        exitScript "Il y a des lignes avec des dates non définis dans la table 'export_oo.saisie_observation'.\n\n ${res}\n
Voir le fichier data.export_oo/oo_data.sql." 1
    fi
}


test_effectif() {
    log SQL "Test effectif"

    export PGPASSWORD=${user_pg_pass};\
    res=$(psql -tA -R";" -h ${db_host}  -p ${db_port} -U ${user_pg} -d ${db_gn_name} \
     -c "SELECT id_obs , effectif_min, effectif_max
     FROM export_oo.saisie_observation s 
     WHERE effectif_min > effectif_max"
    )
           if [ -n "$res" ] ; then
pretty_res=$(echo $res | sed -e "s/;/\n/g" -e "s/|/\t/g" | awk -F $'\t' '
    BEGIN {
        printf "%20s %20s %20s\n\n", "id_obs", "effectif_min", "effectif_max";
    } {
        printf "%20s %20s %20s\n", $1, $2, $3
    }')
        exitScript "Il y a des lignes avec des effectifs_min > effectif_max dans la table 'export_oo.saisie_observation'.
        \n${pretty_res}\n
Veuillez corriger ces geométries (ou bien relancer le script avec l'option -c" 1
    fi
}