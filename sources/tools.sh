#!/bin/bash

set -e

declare -a all_functions_names
current_grade_for_comments=0

tmp_func_dir="../tmp"
tmp_func_file="tmp_functions"

# Encrypt a file
# @param $1 file to encrypt
function encrypt_file() {
    local in_file="${1}";

    if [[ ! -f "${in_file}" ]]; then
        echo "Error: Input file not found: ${in_file}"
        return 1
    fi

    openssl enc -e -aes-256-cbc -pbkdf2 -in "${path_log}" -out "${path_log}.crypt"
    rm "${path_log}" # Delete original
    #mv "${path_log}.crypt" "${path_log}"
}
export -f encrypt_file

# Decrypt a file
# @param $1 file to decrypt
function decrypt_file() {
    local in_file="${1}";
        
    if [[ ! -f "${in_file}.crypt" ]]; then
        echo "Error: Input file not found: ${in_file}"
        return 1
    fi

    local temp_file="${path_log}.tmp"
    openssl enc -d -aes-256-cbc -pbkdf2 -in "${path_log}.crypt" -out "${temp_file}"

    if [ $? -eq 0 ]; then
        echo "Decryption successful."
        rm "${path_log}.crypt" # Delete crypted file.
        mv "${temp_file}" "${path_log}" # Rename the tmp file as the original, non crypted.
    else
        echo "Decryption failed."
        exit 0
    fi
}
export -f decrypt_file

# Encrypt the journal file
function encrypt_journal_file() {
    encrypt_file "${path_log}"
}
export -f encrypt_journal_file

# Decrypt the journal file
function decrypt_journal_file() {
    decrypt_file "${path_log}"
}
export -f decrypt_journal_file

# Recover all functions from a script into a sanitized and formatted array
# Store it into an array so it can be used comparatively with other scripts datas.
# Array entry format = line_index:function_name:upper_comment
# @param $1 script to analyse
# @return array of the functions names
function find_functions_in_script() {
    local script="$1"

    local nb_functions=0
    local nb_commented=0

    # notes: about the use of mapfile here, because otherwise the array 
    # is cutted with whitespace, putting the "{" in an other array cell.

    # Find function in the case where they don't have the "function" keyword (nk = no keyword)
    local no_function_keyword_regex='^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\()'
    local function_names_nk
    local nk__out
    nk__out=$(grep -E -n -o "${no_function_keyword_regex}" "${script}")
    mapfile -t function_names_nk <<< "${nk__out}"

    # Find function in the case where they have the "function" keyword (wk = with keyword)
    local with_function_keyword_regex='^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\()?'
    local function_names_wk
    local wk__out
    wk__out=$(grep -E -n -o "${with_function_keyword_regex}" "${script}")
    mapfile -t function_names_wk <<< "${wk__out}"

    # Sanitize wk collection, removing the first "function ".
    for index in "${!function_names_wk[@]}"; do
        function_names_wk[index]="${function_names_wk[${index}]/function /}"
    done

    # Concatenate both sources.
    all_functions_names=("${function_names_nk[@]}" "${function_names_wk[@]}")

    # Logic applied for the full collection.
    for index in "${!all_functions_names[@]}"; do
            
        # Skip if string is empty, Bash arrays seems to somehow always have a lenght of 1 ?
        if [ -z "${all_functions_names[${index}]}" ]; then
            unset all_functions_names["${index}"]
            continue
        fi

        if [[ "${all_functions_names[${index}]}" == "\n" ]]; then
            unset all_functions_names["${index}"]
            continue
        fi

        # Sanitize collection, removing the first "()" occurrence.
        all_functions_names[index]="${all_functions_names[${index}]//()}"
        
        # Add separator for the next field.
        all_functions_names[index]+=":"

        # Internal Field Separator.
        IFS=":"

        # Split the array values.
        read -r line name <<< "${all_functions_names[${index}]}"

        # Check that we don't look for a line out of the file.
        # i.e. if the script start with a function declaration.
        if ((line > 1)); then
            local prev_line_index=$((line - 1))
            local prev_line
            
            # Get the previous line directly from the script.
            prev_line=$(sed -n "${prev_line_index}p" "${script}")
            all_functions_names[index]+="${prev_line}"

            # Since we are already looking for comments, count them here.
            # @features: comment recognition possible here, for additionnal control over what is valid.
            if [[ "${prev_line}" == "#"* ]]; then
                (( nb_commented++ ))
            fi
        fi 
    done

    # Get the number of function using the array length.
    nb_functions=${#all_functions_names[@]}

    # Remember to reset the IFS to its default value.
    IFS=$' \t\n'

    # Only if the option -c is active.
    if ((option_c == 1));
    then
        # Calculate the "function commented" grade for this script.
        local grade
        if [[ "${nb_functions}" -eq 0 ]];
        then
            # grade = 0, because we can't value function comments if there isn't.
            grade=0
        else
            # Calculate the grade, using integers. Hardcoded to be out of 10.
            grade=$(( (nb_commented * 10) / nb_functions ))
            grade=$(( (10 * grade) / 10 ))
        fi
        current_grade_for_comments=$(( grade - 10 ))
        echo -e "${current_grade_for_comments} [${nb_commented}/${nb_functions}] functions commented" >> "${path_log}"

        # Print whole array line by line.
        printf '%s\n' "${all_functions_names[@]}"
    fi
}
export -f find_functions_in_script

# Simply delete every file in tmp.
function delete_tmp_files() {
    for file in "${tmp_func_dir}"/*; do
        if [[ -e "${file}" ]]; then
            rm "${file}"
        fi 
    done
}
export -f delete_tmp_files

# Write into a tmp file
# @param $1 identifer of the data line
# @param $2 data to write
function log_functions_data() {
    data_identifier=$1
    data=$2

    # Directory doesn't exists ?
    if [[ ! -d "${tmp_func_dir}" ]]; then
        mkdir -p "${tmp_func_dir}"
    fi

    # .txt File doesn't exists ?
    if [[ ! -e "${tmp_func_dir}/${tmp_func_file}" ]]; then
        touch "${tmp_func_dir}/${tmp_func_file}"
    fi

    # Write into the tmp file
    echo -e "${data_identifier}\n${data}" >> "${tmp_func_dir}/${tmp_func_file}"
}

# @todo
function check_for_plagiarism() {
    # iterate through all the data we have from tmp, i.e. function names and function comments
    echo 1
    # Compare with every other data we have about other scripts.

    # Only keep the result matching the most
}