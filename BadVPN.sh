#!/bin/bash
# -*- coding: utf-8 -*-
# BadVPN PRO: Force BadVPN valdymo sprendimas su išplėstomis funkcijomis 

# Nustatome UTF-8 kodavimą
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# --- Globalūs kintamieji ---
readonly SKRIPTO_VERS="PRO v1.0"
readonly GITHUB_URL="https://raw.githubusercontent.com/ForceGROUP/BadVPN-PRO/main/BadVPN.sh"
readonly SCRIPT_PATH="$HOME/.local/bin/badvpn-pro"

# Priklausomybės kompiliavimui
readonly BUILD_DEPS="cmake build-essential g++ make screen wget"

# Keliai ir pavadinimai BadVPN
readonly BADVPN_SRC_DIR="$HOME/badvpn-force"
readonly BADVPN_TAR_URL="https://github.com/ForceGROUP/BadVPN-PRO/raw/main/badvpn-1.999.128.tar.bz2"
readonly BADVPN_TAR_FILE="$HOME/badvpn-1.999.128.tar.bz2"
readonly BADVPN_BIN_PATH="/usr/local/bin/badvpn-udpgw"

# Systemd tarnybos konfigūracija
readonly SERVICE_NAME="badvpn-udpgw.service"
readonly SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# --- Spalvos ir stiliai ---
readonly ŽALIA='\033[0;32m'       # Žalia spalva
readonly MĖLYNA='\033[0;34m'      # Mėlyna spalva
readonly GELTONA='\033[0;33m'     # Geltona spalva
readonly RAUDONA='\033[0;31m'     # Raudona spalva
readonly ŽYDRA='\033[0;36m'       # Žydra spalva
readonly PARYŠKINTAS='\033[1m'    # Paryškintas tekstas
readonly ATSTATYTI='\033[0m'      # Spalvos atstatymas

# --- Pagalbinės funkcijos ---
informacija() { echo -e "${MĖLYNA}ℹ ${*}${ATSTATYTI}"; }
pavyko() { echo -e "${ŽALIA}✔ ${*}${ATSTATYTI}"; }
įspėjimas() { echo -e "${GELTONA}⚠ ${*}${ATSTATYTI}"; }
klaida() { echo -e "${RAUDONA}✖ ${*}${ATSTATYTI}"; }

run_as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@";
    else
        sudo "$@";
    fi
}

spausti_enter_tęsti() {
    echo -e "\n${ŽYDRA}Paspauskite [Enter] tęsimui...${ATSTATYTI}"
    read -r
}

# --- Pagrindinės logikos funkcijos ---

# Patikrina, ar BadVPN sukompiliuotas ir įdiegtas
ar_badvpn_įdiegtas() {
    command -v badvpn-udpgw >/dev/null 2>&1
}

# Gauna aktyvius BadVPN portus
gauti_aktyvius_portus() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl cat "$SERVICE_NAME" 2>/dev/null | grep "ExecStart=" | sed 's/.*ExecStart=//' | grep -oE ':[0-9]+' | sed 's/://' | tr '\n' ' ' | sed 's/ $//'
    fi
}

# Kompiliuoja ir diegia BadVPN iš šaltinio kodo
įdiegti_badvpn() {
    if ar_badvpn_įdiegtas; then
        įspėjimas "BadVPN jau įdiegtas."
        informacija "Jei norite pereinstaliuoti, pirmiausia pašalinkite (5 pasirinkimas)."
        return 1
    fi

    informacija "1 žingsnis: Diegiamos kompiliavimo priklausomybės..."
    run_as_root apt-get update
    run_as_root apt-get install -y $BUILD_DEPS
    
    informacija "2 žingsnis: Atsisiunčiamas BadVPN šaltinio kodas..."
    wget -O "$BADVPN_TAR_FILE" "$BADVPN_TAR_URL"
    
    informacija "3 žingsnis: Išarchyvuojama ir kompiliuojama..."
    rm -rf "$BADVPN_SRC_DIR"
    mkdir -p "$BADVPN_SRC_DIR"
    tar -xjf "$BADVPN_TAR_FILE" -C "$BADVPN_SRC_DIR" --strip-components=1
    
    cd "$BADVPN_SRC_DIR" || exit
    cmake -B build -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    cd build || exit
    make
    
    informacija "4 žingsnis: Diegiamas vykdomasis failas sistemoje..."
    run_as_root make install
    
    informacija "5 žingsnis: Išvalomi diegimo failai..."
    rm -rf "$BADVPN_SRC_DIR"
    rm -f "$BADVPN_TAR_FILE"

    pavyko "BadVPN sėkmingai sukompiliuotas ir įdiegtas!"
    informacija "Vykdomasis failas yra: $BADVPN_BIN_PATH"
}

# Prideda naują portą prie BadVPN
pridėti_portą() {
    if ! ar_badvpn_įdiegtas; then
        klaida "BadVPN nėra įdiegtas. Pirmiausia įdiekite (1 pasirinkimas)."
        return 1
    fi
    
    if ! systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
        klaida "BadVPN tarnyba neegzistuoja. Sukonfigūruokite ją 3 pasirinkimu."
        return 1
    fi
    
    local esami_portai=$(gauti_aktyvius_portus)
    if [[ -n "$esami_portai" ]]; then
        informacija "Esami portai: $esami_portai"
    fi
    
    read -p "Įveskite naują portą, kurį norite pridėti: " naujas_portas
    if [[ -z "$naujas_portas" ]]; then
        klaida "Neįvestas portas. Operacija atšaukta."
        return 1
    fi
    
    if [[ ! "$naujas_portas" =~ ^[0-9]+$ ]]; then
        klaida "Portas turi būti skaičius."
        return 1
    fi
    
    # Patikriname, ar portas jau neegzistuoja
    if [[ "$esami_portai" =~ $naujas_portas ]]; then
        klaida "Portas $naujas_portas jau egzistuoja."
        return 1
    fi
    
    local visi_portai="$esami_portai $naujas_portas"
    
    local listen_addr="127.0.0.1"
    local exec_start_cmd="$BADVPN_BIN_PATH"
    for port in $visi_portai; do
        exec_start_cmd+=" --listen-addr $listen_addr:$port"
    done

    informacija "Atnaujinamas tarnybos failas su nauju portu..."
    
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=$exec_start_cmd
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    informacija "Perkraunamas BadVPN su nauju portu..."
    run_as_root systemctl daemon-reload
    run_as_root systemctl restart "$SERVICE_NAME"

    pavyko "Portas $naujas_portas pridėtas! Aktyvūs portai: $visi_portai"
}

# Sukuria ir konfigūruoja systemd tarnybą BadVPN
sukurti_tarnybą() {
    read -p "Įveskite portus, kuriuos norite, kad BadVPN klausytų (pvz: 7100 7200 7300): " ports
    if [[ -z "$ports" ]]; then
        klaida "Nenurodyti portai. Operacija atšaukta."
        return 1
    fi

    # Validuojame portus
    for port in $ports; do
        if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            klaida "Neteisingas portas: $port. Portas turi būti skaičius tarp 1-65535."
            return 1
        fi
    done

    local listen_addr="127.0.0.1"
    local exec_start_cmd="$BADVPN_BIN_PATH"
    for port in $ports; do
        exec_start_cmd+=" --listen-addr $listen_addr:$port"
    done

    informacija "Kuriamas tarnybos failas $SERVICE_FILE..."
    
    # Naudojame cat su EOF tarnybos turinio rašymui
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=$exec_start_cmd
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    informacija "Perkraunamas systemd, įjungiamas ir paleidžiamas BadVPN..."
    run_as_root systemctl daemon-reload
    run_as_root systemctl enable "$SERVICE_NAME"
    run_as_root systemctl start "$SERVICE_NAME"

    local aktyvūs_portai=$(gauti_aktyvius_portus)
    pavyko "BadVPN sukurtas ir suaktyvinta! Portai: $aktyvūs_portai"
    run_as_root systemctl status "$SERVICE_NAME" --no-pager
}

# Pašalina BadVPN ir jo tarnybą
pašalinti_badvpn() {
    if ! ar_badvpn_įdiegtas; then
        įspėjimas "BadVPN nėra įdiegtas."
        return 1
    fi

    read -p "Ar tikrai norite pašalinti BadVPN ir jo tarnybą? (t/n): " confirm
    if [[ "$confirm" != "t" ]]; then
        informacija "Pašalinimas atšauktas."
        return
    fi
    
    if systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
        informacija "Stabdomas ir išjungiamas BadVPN..."
        run_as_root systemctl stop "$SERVICE_NAME"
        run_as_root systemctl disable "$SERVICE_NAME"
        run_as_root rm -f "$SERVICE_FILE"
        run_as_root systemctl daemon-reload
        pavyko "BadVPN pašalintas."
    fi

    informacija "Šalinamas BadVPN vykdomasis failas..."
    run_as_root rm -f "$BADVPN_BIN_PATH"

    informacija "Šalinami aplankai ir likusieji failai..."
    rm -rf "$BADVPN_SRC_DIR"
    rm -f "$BADVPN_TAR_FILE"

    pavyko "BadVPN visiškai pašalintas!"
}

# Atnaujina save iš GitHub
atnaujinti_skriptą() {
    informacija "Ieškoma atnaujinimų..."
    if wget -q -O "$SCRIPT_PATH.tmp" "$GITHUB_URL"; then
        mv "$SCRIPT_PATH.tmp" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        pavyko "Skriptas atnaujintas į naujausią versiją."
        informacija "Prašome iš naujo paleisti skriptą."
        exit 0
    else
        klaida "Nepavyko atsisiųsti atnaujinimo."
    fi
}

# Analizuoja svetainę ir randa visas nuorodas
analizuoti_svetainę() {
    read -p "Įveskite svetainės domeną (pvz: google.lt): " domain
    if [[ -z "$domain" ]]; then
        klaida "Neįvestas domenas. Operacija atšaukta."
        return 1
    fi
    
    # Pridedame https:// jei nėra protokolo
    if [[ ! "$domain" =~ ^https?:// ]]; then
        domain="https://$domain"
    fi
    
    informacija "Analizuojama svetainė: $domain"
    informacija "Ieškoma visų nuorodų..."
    
    echo -e "\n${PARYŠKINTAS}${ŽYDRA}=== RASTOS NUORODOS ===${ATSTATYTI}"
    
    if curl -sL "$domain" | grep -Eo 'https?://[^"'"'"'<> ]+' | sed 's/[[:punct:]]*$//' | sort -u; then
        pavyko "Analizė baigta sėkmingai!"
    else
        klaida "Nepavyko prisijungti prie svetainės arba rasti nuorodų."
    fi
}

# Perkrauna BadVPN tarnybą
perkrauti_badvpn() {
    if ! systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
        klaida "BadVPN neegzistuoja. Sukonfigūruokite jį 3 pasirinkimu."
        return 1
    fi
    
    informacija "Perkraunamas BadVPN..."
    run_as_root systemctl restart "$SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        pavyko "BadVPN sėkmingai perkrautas!"
        run_as_root systemctl status "$SERVICE_NAME" --no-pager
    else
        klaida "BadVPN nepavyko perkrauti. Patikrinkite konfigūraciją."
    fi
}

# Pašalina save
šalinti_skriptą() {
    read -p "Ar tikrai norite pašalinti šį valdymo skriptą? (t/n): " confirm
    if [[ "$confirm" == "t" ]]; then
        rm -f "$SCRIPT_PATH"
        pavyko "Skriptas pašalintas."
        informacija "Viso gero!"
        exit 0
    fi
    informacija "Šalinimas atšauktas."
}

# Rodo pagrindinį meniu
rodyti_meniu() {
    clear
    echo -e "${PARYŠKINTAS}${ŽYDRA}"'╔══════════════════════════════════════╗'"${ATSTATYTI}"
    echo -e "${PARYŠKINTAS}${ŽYDRA}"'║           BadVPN PRO '"${SKRIPTO_VERS}"'            ║'"${ATSTATYTI}"
    echo -e "${PARYŠKINTAS}${ŽYDRA}"'║         Force BadVPN valdymas        ║'"${ATSTATYTI}" 
    echo -e "${PARYŠKINTAS}${ŽYDRA}"'╚══════════════════════════════════════╝'"${ATSTATYTI}"
    echo -e "────────────────────────────────────────"
    if ar_badvpn_įdiegtas; then
        echo -e " ${ŽALIA}● BadVPN įdiegtas${ATSTATYTI}"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            local aktyvūs_portai=$(gauti_aktyvius_portus)
            if [[ -n "$aktyvūs_portai" ]]; then
                echo -e " ${ŽALIA}● BadVPN AKTYVUS - Portai: $aktyvūs_portai${ATSTATYTI}"
            else
                echo -e " ${ŽALIA}● BadVPN AKTYVUS${ATSTATYTI}"
            fi
        else
            echo -e " ${GELTONA}● BadVPN NEAKTYVUS${ATSTATYTI}"
        fi
    else
        echo -e " ${RAUDONA}● BadVPN NĖRA įdiegtas${ATSTATYTI}"
    fi
    echo -e "────────────────────────────────────────"
    echo -e " ${PARYŠKINTAS}1)${ATSTATYTI} Įdiegti/Pereinstaliuoti BadVPN"
    echo -e " ${PARYŠKINTAS}2)${ATSTATYTI} ${ŽALIA}Pridėti BadVPN portą${ATSTATYTI}"
    echo -e " ${PARYŠKINTAS}3)${ATSTATYTI} Konfigūruoti/Paleisti BadVPN (Portai)"
    echo -e " ${PARYŠKINTAS}4)${ATSTATYTI} Žiūrėti BadVPN būseną"
    echo -e " ${PARYŠKINTAS}5)${ATSTATYTI} Stabdyti/Paleisti BadVPN"
    echo -e " ${PARYŠKINTAS}6)${ATSTATYTI} ${GELTONA}Pašalinti BadVPN${ATSTATYTI}"
    echo -e " ${PARYŠKINTAS}7)${ATSTATYTI} ${ŽYDRA}Analizuoti svetainę${ATSTATYTI}"
    echo -e " ${PARYŠKINTAS}8)${ATSTATYTI} Perkrauti BadVPN"
    echo -e " ${PARYŠKINTAS}9)${ATSTATYTI} Atnaujinti šį skriptą"
    echo -e " ${PARYŠKINTAS}10)${ATSTATYTI} ${RAUDONA}Šalinti šį skriptą${ATSTATYTI}"
    echo -e " ${PARYŠKINTAS}0)${ATSTATYTI} Išeiti"
    echo -e "────────────────────────────────────────"
}

# --- Pagrindinis ciklas ---
while true; do
    rodyti_meniu
    read -p "Pasirinkite variantą: " choice

    case $choice in
        1)
            įdiegti_badvpn
            spausti_enter_tęsti
            ;;
        2)
            pridėti_portą
            spausti_enter_tęsti
            ;;
        3)
            if ! ar_badvpn_įdiegtas; then
                klaida "Pirmiausia turite įdiegti BadVPN (1 pasirinkimas)."
            else
                sukurti_tarnybą
            fi
            spausti_enter_tęsti
            ;;
        4)
            if ! systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
                klaida "BadVPN neegzistuoja. Sukonfigūruokite jį 3 pasirinkimu."
            else
                run_as_root systemctl status "$SERVICE_NAME" --no-pager
            fi
            spausti_enter_tęsti
            ;;
        5)
            if ! systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
                klaida "BadVPN neegzistuoja. Sukonfigūruokite jį 3 pasirinkimu."
            else
                if systemctl is-active --quiet "$SERVICE_NAME"; then
                    run_as_root systemctl stop "$SERVICE_NAME"
                    pavyko "BadVPN sustabdytas."
                else
                    run_as_root systemctl start "$SERVICE_NAME"
                    pavyko "BadVPN paleistas."
                fi
            fi
            spausti_enter_tęsti
            ;;
        6)
            pašalinti_badvpn
            spausti_enter_tęsti
            ;;
        7)
            analizuoti_svetainę
            spausti_enter_tęsti
            ;;
        8)
            perkrauti_badvpn
            spausti_enter_tęsti
            ;;
        9)
            atnaujinti_skriptą
            ;;
        10)
            šalinti_skriptą
            ;;
        0)
            break
            ;;
        *)
            klaida "Neteisingas pasirinkimas."
            sleep 1
            ;;
    esac
done

echo -e "\n${PARYŠKINTAS}${ŽALIA}"'═══════════════════════════════════════'"${ATSTATYTI}"
echo -e "${PARYŠKINTAS}${ŽALIA}"'  Ačiū, kad naudojate BadVPN PRO! 🚀'"${ATSTATYTI}"
echo -e "${PARYŠKINTAS}${ŽALIA}"'═══════════════════════════════════════'"${ATSTATYTI}\n"
