# Prints usage
mm::usage() {
  cat << EOF

Usage: ${progname} <options>

Options:
  --network <network>       Defines the network to scan
  --scan                    Scan network
  --tag <MAC address>       Edit MAC address tag
  --list                    Prints a MAC address table
  --delete <MAC address>    Deletes a MAC address

EOF
}

# Exits with options
mm::exit() {
  local _exit_code=$1
  unlock && exit ${_exit_code}
}

# Locks program
lock() {
  local _date_now=$( date +%s )
  touch "${lock_file}"
  set -u && echo -e "pid=$$\ntimestamp=${_date_now}" > "${lock_file}"
}

# Unlocks program
unlock() {
  set -u && rm "${lock_file}"
}

# Checks if lock exists
check_lock() {
  local _date_now=$( date +%s )

  if [ -f "${lock_file}" ]; then
    local _date_last_run="$( grep 'timestamp' "${lock_file}" | cut -d\= -f2 )"
    local _last_pid="$( grep 'pid' "${lock_file}" | cut -d\= -f2 )"

    # Crude way to check if process is still running...
    if ! kill -0 ${_last_pid} >/dev/null 2>&1 ; then
      we "Lock file found, but process with PID ${_last_pid} not found. Clearing lock file."
      unlock
    elif [ $(( _date_now - _date_last_run )) -ge ${run_timeout} ]; then
        we "Lock file found, but lock time exceeds timeout of ${run_timeout} seconds. Removing stale lock file..."
        unlock
    else
       ee "Script is currently locked with PID ${_last_pid}."
       exit
    fi
  fi
}

# Logs to file
mm::log() {
  _log_msg="$( date ) - $@"
  set -u && echo "${_log_msg}" >> "${log_file}"
}

# Echo/error
ee() {
  echo "ERROR: $@" >&2
}

# Echo/warning
we() {
  echo "WARNING: $@" >&2
}

# Echo/debug
de() {
  echo "$@" >&2
}

# Set up directories and files
mm::setup() {
  [ ! -d "${state_dir}" ] && mkdir "${state_dir}" && FIRSTRUN=0
  [ ! -f "${network_file}" ] && touch "${network_file}"
  [ ! -f "${log_file}" ] && touch "${log_file}"
}

# Checks dependencies
check_dependencies() {
  for dep in "${dependencies[@]}" ; do
    if ! which "${dep}" >/dev/null 2>&1 ; then
      ee "dependency ${dep} not found. Exiting." && mm::exit 1
    fi
  done
}

# UID 0 check
mm::user_check() {
  [ ${EUID} -ne 0 ] && ee "please run ${progname} as root!" && mm::exit 1
}

# Reserved for future use!
mm::verify_mac_address() {
  :
}

# Validates a IPv4 network
mm::validate_network() {
  if ! ipcalc -c "${network}" > /dev/null 2>&1 ; then
    ee "invalid network ${network}. Exiting." && mm::exit 1
  else
    return 0
  fi
}

# Verifies and exports the network parameters
mm::set_network() {
  export network network_dir_name

  [ ! -f "${network_file}" ] && ee "no network defined. Please add your network with the --network option." && mm::exit 1

  network="$( cat "${network_file}" )"

  [ -z "${network}" ] && ee "no network defined. Please add your network with the --network option." && mm::exit 1

  mm::validate_network "${network}"

  network_dir_name="$( echo "${network}" | sed 's/\//_/g' )"
  network_dir_name="${state_dir}/${network_dir_name}"

  if [ ! -d "${network_dir_name}" ]; then
    mkdir "${network_dir_name}"
    #echo "Network set to ${network}!"
  fi
}

# Adds a network
mm::add_network() {
  local _network_dir_name

  network="$1"

  [ -z "${network}" ] && ee "no network specified." && mm::usage && mm::exit 1

  mm::validate_network "${network}"

  set -u && echo "${network}" > "${network_file}"
}

# Scans a network
mm::scan_network() {
  export scan_results mac_address_data
  
  echo "Scanning ${network}..."

  # Scan network
  if ! scan_results="$( nmap -T 4 -sP ${network} 2>&1 ) )" ; then
    echo "Error running nmap scan on ${network}: "
    echo "${scan_results}"
    mm::exit 1
  fi

  # Exit if we have an empty result
  [ -z "${scan_results}" ] && ee "empty scan result return. Exiting." && mm::exit 1

  # Populate MAC address array
  OLDIFS=$IFS ; IFS=$'\n'
  mac_address_data=( $( echo "${scan_results}" | grep 'MAC Address' | sed 's/MAC Address: //g' ) )
  IFS=$OLDIFS

  # Exit if our array is empty
  [ ${#mac_address_data[@]} -eq 0 ] && ee "empty address array returned. Please ensure that you have an accessible network defined! Exiting." && mm::exit 1

  echo "${#mac_address_data[@]} MAC addresses scanned." >&2
  echo

  set -u && echo "$( date +%s )" > "${last_scan_file}"
}

# Reserved for future use!
mm::send_notification() {
  :
}

# Reserved for future use!
mm::new_mac_address_notification() {
  :
}

# Adds or updates address state
mm::add_address() {
  local _address _vendor _this_address_directory _date_updated _date_discovered _friendly_name _this_vendor_file _this_last_seen_file _this_first_discovered_file _date_now _this_tags_file _new_discovered _new_discovered_index _this_last_seen _time_away

  _new_discovered_index=0
  declare -a _new_discovered

  for _mac_address_entry in "${mac_address_data[@]}" ; do
    _address="$( echo "${_mac_address_entry}" | awk '{ print $1 }' )"
    _vendor="$( echo "${_mac_address_entry}" | sed "s/${_address}//g" | sed 's/ (//g' | sed 's/)//g' )"
    _friendly_name="$( echo "${_address}" | sed 's/:/_/g' )"
    _this_address_directory="${network_dir_name}/${_friendly_name}"
    _this_vendor_file="${_this_address_directory}/vendor"
    _this_last_seen_file="${_this_address_directory}/last_seen"
    _this_first_discovered_file="${_this_address_directory}/discovered"
    _this_tags_file="${_this_address_directory}/tags"
    _date_now=$( date +%s )

    if [ -d "${_this_address_directory}" ]; then
      touch "${_this_last_seen_file}"
      _this_last_seen=$( cat "${_this_last_seen_file}" )
      _time_away=$(( _date_now - _this_last_seen ))
      [ ${_time_away} -ge ${return_notify_interval} ] && mm::log "Address ${_address} returned after being away for ${_time_away} seconds."
      set -u && echo "${_date_now}" > "${_this_last_seen_file}"
    else
      set -u && mkdir -p "${_this_address_directory}"
      touch "${_this_last_seen_file}" "${_this_vendor_file}" "${_this_first_discovered_file}" "${_this_tags_file}"
      set -u && echo "${_vendor}" > "${_this_vendor_file}"
      set -u && echo "${_date_now}" > "${_this_last_seen_file}"
      set -u && echo "${_date_now}" > "${_this_first_discovered_file}"

      _new_discovered[${_new_discovered_index}]="${_address},${_vendor}"
      ((_new_discovered_index++))

      mm::log "New MAC address discovered: ${_address} (${_vendor})"
    fi
  done

  # Print summary of new addresses found
  if [ $FIRSTRUN -ne 0 ]; then
    if [ ${#_new_discovered[@]} -gt 0 ]; then
      echo
      echo "Newly discovered addresses: "
      for _new_discovered_data in "${_new_discovered[@]}" ; do
        _address="$( echo "${_new_discovered_data}" | cut -d, -f1 )"
        _vendor="$( echo "${_new_discovered_data}" | cut -d, -f2 )"
        echo " * ${_address} (${_vendor})"
      done
      echo
    fi
  fi
}

# Prints a list of known MAC addres info
mm::list() {
  local _address_data _address _this_address_directory _friendly_name _this_real_name _this_vendor_file _this_last_seen_file _this_first_discovered_file _date_now _address_list _this_vendor _this_last_seen _this_first_discovered _this_tags_file _this_tags _this_last_seen_seconds _last_scan _address_list_sorted

  _date_now=$( date +%s )
  _address_list=""
  _address_list_sorted=""

  # Create address data array
  set -u && _address_data=( $( cd "${network_dir_name}" 2>/dev/null && ls 2>/dev/null ) )

  # Check if we have any addresses
  [ ${#_address_data[@]} -eq 0 ] && ee "no addresses found. Have you scanned yet?" && mm::exit 1

  [ -f "${last_scan_file}" ] && _last_scan=$( cat "${last_scan_file}" ) ; [ ! -f "${last_scan_file}" ] && _last_scan=0

  # Print stats
  [ -f "${last_scan_file}" ] && echo "Last scan: $( date -d@${_last_scan} )"
  echo "Hosts discovered: ${#_address_data[@]}"
 
  # Parse address data
  echo
  _address_list_header="MAC Address\tLast Seen (Date)\tLast Seen (Seconds)\tDiscovered\tVendor\tTags"
  _address_list_header="${_address_list_header}
-----------------\t---------------------\t-------------------\t-----------------\t------------------\t-------------------------------------"

  for _address in "${_address_data[@]}" ; do
    _this_address_directory="${network_dir_name}/${_address}"
    _this_vendor_file="${_this_address_directory}/vendor"
    _this_last_seen_file="${_this_address_directory}/last_seen"
    _this_first_discovered_file="${_this_address_directory}/discovered"
    _this_tags_file="${_this_address_directory}/tags"
    
    _this_real_name="$( echo "${_address}" | sed 's/_/:/g' )"
    _this_vendor="$( cat "${_this_vendor_file}" )"
    _this_first_discovered="$( date -d@$( cat "${_this_first_discovered_file}" ) "+%d/%m/%y %H:%M:%S" )"
    _this_last_seen_seconds="$( cat "${_this_last_seen_file}" )"
    _this_last_seen="$( date -d@${_this_last_seen_seconds} "+%d/%m/%y %H:%M:%S" )"
    _this_tags="$( cat "${_this_tags_file}" )" ; [ -z "${_this_tags}" ] && _this_tags="None"
    _this_last_seen_seconds=$(( _last_scan - _this_last_seen_seconds ))

    [ ${_this_last_seen_seconds} -lt 0 ] && _this_last_seen_seconds=0

    _address_list="${_address_list}
${_this_real_name}\t${_this_last_seen}\t${_this_last_seen_seconds}\t${_this_first_discovered}\t${_this_vendor}\t${_this_tags}"
  
  done

  # Print the address list (header is separated so that we can sort on the correct field only)
  _address_list_sorted="$( echo -e "${_address_list}" | sort -n -k 3 -t$'\t' )"
  echo -e "${_address_list_header}\n${_address_list_sorted}" | column -t -s $'\t'
}

# Adds tags (notes) to a MAC address
mm::add_tag() {
  local _address _address_dir _this_tags_file

  [ $# -ne 1 ] && ee "no address specified." && mm::usage && mm::exit 1
  _address="$1"
  [ -z "${_address}" ] && ee "no address specified." && mm::usage && mm::exit 1


  # Convert address to uppercase and to friendly name
  _address="${_address^^}"
  _address="$( echo "${_address}" | sed 's/:/_/g' )"

  # Check the address exists
  _address_dir="${network_dir_name}/${_address}"  
  [ ! -d "${_address_dir}" ] && ee "MAC address not found." && mm::exit 1

  if [ -d "${_address_dir}" ]; then
    _this_tags_file="${_address_dir}/tags"
    if [ -n "${EDITOR}" ]; then
      $EDITOR "${_this_tags_file}"
    else
      vim "${_this_tags_file}"
    fi
  fi
}

# Deletes a MAC address
mm::delete_address() {
  local _address _address_dir _this_tags_file

  [ $# -ne 1 ] && ee "no address specified." && mm::usage && mm::exit 1

  # This is a destructive operation, so important to use unset mode
  set -u

  _address="$1"

  [ -z "${_address}" ] && ee "no address specified." && mm::usage && mm::exit 1


  # Convert address to uppercase and to friendly name
  _address="${_address^^}"
  _address="$( echo "${_address}" | sed 's/:/_/g' )"

  # Check the address exists
  _address_dir="${network_dir_name}/${_address}"  
  [ ! -d "${_address_dir}" ] && ee "MAC address not found." && mm::exit 1

  if [ -d "${_address_dir}" ]; then
    echo -n "Press enter to remove MAC address entry ${_address_dir}, or CTRL+C to exit now."
    read pause_delete < /dev/tty
    de "deleting ${_address_dir}" && set -u && rm -rf "${_address_dir}"
  fi
}