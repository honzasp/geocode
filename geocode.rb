#!/usr/bin/ruby
$KCODE = "u"
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "json/lib"))
#require 'rubygems'
require 'net/http'
require 'uri'
require 'json'

INPUT_NAME = "input.txt"
OUTPUT_NAME = "output.loc"
input = File.open INPUT_NAME
output = File.open OUTPUT_NAME, "w"

#addresses = [ "Bohuslava Martinů Ostrava-Poruba", "1600 Amphitheatre Parkway, Mountain View, CA" ]
addresses = input.readlines.map &:strip

output.puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
output.puts "<loc version=\"1.0\">"
output.puts

addresses.each do |address|
	next if address.empty?
	$stdout.print "#{address}... "
	$stdout.flush

	uri = URI.parse "http://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(address)}&sensor=false"
	json = JSON.parse(Net::HTTP.get(uri))

	case json["status"]
	when "OK"
		json["results"][0]["geometry"]["location"]
	when "ZERO_RESULTS"
		$stdout.puts "no results found - ignored"
		next
	when "OVER_QUERY_LIMIT"
		raise RuntimeError, "Over query limit"
	when "REQUEST_DENIED"
		raise RuntimeError, "Request denied"
	when "INVALID_REQUEST"
		raise RuntimeError, "Invalid request"
	else
		raise RuntimeError, "Unknown status"
	end

	coords = nil

	if json["results"].size > 1
		$stdout.puts "multiple results: "
		json["results"].each_with_index do |result, i|
			$stdout.puts "  ##{i + 1} - #{result["formatted_address"]}"
		end

		loop do
			$stdout.print "  Number of the right one (nothing to ignore): "
			$stdout.flush

			input = $stdin.gets.strip
			if input.empty?
				break
			else
				result = json["results"][input.to_i - 1]
				unless result.nil?
					coords = result["geometry"]["location"]
					break
				else
					$stdout.puts "  Bad number!"
				end
			end
		end
	else
		coords = json["results"][0]["geometry"]["location"]
		$stdout.puts "OK"
	end
	
	if coords
		output.puts "<waypoint>"
		output.puts "  <name><![CDATA[#{address}]]></name>"
		output.puts "  <coord lat=\"#{coords["lat"]}\" lon=\"#{coords["lng"]}\"/>"
		output.puts "</waypoint>"
		output.puts
	end
end

output.puts "</loc>"