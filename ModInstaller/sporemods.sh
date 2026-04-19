#!/bin/bash

# ─────────────────────────────────────────────
#  Spore Mod Installer
#  Drop your .package and .sporemod files into:
#  /mnt/A/SteamLibrary/steamapps/common/Spore/ModInstaller/Mods/
# ─────────────────────────────────────────────

MODS_DIR="/mnt/A/SteamLibrary/steamapps/common/Spore/ModInstaller/Mods"

SPORE_PATHS=(
  "/mnt/A/SteamLibrary/steamapps/common/Spore/Data"
  "$HOME/.steam/steam/steamapps/common/Spore/Data"
  "$HOME/.local/share/Steam/steamapps/common/Spore/Data"
  "$HOME/.wine/drive_c/Program Files (x86)/Steam/steamapps/common/Spore/Data"
  "$HOME/.wine/drive_c/Program Files/Steam/steamapps/common/Spore/Data"
  "/Applications/Spore.app/Contents/Resources/Data"
)

MODAPI_PATHS=(
  "/mnt/A/SteamLibrary/steamapps/common/Spore/SporeModLoader"
  "$HOME/.wine/drive_c/Program Files (x86)/Spore ModAPI Launcher Kit"
  "$HOME/.wine/drive_c/Program Files/Spore ModAPI Launcher Kit"
  "$HOME/.steam/steam/steamapps/common/Spore/SporeBin"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_banner() {
  clear
  echo ""
  echo -e "${CYAN}${BOLD}╭────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}${BOLD}│          Spore Mod Installer           │${NC}"
  echo -e "${CYAN}${BOLD}╰────────────────────────────────────────╯${NC}"
  echo ""
}

find_spore_data() {
  for path in "${SPORE_PATHS[@]}"; do
    if [ -d "$path" ]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

check_modapi() {
  for path in "${MODAPI_PATHS[@]}"; do
    if [ -d "$path" ]; then
      echo -e "${GREEN}✔ SporeModLoader found at:${NC} $path\n"
      return 0
    fi
  done
  echo -e "${YELLOW}⚠ SporeModLoader / ModAPI not detected.${NC}"
  echo -e "  Some mods may require one or the other. You can get SporeModLoader (Linux-friendly) at:"
  echo -e "  ${CYAN}https://github.com/Rosalie241/SporeModLoader${NC}\n"
}

list_mods() {
  if [ ! -d "$MODS_DIR" ]; then
    mkdir -p "$MODS_DIR"
    MOD_FILES=()
    return 0
  fi

  mapfile -t MOD_FILES < <(find "$MODS_DIR" -maxdepth 1 \( -name "*.package" -o -name "*.sporemod" \) | sort)
}

show_installed_mods() {
  echo -e "${BOLD}Installed mods in Data folder:${NC}"
  echo ""
  mapfile -t INSTALLED_MODS < <(find "$SPORE_DATA" -maxdepth 1 -name "*.package" | sort)

  if [ ${#INSTALLED_MODS[@]} -eq 0 ]; then
    echo -e "  ${YELLOW}No .package files found in Data folder.${NC}"
  else
    for mod in "${INSTALLED_MODS[@]}"; do
      echo -e "  - $(basename "$mod")"
    done
  fi
  echo ""
}

show_menu() {
  if [ ${#MOD_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ No mod files found in:${NC} $MODS_DIR"
    echo -e "  Drop .package or .sporemod files there and the list will update automatically."
    echo ""
  else
    echo -e "${BOLD}Available mods:${NC}"
    echo ""
    for i in "${!MOD_FILES[@]}"; do
      filename=$(basename "${MOD_FILES[$i]}")

      if [[ "$filename" == *.sporemod ]]; then
        type_tag="${YELLOW}[Sporemod Bundle]${NC}"
      elif [[ "$filename" == *"ModAPI"* ]]; then
        type_tag="${YELLOW}[ModAPI]${NC}"
      else
        type_tag="${GREEN}[Standard]${NC}"
      fi

      echo -e "  ${CYAN}[$((i+1))]${NC} $filename $type_tag"
    done
    echo ""
    echo -e " ${CYAN}[A]${NC} Install ALL mods"
  fi
  echo -e " ${CYAN}[U]${NC} Show installed mods (in Data folder)"
  echo -e " ${CYAN}[Q]${NC} Quit"
  echo ""
}

# ─────────────────────────────────────────────
#  parse_modinfo <ModInfo.xml path>
#
#  Outputs tab-separated records, one per line:
#    NAME   <displayName>
#    DESC   <description>
#    GROUP  <unique>\t<displayName>
#    COMP   <unique>\t<displayName>\t<description>\t<defaultChecked>\t<filename>\t<group_unique|"">
#    PREREQ <filename>
#
#  Records are emitted in document order so the
#  display loop can render group headers inline.
# ─────────────────────────────────────────────
parse_modinfo() {
  local xml_file="$1"
  python3 - "$xml_file" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

try:
    tree = ET.parse(sys.argv[1])
    root = tree.getroot()
except Exception as e:
    print(f"PARSE_ERROR\t{e}", file=sys.stderr)
    sys.exit(1)

sep = "\t"
print(f"NAME{sep}{root.get('displayName', 'Unknown Mod')}")
print(f"DESC{sep}{root.get('description', '')}")

def emit_component(elem, group_unique=""):
    unique   = elem.get("unique", "")
    display  = elem.get("displayName", unique)
    edesc    = elem.get("description", "")
    default  = elem.get("defaultChecked", "false").lower()
    filename = (elem.text or "").strip()
    print(f"COMP{sep}{unique}{sep}{display}{sep}{edesc}{sep}{default}{sep}{filename}{sep}{group_unique}")

for elem in root:
    if elem.tag == "component":
        emit_component(elem)
    elif elem.tag == "componentGroup":
        g_unique  = elem.get("unique", "")
        g_display = elem.get("displayName", g_unique)
        print(f"GROUP{sep}{g_unique}{sep}{g_display}")
        for child in elem:
            if child.tag == "component":
                emit_component(child, g_unique)
    elif elem.tag == "prerequisite":
        val = (elem.text or "").strip()
        if val:
            print(f"PREREQ{sep}{val}")
PYEOF
}

# ─────────────────────────────────────────────
#  wrap_text <text> <width> <indent>
#  Simple word-wrap for description display.
# ─────────────────────────────────────────────
wrap_text() {
  local text="$1"
  local width="${2:-72}"
  local indent="${3:-4}"
  local pad
  pad=$(printf '%*s' "$indent" '')
  echo "$text" | fold -s -w "$width" | sed "s/^/${pad}/"
}

# ─────────────────────────────────────────────
#  install_mod <mod_path> <dest_dir> <mode>
#  mode: "auto" (batch install) or "manual"
# ─────────────────────────────────────────────
install_mod() {
  local mod_path="$1"
  local dest_dir="$2"
  local mode="$3"
  local filename
  filename=$(basename "$mod_path")

  # ── .SPOREMOD ARCHIVE LOGIC ──────────────────
  if [[ "$filename" == *.sporemod ]]; then
    local loader_dir=""
    for p in "${MODAPI_PATHS[@]}"; do [ -d "$p" ] && loader_dir="$p" && break; done

    echo -e "${CYAN}📦 Inspecting $filename...${NC}"

    if ! command -v unzip &>/dev/null; then
      echo -e "${RED}  ✘ 'unzip' is missing. Install it to extract .sporemod files.${NC}"
      return 1
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    unzip -q "$mod_path" -d "$tmp_dir"

    # ── Try to locate and parse ModInfo.xml ──
    local modinfo_file
    modinfo_file=$(find "$tmp_dir" -maxdepth 3 -iname "ModInfo.xml" | head -1)

    # Arrays to hold component data parsed from XML
    local -a comp_uniques=()
    declare -A comp_display comp_desc comp_default comp_file comp_group
    declare -A group_display
    local -a group_order=()   # groups in document order, for display
    local mod_name="" mod_desc=""
    local -a prereqs=()
    local has_modinfo=false

    if [ -n "$modinfo_file" ] && command -v python3 &>/dev/null; then
      has_modinfo=true

      while IFS=$'\t' read -r record_type rest; do
        case "$record_type" in
          NAME)
            mod_name="$rest"
            ;;
          DESC)
            mod_desc="$rest"
            ;;
          GROUP)
            IFS=$'\t' read -r g_unique g_display <<< "$rest"
            group_order+=("$g_unique")
            group_display["$g_unique"]="$g_display"
            ;;
          COMP)
            # rest = unique\tdisplayName\tdescription\tdefaultChecked\tfilename\tgroup_unique
            IFS=$'\t' read -r u dname ddesc ddef dfile dgroup <<< "$rest"
            comp_uniques+=("$u")
            comp_display["$u"]="$dname"
            comp_desc["$u"]="$ddesc"
            comp_default["$u"]="$ddef"
            comp_file["$u"]="$dfile"
            comp_group["$u"]="$dgroup"
            ;;
          PREREQ)
            prereqs+=("$rest")
            ;;
        esac
      done < <(parse_modinfo "$modinfo_file")
    fi

    # ── Display mod header ────────────────────
    if $has_modinfo && [ -n "$mod_name" ]; then
      echo ""
      echo -e "  ${BOLD}${CYAN}$mod_name${NC}"
      if [ -n "$mod_desc" ]; then
        echo ""
        wrap_text "$mod_desc" 70 4
      fi
      if [ ${#prereqs[@]} -gt 0 ]; then
        echo ""
        echo -e "  ${YELLOW}⚙ Required DLL(s) — installed automatically:${NC}"
        for req in "${prereqs[@]}"; do
          echo -e "    ${DIM}→ $req${NC}"
        done
      fi
      echo ""
    fi

    # ── Resolve component files from extraction ──
    # Build a lookup: basename -> full path in tmp_dir
    declare -A extracted_lookup=()
    while IFS= read -r -d '' f; do
      extracted_lookup["$(basename "$f")"]="$f"
    done < <(find "$tmp_dir" -type f \( -name "*.package" -o -name "*.dll" \) -print0)

    # ── Determine which components/files to present ──
    local -a files_to_install=()

    if $has_modinfo && [ ${#comp_uniques[@]} -gt 0 ]; then

      if [ ${#comp_uniques[@]} -eq 1 ]; then
        # ── Single component: show info, ask yes/no ──
        local u="${comp_uniques[0]}"
        echo -e "  ${BOLD}Component:${NC}  ${comp_display[$u]}"
        if [ -n "${comp_desc[$u]}" ]; then
          echo ""
          wrap_text "${comp_desc[$u]}" 68 4
        fi
        echo ""

        if [[ "$mode" == "auto" ]]; then
          local yn="y"
        else
          echo -n "  Install this mod? [Y/n]: "
          read -r yn
        fi

        if [[ "${yn,,}" == "n" ]]; then
          echo -e "${YELLOW}  ↺ Skipped $filename.${NC}"
          rm -rf "$tmp_dir"
          return 0
        fi

        # Resolve the single component file
        local target_file="${comp_file[$u]}"
        if [ -n "$target_file" ] && [ -n "${extracted_lookup[$target_file]}" ]; then
          files_to_install+=("${extracted_lookup[$target_file]}")
        else
          # Fallback: install all extracted files
          for f in "${!extracted_lookup[@]}"; do
            files_to_install+=("${extracted_lookup[$f]}")
          done
        fi

      else
        # ── Multiple components: show selection with group headers ──
        echo -e "  ${BOLD}Components:${NC}"
        echo ""

        local last_group=""
        for i in "${!comp_uniques[@]}"; do
          local u="${comp_uniques[$i]}"
          local g="${comp_group[$u]}"

          # Print group header when we enter a new componentGroup
          if [ -n "$g" ] && [ "$g" != "$last_group" ]; then
            echo -e "    ${YELLOW}┬ ${group_display[$g]}  ${DIM}(pick one)${NC}"
            last_group="$g"
          elif [ -z "$g" ] && [ -n "$last_group" ]; then
            echo -e "    ${YELLOW}┴${NC}"
            echo ""
            last_group=""
          fi

          local default_marker=""
          [[ "${comp_default[$u]}" == "true" ]] && default_marker=" ${DIM}(default)${NC}"

          if [[ "${comp_file[$u]}" == *.dll ]]; then
            local ctype="${YELLOW}[DLL]${NC}"
          else
            local ctype="${GREEN}[Package]${NC}"
          fi

          local indent="    "
          [ -n "$g" ] && indent="      "

          echo -e "${indent}${CYAN}[$((i+1))]${NC} $ctype ${BOLD}${comp_display[$u]}${NC}${default_marker}"
          if [ -n "${comp_desc[$u]}" ]; then
            local wrap_indent=8; [ -n "$g" ] && wrap_indent=10
            wrap_text "${comp_desc[$u]}" 64 $wrap_indent
          fi
          echo ""
        done

        # Close any open group bracket
        [ -n "$last_group" ] && echo -e "    ${YELLOW}┴${NC}" && echo ""

        echo -e "    ${CYAN}[A]${NC} Install ALL components"
        echo -e "    ${CYAN}[D]${NC} Install DEFAULT components only"
        echo -e "    ${CYAN}[S]${NC} Skip this mod entirely"
        echo ""

        local selected_uniques=()

        if [[ "$mode" == "auto" ]]; then
          # In batch mode, install defaultChecked components
          for u in "${comp_uniques[@]}"; do
            [[ "${comp_default[$u]}" == "true" ]] && selected_uniques+=("$u")
          done
          [ ${#selected_uniques[@]} -eq 0 ] && selected_uniques=("${comp_uniques[@]}")
          echo -e "  ${DIM}(Batch mode: installing defaults)${NC}"
        else
          while true; do
            echo -n "  Enter choice(s): "
            read -r sub_input

            case "${sub_input^^}" in
              S)
                echo -e "${YELLOW}  ↺ Skipped $filename.${NC}"
                rm -rf "$tmp_dir"
                return 0
                ;;
              A)
                selected_uniques=("${comp_uniques[@]}")
                break
                ;;
              D)
                for u in "${comp_uniques[@]}"; do
                  [[ "${comp_default[$u]}" == "true" ]] && selected_uniques+=("$u")
                done
                [ ${#selected_uniques[@]} -eq 0 ] && selected_uniques=("${comp_uniques[@]}")
                break
                ;;
              *)
                local valid_sub=true
                for num in $sub_input; do
                  if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#comp_uniques[@]}" ]; then
                    echo -e "${RED}    ✘ Invalid choice: $num${NC}"
                    valid_sub=false
                    break
                  fi
                done

                if $valid_sub; then
                  # Check for group conflicts: at most one selection per componentGroup
                  declare -A _grp_seen=()
                  local conflict=false
                  for num in $sub_input; do
                    local candidate_u="${comp_uniques[$((num-1))]}"
                    local candidate_g="${comp_group[$candidate_u]}"
                    if [ -n "$candidate_g" ]; then
                      if [ -n "${_grp_seen[$candidate_g]}" ]; then
                        echo -e "${RED}    ✘ "${group_display[$candidate_g]}" only allows one selection — pick either $num or ${_grp_seen[$candidate_g]}.${NC}"
                        conflict=true
                      else
                        _grp_seen["$candidate_g"]="$num"
                      fi
                    fi
                  done
                  unset _grp_seen

                  if ! $conflict; then
                    for num in $sub_input; do
                      selected_uniques+=("${comp_uniques[$((num-1))]}")
                    done
                    break
                  fi
                fi
                ;;
            esac
          done
        fi

        # Resolve selected component filenames to paths
        for u in "${selected_uniques[@]}"; do
          local target_file="${comp_file[$u]}"
          if [ -n "$target_file" ] && [ -n "${extracted_lookup[$target_file]}" ]; then
            files_to_install+=("${extracted_lookup[$target_file]}")
          else
            echo -e "${YELLOW}    ⚠ Could not locate file for component '${comp_display[$u]}': $target_file${NC}"
          fi
        done
      fi

    else
      # ── No ModInfo.xml: fall back to filesystem scan ──
      local -a raw_files=()
      for f in "${!extracted_lookup[@]}"; do
        raw_files+=("${extracted_lookup[$f]}")
      done

      if [ ${#raw_files[@]} -eq 0 ]; then
        echo -e "${RED}  ✘ No .package or .dll files found inside $filename${NC}"
        rm -rf "$tmp_dir"
        return 1
      fi

      if [ ${#raw_files[@]} -eq 1 ]; then
        echo -e "  ${BOLD}File:${NC} $(basename "${raw_files[0]}")"
        echo ""
        if [[ "$mode" != "auto" ]]; then
          echo -n "  Install this mod? [Y/n]: "
          read -r yn
          if [[ "${yn,,}" == "n" ]]; then
            echo -e "${YELLOW}  ↺ Skipped $filename.${NC}"
            rm -rf "$tmp_dir"
            return 0
          fi
        fi
        files_to_install=("${raw_files[0]}")
      else
        if [[ "$mode" == "auto" ]]; then
          files_to_install=("${raw_files[@]}")
        else
          echo -e "${YELLOW}  No ModInfo.xml found. Showing raw files:${NC}"
          for i in "${!raw_files[@]}"; do
            local bname
            bname=$(basename "${raw_files[$i]}")
            local tag="${GREEN}[Package]${NC}"
            [[ "$bname" == *.dll ]] && tag="${YELLOW}[DLL]${NC}"
            echo -e "    ${CYAN}[$((i+1))]${NC} $tag $bname"
          done
          echo -e "    ${CYAN}[A]${NC} Install ALL"
          echo -e "    ${CYAN}[S]${NC} Skip"
          echo ""

          while true; do
            echo -n "  Enter choice(s): "
            read -r sub_input
            if [[ "${sub_input^^}" == "S" ]]; then
              echo -e "${YELLOW}  ↺ Skipped $filename.${NC}"
              rm -rf "$tmp_dir"
              return 0
            elif [[ "${sub_input^^}" == "A" ]]; then
              files_to_install=("${raw_files[@]}")
              break
            else
              local valid_sub=true
              for num in $sub_input; do
                if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#raw_files[@]}" ]; then
                  echo -e "${RED}    ✘ Invalid choice: $num${NC}"
                  valid_sub=false
                fi
              done
              if $valid_sub; then
                for num in $sub_input; do
                  files_to_install+=("${raw_files[$((num-1))]}")
                done
                break
              fi
            fi
          done
        fi
      fi
    fi

    # ── Prepend prerequisite DLLs (always installed, regardless of component selection) ──
    if [ ${#prereqs[@]} -gt 0 ]; then
      local -a prereq_files=()
      for req in "${prereqs[@]}"; do
        if [ -n "${extracted_lookup[$req]}" ]; then
          prereq_files+=("${extracted_lookup[$req]}")
        else
          echo -e "${YELLOW}    ⚠ Prerequisite '$req' not found inside the archive — skipping.${NC}"
        fi
      done
      files_to_install=("${prereq_files[@]}" "${files_to_install[@]}")
    fi

    # ── Copy selected files to destinations ──────
    for file in "${files_to_install[@]}"; do
      local bname
      bname=$(basename "$file")

      if [[ "$bname" == *.package ]]; then
        [ -f "$dest_dir/$bname" ] && echo -e "${YELLOW}    ↺ Replacing existing:${NC} $bname"
        cp "$file" "$dest_dir/$bname"
        echo -e "${GREEN}    ✔ Installed:${NC} $bname  ${DIM}-> Data/${NC}"

      elif [[ "$bname" == *.dll ]]; then
        if [ -n "$loader_dir" ]; then
          mkdir -p "$loader_dir/ModLibs"
          [ -f "$loader_dir/ModLibs/$bname" ] && echo -e "${YELLOW}    ↺ Replacing existing DLL:${NC} $bname"
          cp "$file" "$loader_dir/ModLibs/$bname"
          echo -e "${GREEN}    ✔ Installed DLL:${NC} $bname  ${DIM}-> ModLibs/${NC}"
        else
          echo -e "${RED}    ✘ Skipping DLL $bname: SporeModLoader not found.${NC}"
        fi
      fi
    done

    rm -rf "$tmp_dir"
    return 0
  fi

  # ── STANDARD .PACKAGE FILE LOGIC ─────────────
  [ -f "$dest_dir/$filename" ] && echo -e "${YELLOW}  ↺ Already installed, replacing:${NC} $filename"

  cp "$mod_path" "$dest_dir/$filename"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✔ Installed:${NC} $filename"
  else
    echo -e "${RED}  ✘ Failed to install:${NC} $filename"
  fi
}

# ─────────────────────────────────────────────
#  _pause: wait for a keypress before redrawing
# ─────────────────────────────────────────────
_pause() {
  echo ""
  echo -e "${DIM}Press any key to return to the menu...${NC}"
  read -r -s -n 1
}

# ─────────────────────────────────────────────
#  _redraw: clear and repaint the full menu screen
# ─────────────────────────────────────────────
_redraw() {
  list_mods 2>/dev/null  # refresh MOD_FILES silently; exits only if dir missing
  print_banner
  echo -e "${GREEN}✔ Spore Data:${NC} $SPORE_DATA"
  echo ""
  check_modapi
  show_menu
}

main() {
  # ── One-time startup ──────────────────────
  print_banner

  SPORE_DATA=$(find_spore_data)
  if [ -z "$SPORE_DATA" ]; then
    echo -e "${RED}✘ Could not find Spore's Data folder automatically.${NC}"
    echo ""
    echo -n "Enter the full path to your Spore/Data folder manually: "
    read -r SPORE_DATA
    if [ ! -d "$SPORE_DATA" ]; then
      echo -e "${RED}Path not found. Exiting.${NC}"
      exit 1
    fi
  fi

  list_mods
  _redraw

  # ── Main event loop ───────────────────────
  while true; do
    echo -n "Enter number(s) separated by spaces, A for all, or Q to quit: "
    read -r input

    case "${input^^}" in
      Q)
        clear
        echo "Bye!"
        exit 0
        ;;

      U)
        clear
        print_banner
        show_installed_mods
        _pause
        _redraw
        continue
        ;;

      A)
        clear
        print_banner
        echo -e "${BOLD}Installing all mods...${NC}"
        echo ""
        for mod in "${MOD_FILES[@]}"; do
          install_mod "$mod" "$SPORE_DATA" "auto"
        done
        echo ""
        echo -e "${GREEN}${BOLD}Done! Restart Spore to apply your mods.${NC}"
        _pause
        _redraw
        continue
        ;;
    esac

    valid=true
    for num in $input; do
      if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#MOD_FILES[@]}" ]; then
        echo -e "${RED}Invalid choice: $num${NC}"
        valid=false
      fi
    done

    if $valid; then
      clear
      print_banner
      echo -e "${BOLD}Installing selected mods...${NC}"
      echo ""
      for num in $input; do
        install_mod "${MOD_FILES[$((num-1))]}" "$SPORE_DATA" "manual"
      done
      echo ""
      echo -e "${GREEN}${BOLD}Done! Restart Spore to apply your mods.${NC}"
      _pause
      _redraw
      continue
    fi

    _redraw
  done
}

main
