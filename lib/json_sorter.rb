#!/usr/bin/env ruby

require 'json'
require 'stringio'

class JsonSorter

  def initialize
    @last_error_line = 0
  end

  def generate_sorted_from_stream(json_stream)
    duplicate_errors = detect_duplicates(json_stream)
    if duplicate_errors == []
      json_stream.seek(0, IO::SEEK_SET)
      sort(JSON.parse(json_stream.read), $stdout)
    else
      duplicate_errors.each { |err| $stdout.puts(err) }
      exit 1
    end
  end

  def generate_sorted_from_file(json_file)
    File.open(json_file, 'r') do |f|
      generate_sorted_from_stream(f)
    end
  end

  def generate_sorted_from_string(json_string)
    StringIO.open(json_string, 'r') do |s|
      generate_sorted_from_stream(s)
    end
  end

  def sort(parsed_json, io_stream)
    def go(json, level, io_stream)
      if json.class == Hash
        io_stream.puts('{')
        level += 1
        (json.keys.sort).each_with_index do |k, i|
          io_stream.print(padding(level))
          io_stream.print("\"#{k}\": ")
          v = json[k]
          if v.class == Hash
            go(v, level, io_stream)
          elsif v.class == Array
            io_stream.print("#{v.to_s}")
          elsif v.class == String
            io_stream.print("\"#{v}\"")
          else
            io_stream.print("#{v}")
          end

          if i < (json.keys.length - 1)
            io_stream.puts(',')
          else
            io_stream.puts('')
          end
        end
        level -= 1
        io_stream.print(padding(level))
        io_stream.print('}')
      elsif json.class == Array
        json.to_s
      end
    end

    go(parsed_json, 0, io_stream)
  end

  def padding(level)
    ' ' * (2 * level)
  end

  def detect_duplicates(json_stream)
    def go(stream, line, collector)
      key_lines = {}
      next_tok = nil
      begin
        if next_tok
          token= next_tok
        else
          token, line = next_token(stream, line)
        end
        if token.nil?
          return [collector, line]
        elsif token == '{'
          collector, line = go(stream, line, collector)
        elsif token == '}'
          duplicates = key_lines.select { |k, v| v.length > 1 }
          duplicates.each { |k, v| collector << "Duplicate key #{k} on lines #{v}." }
          return [collector, line]
        elsif token.match(/\[ERROR\]/)
          collector << "#{token} on line #{line}."
        elsif /".*"/ =~ token
          next_tok, line = next_token(stream, line)
          if next_tok == ':'
            if key_lines[token].nil?
              key_lines[token] = [line]
            else
              key_lines[token] << line
            end
            next_tok = nil
          end
        else
          next_tok = nil
          next
        end
      end while (token)
    end

    go(json_stream, 1, [])[0]
  end

  def next_token(json_stream, line)
    while (ch = json_stream.getc) do
      case
        when ch == "\n"
          line += 1
          next
        when (ch == ' ' or ch == "\t")
          next
        when ch.match(/\{|\}|\[|\]|:|,/)
          return [ch, line]
        when ch == '"'
          return tokenise_string(json_stream, line)
        when ch.match(/-|\d/)
          json_stream.seek(-1, IO::SEEK_CUR)
          return tokenise_number(json_stream, line)
        when (ch == 't' or ch == 'f')
          json_stream.seek(-1, IO::SEEK_CUR)
          return tokenise_boolean(json_stream, line)
        else
          if line > @last_error_line
            @last_error_line = line
            return ['[ERROR] Invalid JSON', line]
          else
            next
          end
      end
    end
  end

  def tokenise_string(json_stream, line)
    token = '"'
    while (ch = json_stream.getc)
      case
        when ch == '"'
          token = token << ch
          return [token, line]
        when ch.match(/[^\n]/)
          token = token << ch
        else
          line += 1 if ch == "\n"
          @last_error_line = line
          ['[ERROR] Invalid JSON string', line]
      end
    end
  end

  def tokenise_number(json_stream, line)
    token = ''
    while (ch = json_stream.getc)
      case
        when ch.match(/\S/)
          token = token << ch
        else
          json_stream.seek(-1, IO::SEEK_CUR)
          return [token, line]
      end
    end
  end

  def tokenise_boolean(json_stream, line)
    ch = json_stream.getc
    token = ch
    case ch
      when 't'
        match_true(json_stream, line, token)
      when 'f'
        match_false(json_stream, line, token)
      else
        line += 1 if ch == "\n"
        @last_error_line = line
        ['[ERROR] Boolean values can only be `true` or `false`.', line]
    end
  end

  def match_true(json_stream, line, token)
    3.times { token = token << json_stream.getc }
    if token == 'true'
      [token, line]
    else
      @last_error_line = line
      ['[ERROR] Boolean values can only be `true` or `false`.', line]
    end
  end

  def match_false(json_stream, line, token)
    4.times { token = token << json_stream.get }
    if token == 'false'
      [token, line]
    else
      @last_error_line = line
      ['[ERROR] Boolean values can only be `true` or `false`.', line]
    end
  end

end

if ARGV.length == 1
  json_file = ARGV[0]
  json_sorter = JsonSorter.new
  json_sorter.generate_sorted_from_file(json_file)
end