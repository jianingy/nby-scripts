#!/usr/bin/env ruby

require 'optparse'
require 'pty'
require 'expect'
require 'pp'

$check_timeout = 5
$prompt = /#|>/
$iface = /([A-Za-z-]+[0-9\/]+)/
$prog = "print-switch-mac-table.rb"
$service = { 22 => 'ssh', 23 => 'telnet' }

def debug(message)
   STDERR.puts "DEBUG: #{message}"
end

def _connect(host, username)
  method = catch :done do
    [23, 22].each do |port|
      nc = %x{nc -z -w #{$check_timeout} '#{host}' #{port}}
      throw :done, $service[port] if $? == 0
    end
    nil
  end
  debug("[#{host}] connect = #{method}")
  case method
    when /telnet/
      $pout, $pin, $pid = PTY.spawn("telnet #{host}")
    when /ssh/
      $pout, $pin, $pid = PTY.spawn("ssh #{username}@#{host}")
    else
      abort "could not determine connection type neither ssh nor telnet"
  end
end

def connect(host, username, password)
  _connect(host, username)
  num_tries = 3
  while num_tries > 0 do
    $pout.expect(/([Uu]sername:|[Pp]assword:|#|>)/, $check_timeout) { |t, match|
      abort "ERROR: switch no response" unless t
      case match
        when /[Uu]sername:/
          $pin.printf("#{username}\n")
        when /[Pp]assword:/
          $pin.printf("#{password}\n")
          num_tries -= 1
        when /#|>/
          return true
      end
    }
  end
  abort "ERROR: login failure" unless failure > 0
end

def execute(command)
  ret = []
  $pin.printf("#{command}\n")
  $pout.expect($prompt, $check_timeout).first.split(/[\r\n]/)[1..-2].each { |r|
      r.strip!
      ret << r if r.length > 0
  }
  return ret
end

def probe_model
  execute('termimal length 0')
  execute('screen-length disable')
  return 'cisco' if /[Cc]isco/.match(execute('show version').join())
  return 'h3c' if /[Hh]3[Cc]/.match(execute('display version').join())
  abort "ERROR: switch model is neither cisco nor h3c"
end

def ifnormalize(iface)
  case iface
    when /Bridge-Aggregation(.*)/
      "PO#{$1}"
    when /Port-[Cc]hannel(.*)/
      "PO#{$1}"
    when /BAGG(.*)/
      "PO#{$1}"
    when /Po(.*)/
      "PO#{$1}"
    when /Ten-?GigabitEthernet(.*)/
      "T#{$1}"
    when /Te(.*)/
      "T#{$1}"
    when /GigabitEthernet(.*)/
      "G#{$1}"
    when /XGE(.*)/
      "T#{$1}"
    when /G[Ei](.*)/
      "G#{$1}"
    else
      iface
  end
end

def show_dynamic_mac(host, username, password)
  connect(host, username, password)
  model = probe_model
  debug("[#{host}] model = #{model}")
# get trunk
  trunks = (case model
    when 'cisco'
    execute 'show int status | include trunk'
    when 'h3c'
    execute 'display port trunk'
  end).select { |t| $iface.match(t) }.collect { |t| ifnormalize t.split.first}

  debug("[#{host}] trunks = " + trunks.join(','))

# get mac
  macs = (case model
    when 'cisco'
      execute 'show mac-address-table dynamic'
    when 'h3c'
      execute 'display mac-address dynamic'
  end).select { |t| $iface.match(t) }.collect { |t|
    s = t.split()
    case model
    when 'cisco'
      [s[0], s[1], s[3]]
    when 'h3c'
      [s[1], s[0], s[3]]
    end
  }.each{ |vlan, mac, iface|
    iface = ifnormalize(iface)
    mac = mac.gsub(/[^a-z0-9]/i, '').downcase.scan(/.{2}/).join(':')
    vlan = vlan.gsub(/[^0-9]/, '')
    next if trunks.include? iface
    puts "#{iface.ljust(20)} #{vlan.ljust(5)} #{mac}"
  }
  return true
end

if __FILE__ == $0
  options = {}
  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$prog} [options] hostname"
    opts.separator "Get learned dynamic mac addresses from a CISCO/H3C switch"
    opts.separator ""
    options[:username] = nil
    opts.on('-u', '--username NAME', 'username for logging in') do |username|
      options[:username] = username
    end
    options[:password] = nil
    opts.on('-p', '--password PASS', 'password for logging in') do |password|
      options[:password] = password
    end
    opts.on("-v", "--verbose", "Print expect debugging message") do
      $expect_verbose = true
    end
    opts.on("-h", "--help", "Show this message") do
      puts opts
      exit
    end
    opts.separator ""
    opts.separator "example:"
    opts.separator "  #{$prog} -u user -p password ASW-01"
    opts.separator ""
    opts.separator "Report bugs to jianingy.yang AT gmail DOT com"
  end
  opts.parse!
  ARGV.each do |hostname|
    show_dynamic_mac(hostname, options[:username], options[:password])
  end
end

# vim: ts=2 sw=2 ai et
