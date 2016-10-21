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

  # returns the first version of a character in a string
  # no alternate forms, no traditional forms
  def isolate_first_version!
    self.gsub!(self, self[0]) # the first character is always the simplified form
                              # there's probably a more sane way to do this lol
  end

  # removes any character in front and promotes the traditional character in its place
  def promote_traditional!
    self.gsub!(TRADITIONAL_REGEX, $1) if self =~ TRADITIONAL_REGEX
  end

  def remove_simplified!
    self.gsub!(SIMPLIFIED_REGEX, "")
  end
end


def most_common_chinese_characters(options)
  data = File.read("data/#{DATA_FILE}")
  doc = Nokogiri::HTML(data)

  simplified = options.fetch(:simplified)
  first_row = true

  Enumerator.new do |enum|
    doc.xpath("//blockquote/table/tr").each do |row|
      # skip the header row
      if first_row
        first_row = false
        next
      end

      # ----- CHARACTER -----------------------------------------------------------------------------

      character = row.xpath("td")[1].text.strip

      if simplified
      # extract the first character and delete everything else
        character.isolate_first_version!
      else
        character.promote_traditional!
        character.remove_simplified!
      end

      # ----- DESCRIPTION ---------------------------------------------------------------------------

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

      if simplified
        description.promote_traditional!
        description = Tradsim::to_trad(description)
      end

      data = {
        "character" => character,
        "description" => description
      }

      enum.yield(data)
    end
  end
end

# defaults to traditional characters
# pass in "simplified: true" to get simplified characters
def build_deck_of_top_n_cards(num_cards, options = {})
  raise ArgumentError, "num_cards must be an integer" unless num_cards.class < Integer

  options[:simplified] ||= false

  type = options[:simplified] ? "simplified" : "traditional"

  headers = %w[front back]
  output_deck_filename = "top-#{num_cards}-#{type}-chinese-characters.txt"

  puts "Generating: #{output_deck_filename}"

  # since there can be multiple entries for some characters, store descriptions onto an
  # hash of arrays keyed by character which we can join together later.
  card_hash = {}

  most_common_chinese_characters(options).take(num_cards).each do |pair|
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

  # ensure output directories exist.  there's probably a FileUtils method for this...
  ["decks", "decks/#{type}"].each do |dir|
    begin
      Dir.mkdir(dir)
    rescue Errno::EEXIST
    end
  end

  output_path = "decks/#{type}/#{output_deck_filename}"
  deck.generate_deck(file: output_path)
end

if __FILE__ == $0
  [100, 250, 500, 1000, 2000, 9999].each do |n|
    build_deck_of_top_n_cards(n, simplified: true)
    build_deck_of_top_n_cards(n)
  end
end
