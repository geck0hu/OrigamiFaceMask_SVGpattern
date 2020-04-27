#!/bin/bash
# ver 1.0
# gkortvelyessy@gmail.com
#

# This function allows testing the required (SRC) files, credit: https://stackoverflow.com/a/1305340
flistadd() {
    export ${1}="${*:2}"
    [[ ${FLIST} =~ "(^| )${1}($| )" ]] || FLIST="${FLIST} ${1}"
}

flistadd ORIG_SVG "OrigamiFaceMask.svg"
flistadd CLONE_SVG "OrigamiFaceMask-CLONE.svg"
flistadd OVERLAY_SVG "OrigamiFaceMask-Overlay.svg"
flistadd UNDERLAY_SVG "OrigamiFaceMask-Underlay.svg"

OUT_PDF="OrigamiFaceMask-A4.pdf"

PAGE_X=297
PAGE_Y=210
ORIG_A=130
ORIG_B=101
# width of nose part
rect1_X="18.224"
# width of stapler pin + clearance
g21_X="12.277 + 3"

# To get the replaceable fields run:
#  sed -n '/«.*\»/p' OrigamiFaceMask-CLONE.svg

declare -a sizes=("130"
                  "120"
                  "115"
                  "110"
                  "105"
                  "100"
                  "95"
                  )

ERR_MissingFile1="Source file missing:"
ERR_MissingFile2="Please check and edit the script if necessary, variable:"

for i in ${FLIST}; do
    if [[ ! -f "${!i}" ]]; then
        echo -e "$ERR_MissingFile1 '${!i}'\n $ERR_MissingFile2 '${i}'" >&2
        ERR_Missing=$(( $ERR_Missing + 1 ))
    fi
done

ERR_MissingCmd1="Missing dependency:"
ERR_MissingCmd2="A required application is not available. The program will exit."

# Testing the required applications
function testdependencies() {
    # [ARGS] $1: Command, $2: Name/Description of the command (optional)
    command -v "$1" > /dev/null
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        local AppName="$([[ -z "$2" ]] && echo "'$1'" || echo "'$1' ($2)")"
        echo -e "$ERR_MissingCmd1 $AppName\n $ERR_MissingCmd2" >&2
        ERR_Missing=$(( $ERR_Missing + 1 ))
    fi
}

testdependencies "inkscape"
testdependencies "qpdf"
testdependencies "exiftool" "part of 'libimage-exiftool-perl'"
[[ $ERR_Missing -gt 0 ]] && exit $ERR_Missing

if [[ -f "${OUT_PDF}" ]]; then
  read -p "Output file '${OUT_PDF}' exists. Do you want to delete it? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "${OUT_PDF}"
  else
    exit
  fi
fi


float2frac() {
  echo -n ${1%%.*}
  local num="$(printf '%.4f' "$1")"
  local i=${num##*.}
  if ((1<=$i && $i<=1000)); then
    echo "⅒"
  elif ((1000<=$i && $i<=1111)); then
    echo "⅑"
  elif ((1111<=$i && $i<=1250)); then
    echo "⅛"
  elif ((1250<=$i && $i<=1429)); then
    echo "⅐"
  elif ((1429<=$i && $i<=1667)); then
    echo "⅙"
  elif ((1667<=$i && $i<=2000)); then
    echo "⅕"
  elif ((2000<=$i && $i<=2500)); then
    echo "¼"
  elif ((2500<=$i && $i<=3333)); then
    echo "⅓"
  elif ((3333<=$i && $i<=3750)); then
    echo "⅜"
  elif ((3750<=$i && $i<=4000)); then
    echo "⅖"
  elif ((4000<=$i && $i<=5000)); then
    echo "½"
  elif ((5000<=$i && $i<=6000)); then
    echo "⅗"
  elif ((6000<=$i && $i<=6250)); then
    echo "⅝"
  elif ((6250<=$i && $i<=6667)); then
    echo "⅔"
  elif ((6667<=$i && $i<=7500)); then
    echo "¾"
  elif ((7500<=$i && $i<=8000)); then
    echo "⅘"
  elif ((8000<=$i && $i<=8333)); then
    echo "⅚"
  elif ((8333<=$i && $i<=8750)); then
    echo "⅞"
  else
    echo ""
  fi
}

TMP_DIR="$(mktemp -d)"
trap '[ -d "${TMP_DIR}" ] && rm -rf "${TMP_DIR}"' EXIT

cp "$ORIG_SVG" "${TMP_DIR}/"

for ((i=0; i<${#sizes[*]}; i++)); do
    f="$(printf '%03d' $i)"
    s="$(printf '%.8f' "$(bc <<< "scale=8; ${sizes[i]} / ${ORIG_A}")")"
    size_btext="$(printf '%.1f' "$(bc <<< "${ORIG_B} * $s")" | grep -o '.*[1-9]')"
    l1translate_x="$(bc <<< "scale=8; ${PAGE_X} * (1 - $s) / 2")"
    l1translate_y="$(bc <<< "scale=8; ${PAGE_Y} * (1 - $s)")"
    l2rotate_deg="$(bc -l <<< "scale=4; if(${g21_X} >= (${rect1_X}*$s)) {a(sqrt(1-$s^2)/$s) *45/a(1)} else {0}")"
    l2translate_x="$(bc <<< "scale=2; ${PAGE_X} * (1 - $s) / 3")"
    l2translate_y="$(bc <<< "scale=2; ${PAGE_Y} * (1 - $s) / 4")"

    rm -f "${TMP_DIR}/replace.sed"
    echo "s|«size_a-text»|${sizes[i]}mm|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«size_b-text»|${size_btext}mm|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«scale»|$s|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«l1translate_x»|$l1translate_x|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«l1translate_y»|$l1translate_y|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«l2rotate_deg»|-$l2rotate_deg|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«l2translate_x»|$l2translate_x|g" >> "${TMP_DIR}/replace.sed"
    echo "s|«l2translate_y»|$l2translate_y|g" >> "${TMP_DIR}/replace.sed"
#    echo "s|||g" >> "${TMP_DIR}/replace.sed"

    sed -E -f "${TMP_DIR}/replace.sed" -e "w ${TMP_DIR}/$f.svg" "${CLONE_SVG}" > /dev/null
    inkscape -z -f "${TMP_DIR}/$f.svg" -A "${TMP_DIR}/$f.pdf" -T --export-pdf-version='1.5' > /dev/null
done

inkscape -z -f "${UNDERLAY_SVG}" -A "${TMP_DIR}/underlay.pdf" -T --export-pdf-version='1.5' > /dev/null
# Overlay with embedded text+font
inkscape -z -f "${OVERLAY_SVG}" -A "${TMP_DIR}/overlay.pdf" --export-pdf-version='1.5' > /dev/null


for file in "${TMP_DIR}"/[0-9]*.pdf; do
    pdfs="$pdfs $file"
done

qpdf --empty --pages $pdfs -- "${TMP_DIR}/pages.pdf"
qpdf --overlay foo.pdf --from=1 --repeat=1 --to=1-$i -- "${TMP_DIR}/pages.pdf" "${TMP_DIR}/underlay.pdf"
qpdf --overlay foo.pdf --from=1 --repeat=1 --to=1-$i -- "${TMP_DIR}/underlay.pdf" "${OUT_PDF}"

exiftool -overwrite_original -Title="Fold-a-Face Mask v2.1 ©foldedlightart2020" -Author="Jiangmei Wu (www.foldedlightart.com)" -Subject="Origami Fashioned Facial Mask for Fighting COVID-19" "${OUT_PDF}"

exit

# EOF

«l1translate_x»
«l1translate_y»
«scale»
«size_a-text»
«size_b-text»
«l2translate_x»
«l2translate_y»
«l2rotate_deg»
