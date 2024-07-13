require "csv"
require "erb"
require "time"
require "google/apis/civicinfo_v2"

def representatives_by_zip(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read("secret.key").strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode, levels: "country",
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue # rubocop:disable Style/RescueStandardError
    "No representatives found"
  end
end

def generate_form_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.tr("() -.", "")
  if phone_number.length == 11 && phone_number[0] == "1"
    phone_number = phone_number[1..]
  elsif phone_number.length > 10 || phone_number.length < 10
    return "BAD NUMBER"
  end

  phone_number.insert(3, "-")
  phone_number.insert(7, "-")
  phone_number
end

def process_time(str)
  processed_str = str.gsub(/0\d/, '20\&')
  Time.strptime(processed_str, "%m/%d/%Y %k:%M")
end

def convert_to_weekday(number)
  weekdays = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  weekdays[number]
end

def peak_registration_hour(time_table)
  sorted_hour = time_table.sort_by { |_k, v| v }.reverse!.first(10)
  puts "Top 10 hours that have the most registrations is:"
  sorted_hour.each_with_index do |(hour, votes), index|
    puts "#{index + 1}: #{hour} with #{votes} votes"
  end
end

def peak_registration_weekday(time_table)
  sorted_time = time_table.sort_by { |_k, v| v }.reverse!
  puts "Weekdays ranked by most registrations:"
  sorted_time.each_with_index do |(day, votes), index|
    puts "#{index + 1}: #{convert_to_weekday(day)} with #{votes} votes"
  end
end

puts "Event Manager Initialized!"

lines = CSV.open("event_attendees_full.csv", headers: true, header_converters: :symbol)
template_letter = File.read("form_letter.erb")
erb = ERB.new template_letter
registration_hour = Hash.new(0)
registration_day = Hash.new(0)

lines.each do |line|
  id = line[0]
  name = line[:first_name]
  zipcode = clean_zipcode(line[:zipcode])
  representatives = representatives_by_zip(zipcode)
  form_letter = erb.result(binding)
  time = process_time(line[:regdate])

  registration_hour[time.hour] += 1
  registration_day[time.wday] += 1

  generate_form_letter(id, form_letter)
end

peak_registration_hour(registration_hour)
peak_registration_weekday(registration_day)
