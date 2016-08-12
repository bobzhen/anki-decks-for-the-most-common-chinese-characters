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
      character.promote_traditional!
      character.remove_simplified!

      # use #inner_html because #text eats <BR> without converting it to a newline
      description = row.xpath("td")[2].inner_html
      description.gsub!(/&amp;/i, "&")
      description.gsub!(/&lt;/i, "<")
      description.gsub!(/&gt;/i, ">")
      description.gsub!(/<br>/i, "\n")
      # particles are described in <explanatory text> which Anki interprets as HTML, so
      # replace <> with {} instead.
      description.gsub!(/<([^>]+)/, "{\\1}")
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

def build_deck_of_top_n_cards(num_cards)
  raise ArgumentError, "num_cards must be an integer" unless num_cards.class < Integer

  headers = %w[front back]
  output_deck_filename = "top-#{num_cards}-chinese-characters.txt"

  puts "Generating: #{output_deck_filename}"

  # since there can be multiple entries for some characters, store descriptions onto an
  # array keyed by character which we can join together later.
  card_hash = {}

  most_common_chinese_characters.take(num_cards).each do |pair|
    character   = pair["character"]
    description = pair["description"]

    card_hash[character] ||= []
    card_hash[character] << description
  end

  cards = []

  card_hash.each do |character, descriptions|
    cards << {
      "front" => character,
      "back" =>  descriptions.join("<br /><br />"),
    }
  end

  deck = Anki::Deck.new(card_headers: headers, card_data: cards, field_separator: "|")

  output_path = "decks/#{output_deck_filename}"
  deck.generate_deck(file: output_path)
end


if __FILE__ == $0
  [100, 250, 500, 1000, 2000].each do |n|
    build_deck_of_top_n_cards(n)
  end
end
