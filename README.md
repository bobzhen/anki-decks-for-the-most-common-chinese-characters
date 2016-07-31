# 最常見的中文字 - Anki Decks for the Most Common Chinese Characters

I found this cool web page which breaks down most of the 3,000 Chinese characters in mainstream use by how common they are.  http://www.zein.se/patrick/3000char.html

I wanted to make Anki decks out of the data on this page, so I wrote this script.

**Note**: This script converts all the simplified characters to traditional because I have zero interest in ever visiting China.  If you want to generate simplified decks, get rid of the two methods monkeypatched onto the `String` class and remove the `tradsim` gem.

加油！

## Usage

Just import one of the .txt decks in the `decks` directory into Anki.  **IMPORTANT**: when you import the deck, you have to manually specify a pipe character ("|") as the field separator.

You can get Anki here:  [Anki website](http://ankisrs.net/)

If you want to regenerate the decks from scratch, run `bundle install` to get all the dependencies and then run `ruby make_decks.rb`.

## License

BSD
