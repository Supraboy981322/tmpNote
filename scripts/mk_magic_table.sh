#!/usr/bin/env bash

(
  set -eou pipefail

  printf "pub const list = [_][2][]const u8 {\n"

  declare -i len=$(cat foo.json | jq '. | length')

  for i in $(seq 0 $((len-1))); do

    declare header_R="$(cat foo.json | jq -r ".[${i}].\"Header (HEX)\"")"
    [[ ${#header_R} -lt 2 ]] && continue

    declare -a first_dig=$(echo "${header_R}" | sed 's|'" "'.*||')
    if [[ ${#first_dig} < 2 ]]; then
      header_R="$(echo "${header_R}" | sed 's|.* ||')";
    fi

    declare -a header="$(echo "\x${header_R}" | sed 's| |\\x|g')"

    declare -a desc="$(cat foo.json | jq ".[${i}].\"ASCII File Description\"")"

    printf "\t.{ \"%s\", %s },\n" "${header}" "${desc}"
  done
  printf "};\n"
)
