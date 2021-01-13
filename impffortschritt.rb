#! /usr/bin/env ruby

require 'twitter'
require 'parseconfig'
require 'rest-client'
require 'multi_json'
require 'date'

VACCINE_DATA_URL = "https://interaktiv.morgenpost.de/data/corona/rki-vaccinations.json"
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
  response = RestClient.get VACCINE_DATA_URL, {:accept => :json}
  MultiJson.load(response).each do |entry|
    if(entry["id"] == "de")
      data["date"] = entry["date"]
      data["sum"] = entry["cumsum_latest"]
      data["sum_7d"] = entry["cumsum_7_days_ago"]
    end
  end
rescue StandardError => e
  raise e
end


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

progress = (data["sum"]/required_doses.to_f).round(3)*100
doses_per_day = (data["sum"] - data["sum_7d"])/7
remaining_days = (required_doses-data["sum"])/doses_per_day
target_date = Time.now + remaining_days * 24*60*60


bar = ""
BAR_LENGTH.times { |i|
  if((i+1)*bar_step <= progress)
    bar << CHAR_Y
  else
    bar << CHAR_N
  end
}

line1 = "Geimpfte Dosen (Deutschland): #{data["sum"]} 💉\n"
line2 = "Fortschritt für Herdenimmunität (70% geimpfte):\n"
line3 = bar + " (#{progress}%)\n"
line4 = "Geschätzes Zieldatum: #{target_date.strftime("%d.%m.%Y")} 📅\n"
line5 = "#COVID19 #VACCINE"


tweet = line1 + line2 + line3 + line4 + line5



client = Twitter::REST::Client.new do |config|
  config.consumer_key        = stored_config["consumer_key"]
  config.consumer_secret     = stored_config["consumer_secret"]
  config.access_token        = stored_config["access_token"]
  config.access_token_secret = stored_config["access_token_secret"]
end

client.update(tweet)
File.write('./data', data["date"])