#!/usr/local/bin/ruby
# ruby 2.3.1

# Uh Oh gathers some info about the client and the access point its connect to
# then opens a helpdesk ticket

# Because we're running this through automator on all types of employee machines, we 
# stick to ruby 2.3.1 std lib

require 'date'
require 'json'
require 'net/http'
require 'open-uri'
require 'uri'


# set up a log file
$logfile = '/Users/Shared/ap_roam.txt'
$date = DateTime.now
File.open($logfile, 'w') { |f| f.write("init") } unless File.file?($logfile)

# Gather client machine info
hostname = `hostname`.strip
$current_user = `stat -f '%Su' /dev/console | /usr/bin/cut -d ' ' -f 4`.strip
$preferred_interface = `route get 8.8.8.8 | awk '/interface/ {print $NF}'`.strip
ifconfig = `ifconfig #{$preferred_interface}`
ssid = `networksetup -getairportnetwork $(networksetup -listallhardwareports | awk '/AirPort|Wi-Fi/{getline; print $NF}') | awk -F'Network: ' '{print $NF}'`.strip

# Check internet connectivity
def internet_connection?
  true if open("https://www.google.com/")
rescue
  false
end

def wait_while(timeout = 10, retry_interval = 1, &block)
  start = Time.now
  until internet_connection?
    break if (Time.now - start).to_i >= timeout
    sleep(retry_interval)
    puts "no internet connectivity, sleeping..."
  end
  puts "no internet, logging..."
  `osascript -e 'display notification "Open an IT ticket if this happens consistantly" with title "Connectivity Error! Report could not be submitted"'`
  File.open('$logfile', 'a') { |f| f.puts("no connectivity : #{$preferred_interface} | #{$current_user} | #{$date}") }
  exit
end

# check for wi-fi power
if !internet_connection? && ssid.include?("Wi-Fi power is currently off.");
  `osascript -e 'display alert "Your Wi-Fi is turned OFF" message "Turn your Wi-Fi on and try again."'`
  puts "Wi-Fi powered off"
  exit
end

# wait for a bit if no connectivity
wait_while if !internet_connection?

Take action based on the SSID
if ssid == "{{ YOUR MAIN SSID }}"
  puts "running..."
elsif ssid == "{{ YOUR GUEST SSID }}"
  `osascript -e 'display alert "You are on the Guest Network!" message "The Guest Network is slower, and the printers wont work."'`
  puts "on Guest"
  exit
elsif ssid == "You are not associated with an AirPort network."
  `osascript -e 'display notification "Access Point :  #{current_ap}." with title "Your Report has been Submitted" subtitle "Thankyou!"'`
  puts "No SSID association"
  exit
else
  `osascript -e 'display alert "Youre not connected to a {{ YOUR COMPANY }} Wi-Fi network" message "join {{ YOUR COMPANY }} Wi-Fi and try again."'`
  puts "not on a {{ YOUR COMPANY }} SSID"
  exit
end

confirmation = `osascript -e 'tell app "System Events" to display dialog "Uh oh! \r \rSubmit a report about slow internet?" buttons {"OK", "Cancel"}'`.strip
exit unless confirmation == "button returned:OK"

# initialize and fill a hash of AP MAC addresses and names
# manually produced by exporting from the Meraki admin Wireless pages
ap = Hash.new
ap =  {"00:00:00"=>"{{ ACCESS POINT - LOCATION - BUILDING }}",
       "00:00:00"=>"{{ ACCESS POINT - LOCATION - BUILDING }}",
       "00:00:00"=>"{{ ACCESS POINT - LOCATION - BUILDING }}"}

# Find the MAC address of the current access point, set the name
airport_info = `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport -I`
bssid = `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport -I | awk '/BSSID:/ {print $2}'`.slice(-9..16).strip

current_ap = "not found"
ap.each do |mac_address, room|
  if mac_address == bssid
    current_ap = room
  end
end

api_token = ARGV[0] # replace w API_TOKEN in prod
# Open a ticket
uri = URI.parse("https://your.company.helpdesk.ticket.api.url")
request = Net::HTTP::Post.new(uri)
request.basic_auth("#{api_token}", "X")
request.content_type = "application/json"
request.body = JSON.dump({
  "helpdesk_ticket" => {
    "description" => "Current AP: #{current_ap}
                      Preferred Interface: #{$preferred_interface}

                      Current User: #{$current_user}
                      Hostname: #{hostname}

                      airport info: #{airport_info}
                      IFConfig: #{ifconfig}",
    "subject" => "#{hostname} | #{$preferred_interface} | #{current_ap}",
    "email" => "dev@yourcomapny.com",
    "priority" => 1,
    "status" => 3
  },
  "cc_emails" => "null@yourcompany.com"
})

req_options = {
  use_ssl: uri.scheme == "https",
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

#response.code
#response.body

# Generate a Desktop alert
`osascript -e 'display notification "Access Point :  #{current_ap}." with title "Your Report has been Submitted" subtitle "Thankyou!"'`

# sleep to prevent spam
sleep 6
exit