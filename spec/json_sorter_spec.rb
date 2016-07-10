require 'rspec'
require 'fileutils'

$: << '.'
require 'lib/json_sorter'

describe 'JsonSorter Behaviour' do

  let(:json_sorter) { JsonSorter.new }

  context 'tokeniser' do
    it 'should tokenise JSON' do
      expected = [
          ['{', 1],
          ['"bob"', 2],
          [':', 2],
          ['{', 2],
          ['"uncle"', 3],
          [':', 3],
          ['"Fred"', 3],
          [',', 3],
          ['"uncle"', 4],
          [':', 4],
          ['"Bob"', 4],
          [',', 4],
          ['"aunt"', 5],
          [':', 5],
          ['"Shirley"', 5],
          [',', 5],
          ['"relations"', 6],
          [':', 6],
          ['true', 6],
          [',', 6],
          ['"age"', 7],
          [':', 7],
          ['42,', 7],
          ['[ERROR] Invalid JSON', 8],
          ['"roger"', 8],
          [':', 8],
          ['"federer"', 8],
          [',', 8],
          ['"negative-age"', 9],
          [':', 9],
          ['-32.4', 9],
          ['}', 10],
          ['}', 11],
          [nil, nil]
      ]
      File.open('spec/errors.json', 'r') do |f|
        line = 1
        index = 0
        begin
          token, line = json_sorter.next_token(f, line)
          expect([token, line]).to eq(expected[index])
          index += 1
        end while (token)
      end
    end
  end

  context 'duplicates' do
    it 'should detect duplicates' do
      expected = [
          'Duplicate key "b" on lines [7, 10].',
          '[ERROR] Invalid JSON on line 14.',
          'Duplicate key "uncle" on lines [3, 15].'
      ]
      File.open('spec/duplicates.json', 'r') do |f|
        collector = json_sorter.detect_duplicates(f)
        expect(collector.sort).to eq(expected.sort)
      end
    end
  end

  context 'sorting' do
    it 'should sort valid JSON alphabetically by keys' do
      out = File.open('temp', 'w')
      File.open('spec/unsorted.json', 'r') do |f|
        json_sorter.sort(JSON.load(f), out)
      end
      out.close

      expect(FileUtils.identical?('spec/sorted.json', 'temp')).to be_truthy
      FileUtils.remove('temp')
    end
  end

end
