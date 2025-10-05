#!/bin/bash
# -*- coding: utf-8 -*-
# install.sh: Pažangus ir patikimas BadVPN-Force diegimo įrankis

# Nustatome UTF-8 kodavimą
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# --- Konfigūracijos kintamieji ---
readonly SCRIPT_NAME="badvpn-pro"          
readonly GITHUB_USER="ForceGROUP"                   
readonly GITHUB_REPO="BadVPN-PRO"                  
readonly SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/BadVPN.sh"  
readonly INSTALL_DIR="$HOME/.local/bin"        

# --- Spalvos ir stiliai ---
readonly ZALIA='\033[0;32m'       # Žalia spalva
readonly MELYNA='\033[0;34m'      # Mėlyna spalva  
readonly GELTONA='\033[0;33m'     # Geltona spalva
readonly RAUDONA='\033[0;31m'     # Raudona spalva
readonly PARYSKINTAS='\033[1m'    # Paryškintas tekstas
readonly ATSTATYTI='\033[0m'      # Spalvos atstatymas

# --- Pagalbinės funkcijos ---
informacija() { echo -e "${MELYNA}ℹ ${*}${ATSTATYTI}"; }
pavyko() { echo -e "${ZALIA}✔ ${*}${ATSTATYTI}"; }
ispejimas() { echo -e "${GELTONA}⚠ ${*}${ATSTATYTI}"; }
klaida() { echo -e "${RAUDONA}✖ ${*}${ATSTATYTI}"; exit 1; }
veiksmas() { echo -e "\n${PARYSKINTAS}${ZALIA}› ${*}${ATSTATYTI}"; }

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
        ispejimas "'sudo' nerasta. Jei reikalingos root teisės, skriptas gali neveikti."
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
    
    veiksmas "Atsisiunčiamas pagrindinis skriptas iš GitHub..."

    # Patikriname, ar tikslo failas jau egzistuoja
    if [[ -f "$target_path" ]]; then
        ispejimas "Skriptas jau egzistuoja. Bus perrašytas."
    fi

    # Atsisiunčiame failą iš GitHub
    if komanda_egzistuoja curl; then
        if curl -sSL "$SCRIPT_URL" -o "$target_path"; then
            pavyko "Skriptas atsisiųstas į '$target_path'."
        else
            klaida "Atsisiuntimas su curl nepavyko. Patikrinkite interneto ryšį ir URL: $SCRIPT_URL"
        fi
    elif komanda_egzistuoja wget; then
        if wget -q -O "$target_path" "$SCRIPT_URL"; then
            pavyko "Skriptas atsisiųstas į '$target_path'."
        else
            klaida "Atsisiuntimas su wget nepavyko. Patikrinkite interneto ryšį ir URL: $SCRIPT_URL"
        fi
    else
        klaida "Nerasta nei curl, nei wget komandos."
    fi
    
    if [[ -f "$target_path" ]]; then
        chmod +x "$target_path"
        pavyko "Vykdymo teisės priskirtos."
    else
        klaida "Nepavyko sukurti failo '$target_path'."
    fi
}

# --- Pagrindinis srautas ---
pagrindinis() {
    clear
    echo -e "${PARYSKINTAS}${ZALIA}--- BadVPN Manager diegėjas ---${ATSTATYTI}"
    tikrinti_priklausomybes
    nustatyti_aplinką
    atsisiųsti_skriptą
    
    echo -e "\n\n${PARYSKINTAS}🎉 Diegimas baigtas sėkmingai! 🎉${ATSTATYTI}"
    informacija "Kad pradėtumėte, iš naujo paleiskite terminalą arba vykdykite:"
    echo -e "  ${GELTONA}source ~/.bashrc  # (arba jūsų apvalkalo failą, pvz.: ~/.zshrc)${ATSTATYTI}"
    informacija "Tada paprasčiausiai vykdykite komandą:"
    echo -e "  ${ZALIA}${SCRIPT_NAME}${ATSTATYTI}"
    informacija "Arba galite iš karto paleisti:"
    echo -e "  ${ZALIA}$INSTALL_DIR/$SCRIPT_NAME${ATSTATYTI}"
}

pagrindinis
