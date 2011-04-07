#!/usr/bin/ruby
begin
	$KCODE = "u"
	$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "json/lib"))
	#require 'rubygems'
	require 'net/http'
	require 'uri'
	require 'json'

	input_name = ARGV[0] || "input.txt"
	output_name = ARGV[1] || "output.loc"
	input = File.open input_name
	output = File.open output_name, "w"

	output.puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	output.puts "<loc src=\"Geocode\" version=\"1.0\">"
	output.puts

	input.readlines.map(&:strip).each do |line|
		next if line.empty?

		if line =~ /^([^:]*):(.*)$/
			name, address = $1.strip, $2.strip
		else
			address = line.strip
		end

		$stdout.print "#{name+": " if name}#{address} ... "
		$stdout.flush

		uri = URI.parse "http://maps.googleapis.com/maps/api/geocode/json?address=#{URI.encode(address)}&sensor=false"
		json = JSON.parse(Net::HTTP.get(uri))

		case json["status"]
		when "OK"
			sleep 0.5
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
			output.puts "  <name id=\"#{name or address}\"><![CDATA[#{address}]]></name>"
			output.puts "  <coord lat=\"#{coords["lat"]}\" lon=\"#{coords["lng"]}\"/>"
			output.puts "</waypoint>"
			output.puts
		end
	end

	output.puts "</loc>"
rescue Exception => exception
	File.open "error.log", "a" do |error_log|
		error_log.puts "### #{Time.now.to_s}"
		error_log.puts exception.inspect
		exception.backtrace.each do |line|
			error_log.puts "  #{line}"
		end
	end
	raise
end
