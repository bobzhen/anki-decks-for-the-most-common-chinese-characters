# encoding: utf-8

require "bundler/setup"
require "anki"
require "json"
require "nokogiri"
require "tradsim"

DATA_FILE = "web_page_archive_20160630.html"


# yolo
class String
  SIMPLIFIED_REGEX = /\(S.+?\)/
  TRADITIONAL_REGEX = /\S?\(F(.+?)\)/

  # removes any character in front and promotes the traditional character in its place
  def promote_traditional!
    self.gsub!(TRADITIONAL_REGEX, $1) if self =~ TRADITIONAL_REGEX
  end

  def remove_simplified!
    self.gsub!(SIMPLIFIED_REGEX, "")
  end
end


def most_common_chinese_characters
  data = File.read("data/#{DATA_FILE}")
  doc = Nokogiri::HTML(data)

  first_row = true

  Enumerator.new do |enum|
    doc.xpath("//blockquote/table/tr").each do |row|
      # skip the header row
      if first_row
        first_row = false
        next
      end

      character = row.xpath("td")[1].text
      # use #inner_html because #text eats <BR> without converting it to a newline
      description = row.xpath("td")[2].inner_html

      if character == "仆"
        puts "Description: #{description}"
      end

      character.promote_traditional!
      character.remove_simplified!

      description.gsub!(/&amp;/i, "&")
      description.gsub!(/&lt;/i, "<")
      description.gsub!(/&gt;/i, ">")
      description.gsub!(/<br>/i, "\n")
      description.gsub!("\n", "<br /><br />")
      description.promote_traditional!
      description = Tradsim::to_trad(description)

      data = {
        "character" => character,
        "description" => description
      }

      enum.yield(data)
    end
  end
end

# the "anki" gem does not allow you to define a separator and always
# uses a semicolon. This breaks anki imports of the decks generated
# from the web page we're scraping.
#
# The pipe character is not used on the web page, so it's a safe choice.
module Anki
  class Deck
    def card_header_to_string
      "#" + self.card_headers.join("|") + "\n"
    end

    def card_data_to_string(card)
      raise ArgumentError, "card must be a hash" if !card.is_a?(Hash)

      card.default = ""

      self.card_headers.map{ |header| card[header] }.join("|")
    end
  end
end

def build_deck_of_top_n_cards(num_cards)
  raise ArgumentError, "num_cards must be an integer" unless num_cards.class < Integer

  headers = %w[front back]
  output_deck_filename = "top-#{num_cards}-chinese-characters.txt"
  cards = []

  puts "Generating: #{output_deck_filename}"

  most_common_chinese_characters.take(num_cards).each_with_index do |card, index|
    cards << {
      "front" => card["character"],
      "back" =>  card["description"],
    }
  end

  deck = Anki::Deck.new(card_headers: headers, card_data: cards)

  output_path = "decks/#{output_deck_filename}"
  deck.generate_deck(file: output_path)
end


if __FILE__ == $0
  [100, 250, 500, 1000, 2000].each do |n|
    build_deck_of_top_n_cards(n)
  end
end
