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
CHAR_Y = "🟩"
CHAR_N = "⬜️"
BAR_LENGTH = 20


required_doses = (POPULATION * DOSES_PER_PERSON * PERCENTAGE_HERD_IMMUNITY).round(0)
bar_step = 100/BAR_LENGTH

stored_config = ParseConfig.new("#{File.dirname(__FILE__)}/twitter.config")

data = {}

begin
  response = RestClient.get VACCINE_DATA_URL, {:accept => :tsv}
  data_table = TSV.parse(response).without_header.each_with_index do |entry, idx|
      data["date"] = entry.to_a[0]
      data["sum"] = entry.to_a[1].to_i
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


bar = ""
BAR_LENGTH.times { |i|
  if((i+1)*bar_step <= progress)
    bar << CHAR_Y
  else
    bar << CHAR_N
  end
}

line1 = "Geimpfte Dosen (Deutschland): #{data["sum"].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} 💉\n"
line2 = "Fortschritt für Herdenimmunität (70% Geimpfte):\n"
line3 = bar + " (#{progress}%)\n"
line4 = "Geschätzes Zieldatum: #{target_date.strftime("%d.%m.%Y")} 📅\n"
line5 = "⌀(7 Tage): #{doses_per_second} Impfungen pro Sekunde\n"
line6 = "#COVID19 #VACCINE"


tweet = line1 + line2 + line3 + line4 + line5 + line6



client = Twitter::REST::Client.new do |config|
  config.consumer_key        = stored_config["consumer_key"]
  config.consumer_secret     = stored_config["consumer_secret"]
  config.access_token        = stored_config["access_token"]
  config.access_token_secret = stored_config["access_token_secret"]
end

client.update(tweet)
File.write('./data', data["date"])