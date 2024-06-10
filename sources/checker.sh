#!/bin/bash

#-------------------------------------------------------------------------#

option_a=0
option_b=0
option_f=0
option_i=0
option_n=0
option_s=0
option_p=0
option_r=0

chmod +x tools.sh
source ./tools.sh
source config.txt

#-------------------------------------------------------------------------#

function comment_check() {
  local subdir="$1"
  local name="$2"
  
  # log "identifier:[${name}]" >> "${path_log}"  
  echo -n -e "Warning: [${name}] " >> "${path_log}"  

  # For every script in the student folder, and is a .sh file.
  for script in "${subdir}"/*.sh;
  do
    if [[ -f "${script}" ]]; # is a file ?
    then
      set -e;
      local result_by_script
      # Those executions use the same resources, so we specialize the logic later.
      if ((option_c == 1 || option_p == 1));
      then
        result_by_script=$(find_functions_in_script "${script}")

        # log formatted data in tmp, for further process like plagiarism (functions and comments).
        log_functions_data "${name}" "${result_by_script}"
      fi
    fi
  done
}

# Main program execution
# will be refactored.
function execute_checking() {
    log_clear
    if [[ ! -f "${path_csv}" ]]; then
        echo "${path_csv} not found"
        exit 1
    fi

    # If user want to execute a new check, but there is a .crypt existing. Delete it.
    if [[ -f "${path_log}.crypt" ]]; then
      rm "${path_log}.crypt"
    fi

    while IFS=';' read -r last_name first_name _; do
      if [[ "${last_name}" != "Nom" ]]; then
        student_name="${last_name} ${first_name}"
        directory_pattern="${student_name}_*_assignsubmission_file"
        file_name="script-$(echo "${last_name}" | cut -c 1-3 | tr '[:upper:]' '[:lower:]')-$(echo "${first_name}" | cut -c 1-3 | tr '[:upper:]' '[:lower:]').sh"
        
        # Find the directory based on the pattern
        directory=$(find "${path_r}" -type d -name "${directory_pattern}" -print -quit)

        # Check if the directory exists
        if [[ -n "${directory}" ]]; then

          # Check if the file exists in the directory
          if [[ -f "${directory}/${file_name}" ]]; then #code here
            if [[ "$(basename "${directory}/${file_name}")" != "${file_name}" ]]; then

              if ((option_n == 1)); then
                log "Warning: [${student_name}] -5 Incorrect file name format in ${directory}. Expected: ${file_name}"
              fi            
            fi

            if ((option_c == 1)); then
              comment_check "${directory}" "${student_name}"
            fi

          else
            if ((option_n == 1)); then
              log "Warning: [${student_name}] -20 File ${file_name} not found in ${directory}"
            fi
          fi
        else
          if ((option_n == 1)); then
            log "Warning: [${student_name}] -20 Directory not found"
          fi
        fi
      fi
    done < "${path_csv}"
}

function calculate_penalty() {

    if [[ -f "${path_log}.crypt" ]]; then
      decrypt_journal_file
    fi

    if [[ ! -f "${path_csv}" ]]; then
        echo "Error: ${path_csv} not found"
        exit 0
    fi

    if [[ ! -f "${path_log}" ]]; then
       echo "Error: ${path_log} not found"
        exit 0
    fi

    while IFS=';' read -r last_name first_name _; do
        if [[ "${last_name}" != "Nom" ]]; then
            student_name="${last_name} ${first_name}"
            total_penalty=0

            # Search for lines in log.txt related to the student
            while read -r line; do
                if [[ ${line} == *"Warning: [${student_name}] -"* ]]; then
                    # Extract the penalty points from the log line
                    penalty=$(echo "${line}" | grep -oP 'Warning: \['"${student_name}"'\] -\d+' | grep -oP '\d+')
                    total_penalty=$((total_penalty + penalty))
                fi
            done < "${path_log}"

            # Display the result for the student
            echo "Student: ${student_name} -${total_penalty} points"
            echo "------------------------"
        fi
    done < "${path_csv}"
}

#-------------------------------------------------------------------------#
# Function to log messages to the journal file
function log() {
    printf "$1\n" >> "${path_log}"
}
# Function to clear the log file
function log_clear() {
    if [[ -f "${path_log}" ]]; then
      rm "${path_log}"
    fi

    touch "${path_log}"
}
#-------------------------------------------------------------------------#
# Give the user information about the possible arguments of the script.
function help() {
  echo "Usage: $0 [-abcfhinspr]"
  echo "Options:"
  echo "  -a : Option that launches all controls."
  echo "  -b : Presentation on screen of the sum of penalties to be withdrawn from students by analyzing the log file."
  echo "  -c : Checks the presence of at least 1 comment line before each function."
  echo "  -f : Path to the log file that stores the control report(s)."
  echo "  -h : Simplified help which describes all the functionalities developed."
  echo "  -i : Installing a more comprehensive man page than the simplified help created for this script."
  echo "  -n : Check file names. The file name must be of the form: 
                script-<first 3 letters of last name>-<first 3 letters of first name>.sh
                The first 3 letters of the first and last name are in lowercase and pasted without take into account apostrophes,spaces and hyphens."
  echo "  -s : Implementation of an encryption procedure to secure the results."
  echo "  -p : Implementation of an anti-plagiarism check with the Levenshtein distance: 
                On the names of the functions used. On the comments. 
                The result must indicate with the relationships between the plagiarisms."
  echo "  -r : Directory exported from Moodle which contains all deliverables."
  exit 1
}

# decrypt_journal_file # TO MOVE, HERE FOR DEMONSTRATION PURPOSE ONLY
    
#-------------------------------------------------------------------------#
#acquisition of parameters
while getopts ":abcf:hinspr:" option; do
  case ${option} in
    a) option_a=1;;
    b) option_b=1;;
    c) option_c=1;;
    f) option_f=1;path_f="${OPTARG}";;
    h) option_h=1;;
    i) option_i=1;;
    n) option_n=1;;
    p) option_p=1;;
    r) option_r=1;path_r="${OPTARG}";;
    s) option_s=1;;
    \?) echo "Error : Invalide Option" >&2; help ;;
  esac
done

if ((option_f == 1)); then
        echo "path_log=\"${path_log}\"" > config.txt
        echo path_f="\"${path_f}\"" >> config.txt
        echo path_r="\"${path_r}\"" >> config.txt
        echo path_csv="\"${path_csv}\"" >> config.txt
        echo path_man="\"${path_man}\"" >> config.txt
        if [[ ! -f "${path_f}" ]]; then
          echo "Error: The parameter is not a file"
          echo "Use -h for more information"
          exit 1
        fi
fi
if ((option_r == 1)); then
    echo "path_log=\"${path_log}\"" > config.txt
    echo path_f="\"${path_f}\"" >> config.txt
    echo path_r="\"${path_r}\"" >> config.txt
    echo path_csv="\"${path_csv}\"" >> config.txt
    echo path_man="\"${path_man}\"" >> config.txt
        if [[ ! -d "${path_r}" ]]; then
          echo "Error: The parameter is not a directory"
          echo "Use -h for more information"
        fi
fi
if ((option_a == 1)); then
  option_c=1
  option_n=1
  option_p=1
fi


if ((option_h == 1)); then
  help
fi
if ((option_i == 1)); then
  if [[ -f "/usr/share/man/man1/checker.1" ]]; then
            echo checker.1 already installed!
            exit 1
        else
          sudo install -m 644 "${path_man}" /usr/share/man/man1/
        fi
fi

# Clear the tmp folder at each execution 
delete_tmp_files

if ((option_c == 1 || option_p == 1 || option_n == 1)); then
  execute_checking
fi

if ((option_b == 1)); then
  calculate_penalty
fi


if ((option_s == 1)); then      
  # Crypt the file
  encrypt_journal_file
fi

# Execution
#___execute_checking

#-------------------------------------------------------------------------#
exit 0