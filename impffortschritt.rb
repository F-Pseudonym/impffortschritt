#! /usr/bin/env ruby

require 'twitter'
require 'parseconfig'
require 'rest-client'
require 'date'
require 'tsv'

VACCINE_DATA_URL = "https://impfdashboard.de/static/data/germany_vaccinations_timeseries_v2.tsv"
POPULATION = 83190556 #https://www.destatis.de/DE/Themen/Gesellschaft-Umwelt/Bevoelkerung/Bevoelkerungsstand/Tabellen/zensus-geschlecht-staatsangehoerigkeit-2020.html
DOSES_PER_PERSON = 2
PERCENTAGE_HERD_IMMUNITY = 0.7
PERCENTAGE_HERD_IMMUNITY_DELTA = 0.85
CHAR_Y = "🟩"
CHAR_S = "🟦"
CHAR_N = "⬜️"
BAR_LENGTH = 20


required_doses = (POPULATION * DOSES_PER_PERSON * PERCENTAGE_HERD_IMMUNITY).round(0)
required_immune_persons_delta = (POPULATION * PERCENTAGE_HERD_IMMUNITY_DELTA).round(0)
bar_step = 100/BAR_LENGTH

stored_config = ParseConfig.new("#{File.dirname(__FILE__)}/twitter.config")

data = {}

begin
  response = RestClient.get VACCINE_DATA_URL, {:accept => :tsv}
  data_table = TSV.parse(response).without_header.each_with_index do |entry, idx|
      data["date"] = entry.to_a[0]
      data["sum"] = entry.to_a[1].to_i
      data["first"] = entry.to_a[8].to_i
      data["full"] = entry.to_a[9].to_i
      data["index"] = idx
      # data["sum_7d"] = entry["cumsum_7_days_ago"]
  end
rescue StandardError => e
  raise e
end

data_7d = TSV.parse(response).without_header.take(data["index"]-6).last
data["sum_7d"] = data_7d.to_a[1].to_i

begin
  content = File.read('./data')
rescue StandardError => e
  content = "1970-01-01"
end

pubdate_parsed = Date._parse(data["date"])
pubdate = Time.new(pubdate_parsed[:year], pubdate_parsed[:mon], pubdate_parsed[:mday])
olddate_parsed = Date._parse(content)
olddate = Time.new(olddate_parsed[:year], olddate_parsed[:mon], olddate_parsed[:mday])

if olddate >= pubdate
  exit(0)
end

progress = ((data["sum"]/required_doses.to_f)*100).round(1)
doses_per_day = (data["sum"] - data["sum_7d"])/7
remaining_days = (required_doses-data["sum"])/doses_per_day
target_date = Time.now + remaining_days * 24*60*60
doses_per_second = (doses_per_day.to_f / (3600*24)).round(2)

progress_first = ((data["first"]/required_immune_persons_delta.to_f)*100).round(1)
progress_full = ((data["full"]/required_immune_persons_delta.to_f)*100).round(1)

# bar = ""
# BAR_LENGTH.times { |i|
#   if((i+1)*bar_step <= progress)
#     bar << CHAR_Y
#   else
#     bar << CHAR_N
#   end
# }

bar_first = ""
BAR_LENGTH.times { |i|
  if((i+1)*bar_step <= progress_first)
    bar_first << CHAR_S
  else
    bar_first << CHAR_N
  end
}

bar_full = ""
BAR_LENGTH.times { |i|
  if((i+1)*bar_step <= progress_full)
    bar_full << CHAR_Y
  else
    bar_full << CHAR_N
  end
}


line1 = "Geimpfte Dosen (Deutschland): #{data["sum"].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} 💉\n"
line11 = "Herdenimmunität (85% vollst. Geimpfte): #{required_immune_persons_delta.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} 💉\n"
line2 = "Fortschritt für Herdenimmunität:\n"
line3 = bar_full + " (#{progress_full}%)\n"
line31 = "Fortschritt Erstgeimpfte:\n"
line32 = bar_first + " (#{progress_first}%)\n"
# line4 = "Geschätzes Zieldatum: #{target_date.strftime("%d.%m.%Y")} 📅\n"
line5 = "⌀(7 Tage): #{doses_per_second} Impf./s"


tweet = line1 + line11 + line2 + line3 + line31 + line32 +  line5



client = Twitter::REST::Client.new do |config|
  config.consumer_key        = stored_config["consumer_key"]
  config.consumer_secret     = stored_config["consumer_secret"]
  config.access_token        = stored_config["access_token"]
  config.access_token_secret = stored_config["access_token_secret"]
end

#client.update(tweet)
#File.write('./data', data["date"])
puts tweet