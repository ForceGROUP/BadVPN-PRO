#!/bin/bash
# install.sh: Pažangus ir patikimas BadVPN-Force diegimo įrankis 

# --- Konfigūracijos kintamieji ---
readonly SCRIPT_NAME="badvpn-Force"          
readonly GITHUB_USER="ForceGROUP"                   
readonly GITHUB_REPO="BadVPN"                  
readonly SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/Main_BadVPN.sh"  
readonly INSTALL_DIR="$HOME/.local/bin"        

# --- Spalvos ir stiliai ---
readonly ŽALIA='\033[0;32m'       # Žalia spalva
readonly MĖLYNA='\033[0;34m'      # Mėlyna spalva  
readonly GELTONA='\033[0;33m'     # Geltona spalva
readonly RAUDONA='\033[0;31m'     # Raudona spalva
readonly PARYŠKINTAS='\033[1m'    # Paryškintas tekstas
readonly ATSTATYTI='\033[0m'      # Spalvos atstatymas

# --- Pagalbinės funkcijos ---
informacija() { echo -e "${MĖLYNA}ℹ ${*}${ATSTATYTI}"; }
pavyko() { echo -e "${ŽALIA}✔ ${*}${ATSTATYTI}"; }
įspėjimas() { echo -e "${GELTONA}⚠ ${*}${ATSTATYTI}"; }
klaida() { echo -e "${RAUDONA}✖ ${*}${ATSTATYTI}"; exit 1; }
veiksmas() { echo -e "\n${PARYŠKINTAS}${ŽALIA}› ${*}${ATSTATYTI}"; }

# --- Skripto logika ---

# Funkcija patikrinti, ar komanda egzistuoja
komanda_egzistuoja() {
    command -v "$1" >/dev/null 2>&1
}

# Vykdo komandas kaip root tik esant poreikiui
vykdyti_kaip_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Patikrina pagrindinius priklausomybes (curl arba wget)
tikrinti_priklausomybes() {
    veiksmas "Tikrinamos priklausomybės..."
    if ! komanda_egzistuoja curl && ! komanda_egzistuoja wget; then
        klaida "Jums reikia 'curl' arba 'wget' skripto atsisiuntimui. Prašome įdiegti vieną iš jų."
    fi
    if ! komanda_egzistuoja sudo; then
        įspėjimas "'sudo' nerasta. Jei reikalingos root teisės, skriptas gali neveikti."
    fi
    pavyko "Priklausomybės rastos."
}

# Sukuria direktoriją ir konfigūruoja PATH esant poreikiui
nustatyti_aplinką() {
    veiksmas "Konfigūruojama diegimo aplinka..."
    mkdir -p "$INSTALL_DIR"

    # Aptinka shell profilio failą (.bashrc, .zshrc, ir t.t.)
    local shell_profile
    if [[ -n "$BASH_VERSION" ]]; then
        shell_profile="$HOME/.bashrc"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_profile="$HOME/.zshrc"
    else
        shell_profile="$HOME/.profile"
    fi

    # Prideda direktoriją prie PATH tik jei dar nepridėta
    if ! grep -q "export PATH=.*$INSTALL_DIR" "$shell_profile"; then
        informacija "Pridedama '$INSTALL_DIR' į jūsų PATH faile '$shell_profile'."
        echo -e "\n# Pridėta BadVPN-Manager diegėjo\nexport PATH=\"\$PATH:$INSTALL_DIR\"" >> "$shell_profile"
        pavyko "PATH sukonfigūruotas. Reikės iš naujo paleisti terminalą, kad pakeitimai įsigaliotų."
    else
        informacija "Direktorija '$INSTALL_DIR' jau yra jūsų PATH."
    fi
}

# Atsisiunčia pagrindinį skriptą iš GitHub
atsisiųsti_skriptą() {
    local target_path="$INSTALL_DIR/$SCRIPT_NAME"
    veiksmas "Atsisiunčiamas pagrindinis skriptas..."

    if komanda_egzistuoja curl; then
        if curl -sSL "$SCRIPT_URL" -o "$target_path"; then
            pavyko "Skriptas atsisiųstas į '$target_path'."
        else
            klaida "Atsisiuntimas su curl nepavyko."
        fi
    elif komanda_egzistuoja wget; then
        if wget -q -O "$target_path" "$SCRIPT_URL"; then
            pavyko "Skriptas atsisiųstas į '$target_path'."
        else
            klaida "Atsisiuntimas su wget nepavyko."
        fi
    fi
    
    chmod +x "$target_path"
    pavyko "Vykdymo teisės priskirtos."
}

# --- Pagrindinis srautas ---
pagrindinis() {
    clear
    echo -e "${PARYŠKINTAS}${ŽALIA}--- BadVPN Manager diegėjas ---${ATSTATYTI}"
    tikrinti_priklausomybes
    nustatyti_aplinką
    atsisiųsti_skriptą
    
    echo -e "\n\n${PARYŠKINTAS}🎉 Diegimas baigtas! 🎉${ATSTATYTI}"
    informacija "Kad pradėtumėte, iš naujo paleiskite terminalą arba vykdykite:"
    echo -e "  ${GELTONA}source ~/.bashrc  # (arba jūsų apvalkalo failą, pvz.: ~/.zshrc)${ATSTATYTI}"
    informacija "Tada paprasčiausiai vykdykite komandą:"
    echo -e "  ${ŽALIA}${SCRIPT_NAME}${ATSTATYTI}"
}

pagrindinis
