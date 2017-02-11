require "http/client"
require "option_parser"
require "base64"
require "json"
require "zlib"
require "csv"

input_file = ""
output_file = ""
username = ""
password = ""

OptionParser.parse! do |parser|
  parser.banner = "This tool takes a newline separated list of user ids and outputs their name and email to a csv.\n Usage: get_users [arguments]"
  parser.on("-f PATH", "--file=PATH", "Path to a file with a newline separated list of user ids to read") { |path| input_file = path }
  parser.on("-o PATH", "--output=PATH", "Path to output file with emails") { |path| output_file = path }
  parser.on("-u USERNAME", "--user=USERNAME", "User name") { |user| username = user }
  parser.on("-p PASSWORD", "--password=PASSWORD", "Password") { |pw| password = pw }
  parser.on("-h", "--help", "Show this help") { puts parser; exit }
end

user_ids = File.read_lines(input_file)

hashed = Base64.encode("#{username}:#{password}").chomp("\n")
headers = HTTP::Headers{"Authorization" => "Basic #{hashed}", "Content-Type" => "application/json"}
io = MemoryIO.new
io.puts "Name,Email"

channel = Channel(Array(String)).new(4)

user_ids.each do |id|
  print "."
  spawn do
    begin
      HTTP::Client.get("https://core.cloud.unity3d.com/api/users/#{id}", headers) do |response|
        body = response.body_io.gets_to_end
        json = JSON.parse(body)
        channel.send(["#{json["name"]}","#{json["email"]}"])
      end
    rescue ex
      puts ex.message
    end
  end
end

user_ids.size.times do |i|
  arr = channel.receive
  CSV.build(io) {|csv| csv.row arr[0],arr[1]}
end

File.write(output_file, io.to_s)

puts "Done."
