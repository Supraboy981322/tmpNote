#!/usr/bin/env bash

(
  set -eou pipefail
 
  # print this script's source
cat <<EOF
//thank you, https://filesig.search.org/
//  for your amazing table of file header signatures
//
//script to generate the list:
EOF

  # embed the script in the output
  declare -a filename="$(echo "${0}")"
  cat "${filename}" | sed 's|^|//  |g'

  # create the table as an exported constant
  printf "\npub const list = [_][2][]const u8 {\n"

  # get the length of the json input
  declare -i len=$(cat magic.json | jq '. | length')

  # iterate over the json
  for i in $(seq 0 $((len-1))); do

    # get the header
    declare header_R="$(cat magic.json | jq -r ".[${i}].\"Header (HEX)\"")"
    # skip short headers
    [[ ${#header_R} -lt 2 ]] && continue

    # get the first hex digit
    declare -a first_dig=$(echo "${header_R}" | sed 's|'" "'.*||')
    # remove first digit if not 2 chars (not hex, there's a few of those)
    if [[ ${#first_dig} < 2 ]]; then
      header_R="$(echo "${header_R}" | sed 's|.* ||')";
    fi

    # replace the spaces with '\x' (for '\x00' formatted escape)
    declare -a header="$(echo "\x${header_R}" | sed 's| |\\x|g')"
    # get the file description (what it is) 
    declare -a desc="$(cat magic.json | jq ".[${i}].\"ASCII File Description\"")"
    # get the file class (eg: 'Picture')
    declare -a type="$(cat magic.json | jq ".[${i}].\"File Class\"")"

    # print the object
    printf "  .{\n    \"%s\",\n    %s,\n    %s\n  },\n" "${header}" "${desc}" "${type}"
  done
  # close the table
  printf "};\n"
)
